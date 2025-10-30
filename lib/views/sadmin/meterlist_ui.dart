import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/widgets/subnavbar.dart';
import '../../services/meter_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';
import '../widgets/colors.dart';

class MeterReadingsListPage extends StatefulWidget {
  final bool hideBottomNav;
  final String? branchId;
  final String? branchName;

  const MeterReadingsListPage({
    Key? key,
    this.hideBottomNav = false,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<MeterReadingsListPage> createState() => _MeterReadingsListPageState();
}

class _MeterReadingsListPageState extends State<MeterReadingsListPage> {
  // User/permission
  UserModel? _currentUser;

  // Filters
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _roomNumberController = TextEditingController();
  String _roomNumberQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];

  // Rooms (active contracts)
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  bool _loadingRooms = false;

  // Previous readings per room_id
  final Map<String, double> _prevWaterByRoom = {};
  final Map<String, double> _prevElecByRoom = {};

  // Controllers per room_id
  final Map<String, TextEditingController> _waterCtrl = {};
  final Map<String, TextEditingController> _elecCtrl = {};
  final Map<String, TextEditingController> _noteCtrl = {};

  // Saving state and saved flags
  final Set<String> _savingRoomIds = {};
  final Set<String> _savedRoomIds = {};

  // Existing readings for selected month/year per room_id
  final Map<String, Map<String, dynamic>> _existingByRoom = {};
  final Set<String> _editingRoomIds = {};

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year; // ค.ศ. (แสดงผล พ.ศ.)

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in _waterCtrl.values) c.dispose();
    for (final c in _elecCtrl.values) c.dispose();
    for (final c in _noteCtrl.values) c.dispose();
    _searchController.dispose();
    _roomNumberController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await AuthService.getCurrentUser();
      if (_currentUser == null) return;

      await _loadRoomsAndPrevious();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRoomsAndPrevious() async {
    setState(() => _loadingRooms = true);
    try {
      // Load active rooms for selected branch
      _rooms = await MeterReadingService.getActiveRoomsForMeterReading();

      // Sort by room number (asc) then category
      _rooms.sort((a, b) {
        final an = (a['room_number'] ?? '').toString();
        final bn = (b['room_number'] ?? '').toString();
        final cmpRoom = an.compareTo(bn);
        if (cmpRoom != 0) return cmpRoom;
        final ac = (a['room_category_name'] ?? '').toString();
        final bc = (b['room_category_name'] ?? '').toString();
        return ac.compareTo(bc);
      });

      // Build categories list
      final setCats = <String>{};
      for (final r in _rooms) {
        final c = (r['room_category_name'] ?? '').toString();
        if (c.isNotEmpty) setCats.add(c);
      }
      _categories = setCats.toList()..sort();

      // Fetch previous readings for each room in parallel
      await Future.wait(_rooms.map((r) async {
        final roomId = r['room_id']?.toString();
        if (roomId == null) return;
        try {
          final prev = await MeterReadingService.getSuggestedPreviousReadings(roomId);
          _prevWaterByRoom[roomId] = (prev?['water_previous'] ?? 0.0).toDouble();
          _prevElecByRoom[roomId] = (prev?['electric_previous'] ?? 0.0).toDouble();
        } catch (_) {
          _prevWaterByRoom[roomId] = 0.0;
          _prevElecByRoom[roomId] = 0.0;
        }
        // Init controllers if not exist
        _waterCtrl.putIfAbsent(roomId, () => TextEditingController());
        _elecCtrl.putIfAbsent(roomId, () => TextEditingController());
        _noteCtrl.putIfAbsent(roomId, () => TextEditingController());
      }));

      // Fetch existing readings of the selected month/year for each room
      _existingByRoom.clear();
      _savedRoomIds.clear();
      await Future.wait(_rooms.map((r) async {
        final roomId = r['room_id']?.toString();
        if (roomId == null) return;
        try {
          final list = await MeterReadingService.getAllMeterReadings(
            roomId: roomId,
            readingMonth: _selectedMonth,
            readingYear: _selectedYear,
            includeInitial: false,
            status: 'confirmed',
            limit: 1,
            orderBy: 'created_at',
            ascending: false,
          );
          if (list.isNotEmpty) {
            _existingByRoom[roomId] = list.first;
            _savedRoomIds.add(roomId);
          }
        } catch (_) {}
      }));

      if (mounted) setState(() {});
    } catch (e) {
      _showErrorSnackBar('โหลดห้องไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return monthNames[(month.clamp(1, 12)) - 1];
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    },
                    tooltip: 'ย้อนกลับ',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'บันทึกค่ามิเตอร์แบบลิสต์ทุกห้อง',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'รอบเดือน: ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search & Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาเลขห้อง หรือชื่อผู้เช่า...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 680;
                      final itemWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: TextField(
                              controller: _roomNumberController,
                              onChanged: (v) => setState(() => _roomNumberQuery = v),
                              decoration: const InputDecoration(
                                labelText: 'เลขห้อง',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.meeting_room_outlined),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'หมวดหมู่ห้อง',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: null, child: Text('ทั้งหมด')),
                                ..._categories
                                    .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                                    .toList(),
                              ],
                              onChanged: (val) => setState(() => _selectedCategory = val),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DropdownButtonFormField<int>(
                              value: _selectedMonth,
                              decoration: const InputDecoration(
                                labelText: 'เดือน',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem(value: m, child: Text(_getMonthName(m))))
                                  .toList(),
                              onChanged: (val) async {
                                setState(() => _selectedMonth = val ?? _selectedMonth);
                                await _loadRoomsAndPrevious();
                              },
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: DropdownButtonFormField<int>(
                              value: _selectedYear,
                              decoration: const InputDecoration(
                                labelText: 'ปี (พ.ศ.)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(6, (i) => DateTime.now().year - i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text('${y + 543}')))
                                  .toList(),
                              onChanged: (val) async {
                                setState(() => _selectedYear = val ?? _selectedYear);
                                await _loadRoomsAndPrevious();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isNarrow ? constraints.maxWidth : itemWidth,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: 'รีเฟรช',
                                onPressed: _loadRoomsAndPrevious,
                                icon: const Icon(Icons.refresh, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _isLoading || _loadingRooms
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          const SizedBox(height: 16),
                          Text('กำลังโหลดห้อง...', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : _buildRoomsList(isMobileApp),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Subnavbar(
        currentIndex: 3,
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
    );
  }

  Widget _buildRoomsList(bool isMobileApp) {
    final filtered = _rooms.where((r) {
      // free-text search (ห้องหรือผู้เช่า)
      if (_searchQuery.isNotEmpty) {
        final room = (r['room_number'] ?? '').toString().toLowerCase();
        final tenant = (r['tenant_name'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!room.contains(q) && !tenant.contains(q)) return false;
      }

      // room number filter
      if (_roomNumberQuery.isNotEmpty) {
        final rn = (r['room_number'] ?? '').toString().toLowerCase();
        if (!rn.contains(_roomNumberQuery.toLowerCase())) return false;
      }

      // category filter
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        final cat = (r['room_category_name'] ?? '').toString();
        if (cat != _selectedCategory) return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('ไม่พบบัญชีห้องที่ใช้งาน', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoomsAndPrevious,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final r = filtered[index];
          return _buildRoomCard(r);
        },
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomId = room['room_id']?.toString() ?? '';
    final roomNo = room['room_number']?.toString() ?? '-';
    final cate = room['room_category_name']?.toString() ?? '-';
    final tenant = room['tenant_name']?.toString() ?? '-';

    final prevW = (_prevWaterByRoom[roomId] ?? 0.0).toDouble();
    final prevE = (_prevElecByRoom[roomId] ?? 0.0).toDouble();

    final wCtrl = _waterCtrl[roomId] ??= TextEditingController();
    final eCtrl = _elecCtrl[roomId] ??= TextEditingController();
    final nCtrl = _noteCtrl[roomId] ??= TextEditingController();

    final existing = _existingByRoom[roomId];
    final isEditing = _editingRoomIds.contains(roomId);

    // Resolve previous/current for display/input depending on state
    final displayPrevW = (existing != null && isEditing)
        ? (existing['water_previous_reading'] ?? prevW).toDouble()
        : prevW;
    final displayPrevE = (existing != null && isEditing)
        ? (existing['electric_previous_reading'] ?? prevE).toDouble()
        : prevE;

    final curW = double.tryParse(wCtrl.text.trim());
    final curE = double.tryParse(eCtrl.text.trim());
    final usageW = curW == null ? null : (curW - displayPrevW);
    final usageE = curE == null ? null : (curE - displayPrevE);
    final validW = curW != null && curW >= displayPrevW;
    final validE = curE != null && curE >= displayPrevE;
    final canSaveNew = !_savingRoomIds.contains(roomId) && existing == null && validW && validE && curW != null && curE != null;
    final canSaveEdit = !_savingRoomIds.contains(roomId) && existing != null && isEditing && validW && validE && curW != null && curE != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Icon(Icons.meeting_room, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ห้อง $roomNo • $cate • $tenant',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_existingByRoom.containsKey(roomId))
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Chip(label: Text('มีข้อมูลเดือนนี้'), backgroundColor: Color(0xFFE8F5E9)),
              ),
          ],
        ),
        children: [
          if (existing != null && !isEditing) ...[
            // Read-only view when this month already has data and not in editing mode
            const SizedBox(height: 8),
            _buildReadonlyLine(
              label: 'ค่าน้ำ',
              previous: (existing['water_previous_reading'] ?? 0.0).toDouble(),
              current: (existing['water_current_reading'] ?? 0.0).toDouble(),
              color: Colors.blue[700]!,
            ),
            const SizedBox(height: 8),
            _buildReadonlyLine(
              label: 'ค่าไฟ',
              previous: (existing['electric_previous_reading'] ?? 0.0).toDouble(),
              current: (existing['electric_current_reading'] ?? 0.0).toDouble(),
              color: Colors.orange[700]!,
            ),
            const SizedBox(height: 8),
            if ((existing['reading_notes'] ?? '').toString().isNotEmpty)
              Text('หมายเหตุ: ${existing['reading_notes']}', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _savingRoomIds.contains(roomId)
                      ? null
                      : () {
                          // enter edit mode and prefill controllers
                          _editingRoomIds.add(roomId);
                          wCtrl.text = (existing['water_current_reading'] ?? '').toString();
                          eCtrl.text = (existing['electric_current_reading'] ?? '').toString();
                          nCtrl.text = (existing['reading_notes'] ?? '').toString();
                          setState(() {});
                        },
                  icon: const Icon(Icons.edit),
                  label: const Text('แก้ไข'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _savingRoomIds.contains(roomId)
                      ? null
                      : () => _confirmDelete(existing['reading_id'].toString(), roomId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('ลบ', style: TextStyle(color: Colors.red)),
                ),
                const Spacer(),
                Text('เดือน ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ] else ...[
            // Input view (new or editing existing)
            const SizedBox(height: 8),
            _buildInputLine(
              label: 'ค่าน้ำ',
              previous: displayPrevW,
              controller: wCtrl,
              icon: const Icon(Icons.water_drop, color: Colors.blue),
              error: (curW != null && !validW) ? 'ต้องไม่ต่ำกว่าก่อนหน้า' : null,
              usage: usageW,
              usageColor: Colors.blue[700]!,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _buildInputLine(
              label: 'ค่าไฟ',
              previous: displayPrevE,
              controller: eCtrl,
              icon: const Icon(Icons.electric_bolt, color: Colors.orange),
              error: (curE != null && !validE) ? 'ต้องไม่ต่ำกว่าก่อนหน้า' : null,
              usage: usageE,
              usageColor: Colors.orange[700]!,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nCtrl,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (existing == null) ...[
                  ElevatedButton.icon(
                    onPressed: canSaveNew ? () => _saveRow(room) : null,
                    icon: _savingRoomIds.contains(roomId)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: const Text('บันทึกแถวนี้'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: canSaveEdit ? () => _updateRow(roomId) : null,
                    icon: _savingRoomIds.contains(roomId)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_as_outlined),
                    label: const Text('บันทึกการแก้ไข'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _savingRoomIds.contains(roomId)
                        ? null
                        : () {
                            // Cancel edit
                            _editingRoomIds.remove(roomId);
                            wCtrl.clear();
                            eCtrl.clear();
                            nCtrl.clear();
                            setState(() {});
                          },
                    child: const Text('ยกเลิก'),
                  ),
                ],
                const Spacer(),
                Text('เดือน ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadonlyLine({
    required String label,
    required double previous,
    required double current,
    required Color color,
  }) {
    final usage = (current - previous);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ปัจจุบัน ${current.toStringAsFixed(2)} - ก่อนหน้า ${previous.toStringAsFixed(2)} = ${usage.toStringAsFixed(2)} หน่วย',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLine({
    required String label,
    required double previous,
    required TextEditingController controller,
    required Widget icon,
    String? error,
    double? usage,
    required Color usageColor,
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: usageColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('ก่อนหน้า: ${previous.toStringAsFixed(2)}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'ปัจจุบัน',
                  prefixIcon: icon,
                  errorText: error,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.calculate, size: 16, color: usageColor),
          const SizedBox(width: 6),
          Text(
            'ปัจจุบัน - ก่อนหน้า = ${usage == null ? '-' : usage < 0 ? 'ผิด' : usage.toStringAsFixed(2)} หน่วย',
            style: TextStyle(color: (usage == null || usage >= 0) ? usageColor : Colors.red),
          ),
        ]),
      ],
    );
  }

  Future<void> _saveRow(Map<String, dynamic> room) async {
    final roomId = room['room_id']?.toString();
    final tenantId = room['tenant_id']?.toString();
    final contractId = room['contract_id']?.toString();
    if (roomId == null || tenantId == null || contractId == null) {
      _showErrorSnackBar('ข้อมูลไม่ครบ ไม่สามารถบันทึกได้');
      return;
    }

    final wCtrl = _waterCtrl[roomId]!;
    final eCtrl = _elecCtrl[roomId]!;
    final nCtrl = _noteCtrl[roomId]!;
    final prevW = _prevWaterByRoom[roomId] ?? 0.0;
    final prevE = _prevElecByRoom[roomId] ?? 0.0;
    final curW = double.tryParse(wCtrl.text.trim());
    final curE = double.tryParse(eCtrl.text.trim());

    if (curW == null || curE == null) {
      _showErrorSnackBar('กรุณากรอกตัวเลขให้ถูกต้อง');
      return;
    }
    if (curW < prevW) {
      _showErrorSnackBar('ค่าน้ำปัจจุบันต้องไม่ต่ำกว่าค่าก่อนหน้า');
      return;
    }
    if (curE < prevE) {
      _showErrorSnackBar('ค่าไฟปัจจุบันต้องไม่ต่ำกว่าค่าก่อนหน้า');
      return;
    }

    setState(() => _savingRoomIds.add(roomId));
    try {
      final payload = {
        'room_id': roomId,
        'tenant_id': tenantId,
        'contract_id': contractId,
        'is_initial_reading': false,
        'reading_month': _selectedMonth,
        'reading_year': _selectedYear,
        'water_previous_reading': prevW,
        'electric_previous_reading': prevE,
        'water_current_reading': curW,
        'electric_current_reading': curE,
        'reading_date': DateTime.now().toIso8601String().split('T')[0],
        'reading_notes': nCtrl.text.trim().isEmpty ? null : nCtrl.text.trim(),
      };

      final res = await MeterReadingService.createMeterReading(payload);
      if (res['success'] == true) {
        _showSuccessSnackBar('บันทึกสำเร็จ และยืนยันอัตโนมัติ');
        _savedRoomIds.add(roomId);
        // Store as existing for read-only view
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        _existingByRoom[roomId] = data;
        // Clear inputs and refresh previous suggestions for next month logic
        wCtrl.clear();
        eCtrl.clear();
        nCtrl.clear();
        setState(() {});
      } else {
        _showErrorSnackBar(res['message'] ?? 'บันทึกไม่สำเร็จ');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _savingRoomIds.remove(roomId));
    }
  }

  Future<void> _updateRow(String roomId) async {
    final existing = _existingByRoom[roomId];
    if (existing == null) return;

    final wCtrl = _waterCtrl[roomId]!;
    final eCtrl = _elecCtrl[roomId]!;
    final nCtrl = _noteCtrl[roomId]!;

    final prevW = (existing['water_previous_reading'] ?? 0.0).toDouble();
    final prevE = (existing['electric_previous_reading'] ?? 0.0).toDouble();
    final curW = double.tryParse(wCtrl.text.trim());
    final curE = double.tryParse(eCtrl.text.trim());

    if (curW == null || curE == null) {
      _showErrorSnackBar('กรุณากรอกตัวเลขให้ถูกต้อง');
      return;
    }
    if (curW < prevW) {
      _showErrorSnackBar('ค่าน้ำปัจจุบันต้องไม่ต่ำกว่าค่าก่อนหน้า');
      return;
    }
    if (curE < prevE) {
      _showErrorSnackBar('ค่าไฟปัจจุบันต้องไม่ต่ำกว่าค่าก่อนหน้า');
      return;
    }

    final readingId = (existing['reading_id'] ?? '').toString();
    if (readingId.isEmpty) return;

    setState(() => _savingRoomIds.add(roomId));
    try {
      final payload = {
        'water_previous_reading': prevW,
        'electric_previous_reading': prevE,
        'water_current_reading': curW,
        'electric_current_reading': curE,
        'reading_date': DateTime.now().toIso8601String().split('T')[0],
        'reading_notes': nCtrl.text.trim().isEmpty ? null : nCtrl.text.trim(),
      };
      final res = await MeterReadingService.updateMeterReading(readingId, payload);
      if (res['success'] == true) {
        _showSuccessSnackBar('บันทึกการแก้ไขสำเร็จ');
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        _existingByRoom[roomId] = data;
        _editingRoomIds.remove(roomId);
        // Clear inputs
        wCtrl.clear();
        eCtrl.clear();
        nCtrl.clear();
        setState(() {});
      } else {
        _showErrorSnackBar(res['message'] ?? 'แก้ไขไม่สำเร็จ');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _savingRoomIds.remove(roomId));
    }
  }

  Future<void> _confirmDelete(String readingId, String roomId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบข้อมูลค่ามิเตอร์ของเดือนนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _savingRoomIds.add(roomId));
    try {
      final res = await MeterReadingService.deleteMeterReading(readingId);
      if (res['success'] == true) {
        _showSuccessSnackBar('ลบข้อมูลสำเร็จ');
        _existingByRoom.remove(roomId);
        _savedRoomIds.remove(roomId);
        _editingRoomIds.remove(roomId);
        // Clear inputs
        _waterCtrl[roomId]?.clear();
        _elecCtrl[roomId]?.clear();
        _noteCtrl[roomId]?.clear();
        // Refresh previous suggestions (optional)
        try {
          final prev = await MeterReadingService.getSuggestedPreviousReadings(roomId);
          _prevWaterByRoom[roomId] = (prev?['water_previous'] ?? 0.0).toDouble();
          _prevElecByRoom[roomId] = (prev?['electric_previous'] ?? 0.0).toDouble();
        } catch (_) {}
        setState(() {});
      } else {
        _showErrorSnackBar(res['message'] ?? 'ลบไม่สำเร็จ');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _savingRoomIds.remove(roomId));
    }
  }

  // Snackbars
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
