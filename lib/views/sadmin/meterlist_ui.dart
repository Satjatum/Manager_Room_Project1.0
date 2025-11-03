import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/meter_service.dart';
import '../../services/utility_rate_service.dart';
import '../../services/invoice_service.dart';
import 'invoice_add_ui.dart';
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
  // For rooms with no history: allow entering "previous" too
  final Map<String, TextEditingController> _prevWaterCtrl = {};
  final Map<String, TextEditingController> _prevElecCtrl = {};
  final Set<String> _needsPrevWaterInput = {};
  final Set<String> _needsPrevElecInput = {};

  // Controllers per room_id (note only; meter inputs are dynamic per utility)
  final Map<String, TextEditingController> _noteCtrl = {};

  // Saving state and saved flags
  final Set<String> _savingRoomIds = {};
  final Set<String> _savedRoomIds = {};

  // Existing readings for selected month/year per room_id
  final Map<String, Map<String, dynamic>> _existingByRoom = {};
  // Previous month reading for selected period (room_id -> reading) when selected month has no data
  final Map<String, Map<String, dynamic>> _prevMonthReadingByRoom = {};
  final Set<String> _editingRoomIds = {};

  // Invoice utilities snapshot for billed readings (room_id -> list of utilities)
  final Map<String, List<Map<String, dynamic>>> _invoiceUtilsByRoom = {};
  // Keep invoice id for room if any
  final Map<String, String> _invoiceIdByRoom = {};

  // Dynamic metered rates from utility settings (by branch)
  List<Map<String, dynamic>> _meteredRates = [];
  // Controllers for dynamic meters per room and rate_id
  final Map<String, Map<String, TextEditingController>> _dynPrevCtrls = {};
  final Map<String, Map<String, TextEditingController>> _dynCurCtrls = {};

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year; // ค.ศ. (แสดงผล พ.ศ.)

  // Period helpers
  bool get _isCurrentPeriod {
    final now = DateTime.now();
    return _selectedMonth == now.month && _selectedYear == now.year;
  }

  bool get _isFuturePeriod {
    final now = DateTime.now();
    return _selectedYear > now.year ||
        (_selectedYear == now.year && _selectedMonth > now.month);
  }

  bool get _isPastPeriod => !_isCurrentPeriod && !_isFuturePeriod;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
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
      await _loadMeteredRates();
      await _loadRoomsAndPrevious();
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMeteredRates() async {
    try {
      final branchId = widget.branchId;
      if (branchId == null || branchId.isEmpty) {
        _meteredRates = [];
        return;
      }
      final rates = await UtilityRatesService.getMeteredRates(branchId);
      // ใช้เฉพาะค่าน้ำและค่าไฟเท่านั้น
      _meteredRates = rates.where((r) {
        final name = (r['rate_name'] ?? '').toString().toLowerCase();
        return name.contains('น้ำ') ||
            name.contains('water') ||
            name.contains('ไฟ') ||
            name.contains('electric');
      }).toList();
    } catch (e) {
      _meteredRates = [];
    }
  }

  bool _isWaterRate(Map<String, dynamic> rate) {
    final name = (rate['rate_name'] ?? '').toString().toLowerCase();
    return name.contains('น้ำ') || name.contains('water');
  }

  bool _isElectricRate(Map<String, dynamic> rate) {
    final name = (rate['rate_name'] ?? '').toString().toLowerCase();
    return name.contains('ไฟ') || name.contains('electric');
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
          final prev = await MeterReadingService.getPreviousForMonth(
              roomId, _selectedMonth, _selectedYear);
          if (prev == null) {
            // No previous at all -> require input for previous
            _needsPrevWaterInput.add(roomId);
            _needsPrevElecInput.add(roomId);
            _prevWaterByRoom[roomId] = 0.0;
            _prevElecByRoom[roomId] = 0.0;
          } else {
            _prevWaterByRoom[roomId] =
                (prev['water_previous'] ?? 0.0).toDouble();
            _prevElecByRoom[roomId] =
                (prev['electric_previous'] ?? 0.0).toDouble();
          }
        } catch (_) {
          _prevWaterByRoom[roomId] = 0.0;
          _prevElecByRoom[roomId] = 0.0;
          // On error, keep as not requiring previous input; user can still input current
        }
        // Init controllers if not exist
        _noteCtrl.putIfAbsent(roomId, () => TextEditingController());
        _prevWaterCtrl.putIfAbsent(roomId, () => TextEditingController());
        _prevElecCtrl.putIfAbsent(roomId, () => TextEditingController());
        // Init dynamic controllers for this room (include all metered rates)
        if (_meteredRates.isNotEmpty) {
          _dynPrevCtrls.putIfAbsent(roomId, () => {});
          _dynCurCtrls.putIfAbsent(roomId, () => {});
          for (final rate in _meteredRates) {
            final rateId = (rate['rate_id'] ?? '').toString();
            if (rateId.isEmpty) continue;
            final prev = _dynPrevCtrls[roomId]!
                .putIfAbsent(rateId, () => TextEditingController());
            _dynCurCtrls[roomId]!
                .putIfAbsent(rateId, () => TextEditingController());
            // Prefill water/electric previous from computed suggestions
            if ((prev.text.isEmpty)) {
              if (_isWaterRate(Map<String, dynamic>.from(rate))) {
                prev.text = (_prevWaterByRoom[roomId] ?? 0.0).toString();
              } else if (_isElectricRate(Map<String, dynamic>.from(rate))) {
                prev.text = (_prevElecByRoom[roomId] ?? 0.0).toString();
              }
            }
          }
        }
      }));

      // Fetch existing readings of the selected month/year for each room
      _existingByRoom.clear();
      _prevMonthReadingByRoom.clear();
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
            limit: 1,
            orderBy: 'created_at',
            ascending: false,
          );
          if (list.isNotEmpty) {
            _existingByRoom[roomId] = list.first;
            _savedRoomIds.add(roomId);
            final status = (list.first['reading_status'] ?? '').toString();
            final invoiceId = (list.first['invoice_id'] ?? '').toString();
            if (status == 'billed' && invoiceId.isNotEmpty) {
              try {
                final inv = await InvoiceService.getInvoiceById(invoiceId);
                final utils = List<Map<String, dynamic>>.from(
                    inv?['utilities'] ?? const []);
                _invoiceUtilsByRoom[roomId] = utils;
                _invoiceIdByRoom[roomId] = invoiceId;
              } catch (_) {}
            }
          } else if (_isPastPeriod) {
            // For past periods with no data -> try immediate previous month
            int prevMonth = _selectedMonth - 1;
            int prevYear = _selectedYear;
            if (prevMonth <= 0) {
              prevMonth = 12;
              prevYear -= 1;
            }
            final prevList = await MeterReadingService.getAllMeterReadings(
              roomId: roomId,
              readingMonth: prevMonth,
              readingYear: prevYear,
              includeInitial: false,
              limit: 1,
              orderBy: 'created_at',
              ascending: false,
            );
            if (prevList.isNotEmpty) {
              _prevMonthReadingByRoom[roomId] = prevList.first;
            }
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
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop())
                        Navigator.of(context).pop();
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
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
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
                        hintStyle:
                            TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[600], size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey[600], size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // เลขห้อง + หมวดหมู่ห้อง
                      Row(
                        children: [
                          // เลขห้อง
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.meeting_room_outlined,
                                      size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _roomNumberController,
                                      onChanged: (v) =>
                                          setState(() => _roomNumberQuery = v),
                                      decoration: const InputDecoration(
                                        hintText: 'เลขห้อง',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // หมวดหมู่ห้อง
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.grid_view_outlined,
                                      size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String?>(
                                        value: _selectedCategory,
                                        isExpanded: true,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 20),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                        onChanged: (val) => setState(
                                            () => _selectedCategory = val),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('ทั้งหมด')),
                                          ..._categories
                                              .map((c) =>
                                                  DropdownMenuItem<String?>(
                                                      value: c, child: Text(c)))
                                              .toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // เดือน + ปี (พ.ศ.)
                      Row(
                        children: [
                          // เดือน
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 18, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _selectedMonth,
                                        isExpanded: true,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 20),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                        items: List.generate(12, (i) => i + 1)
                                            .map((m) => DropdownMenuItem(
                                                value: m,
                                                child: Text(_getMonthName(m))))
                                            .toList(),
                                        onChanged: (val) async {
                                          setState(() => _selectedMonth =
                                              val ?? _selectedMonth);
                                          await _loadRoomsAndPrevious();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ปี (พ.ศ.)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.date_range,
                                      size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _selectedYear,
                                        isExpanded: true,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 20),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                        items: List.generate(6,
                                                (i) => DateTime.now().year - i)
                                            .map((y) => DropdownMenuItem(
                                                value: y,
                                                child: Text('${y + 543}')))
                                            .toList(),
                                        onChanged: (val) async {
                                          setState(() => _selectedYear =
                                              val ?? _selectedYear);
                                          await _loadRoomsAndPrevious();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  _buildPeriodBanner(),
                  if (_meteredRates.isEmpty) ...[
                    const SizedBox(height: 8),
                    _buildUtilityMissingHelper(),
                  ],
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
                          Text('กำลังโหลดห้อง...',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : _buildRoomsList(isMobileApp),
            ),
          ],
        ),
      ),
    );
  }

  // Responsive container widths (Mobile S/M/L, Tablet, Laptop, Laptop L, 4K)
  double _maxContentWidth(double screenWidth) {
    if (screenWidth >= 2560) return 1280; // 4K
    if (screenWidth >= 1440) return 1100; // Laptop L
    if (screenWidth >= 1200) return 1000; // Laptop
    if (screenWidth >= 900) return 860; // Tablet landscape / small desktop
    if (screenWidth >= 600) return 560; // Mobile L / Tablet portrait
    return screenWidth; // Mobile S/M: full width
  }

  Widget _buildPeriodBanner() {
    if (_isCurrentPeriod) return const SizedBox.shrink();
    String message;
    Color color;
    IconData icon;
    if (_isPastPeriod) {
      message =
          'เดือนที่ผ่านมาย้อนหลัง: ดูได้อย่างเดียว แก้ไข/ลบ/สร้างย้อนหลังไม่ได้';
      color = Colors.blueGrey.shade50;
      icon = Icons.info_outline;
    } else {
      message = 'เดือนอนาคต: ยังไม่เปิดให้บันทึก แสดงเพื่อดูข้อมูลเท่านั้น';
      color = Colors.amber.shade50;
      icon = Icons.lock_clock;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
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
            Icon(Icons.meeting_room_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('ไม่พบบัญชีห้องที่ใช้งาน',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // DataTable view with tabs: น้ำ และ ไฟ แยก Tab และให้ตารางเต็มหน้าจอ
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                labelColor: Colors.black87,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.water_drop, color: Colors.blue), text: 'ค่าน้ำ'),
                  Tab(icon: Icon(Icons.electric_bolt, color: Colors.orange), text: 'ค่าไฟ'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRoomsAndPrevious,
              color: AppTheme.primary,
              child: TabBarView(
                children: [
                  // Water tab
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildHorizontalTable(_buildWaterDataTable(filtered)),
                  ),
                  // Electric tab
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildHorizontalTable(_buildElectricDataTable(filtered)),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    final nCtrl = _noteCtrl[roomId] ??= TextEditingController();

    final existing = _existingByRoom[roomId];
    final isEditing = _editingRoomIds.contains(roomId);

    // Resolve previous/current for display/input depending on state
    // Resolve water/electric from dynamic controllers (from Utility Settings)
    String? waterRateId;
    String? electricRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (waterRateId == null && _isWaterRate(r)) waterRateId = rid;
      if (electricRateId == null && _isElectricRate(r)) electricRateId = rid;
    }

    final prevMapDyn = _dynPrevCtrls[roomId];
    final curMapDyn = _dynCurCtrls[roomId];
    final pvWCtrlDyn = (waterRateId != null && prevMapDyn != null)
        ? prevMapDyn[waterRateId!]
        : null;
    final cvWCtrlDyn = (waterRateId != null && curMapDyn != null)
        ? curMapDyn[waterRateId!]
        : null;
    final pvECtrlDyn = (electricRateId != null && prevMapDyn != null)
        ? prevMapDyn[electricRateId!]
        : null;
    final cvECtrlDyn = (electricRateId != null && curMapDyn != null)
        ? curMapDyn[electricRateId!]
        : null;

    final displayPrevW = (existing != null && isEditing)
        ? (existing['water_previous_reading'] ?? prevW).toDouble()
        : (double.tryParse((pvWCtrlDyn?.text ?? '').trim()) ?? prevW);
    final displayPrevE = (existing != null && isEditing)
        ? (existing['electric_previous_reading'] ?? prevE).toDouble()
        : (double.tryParse((pvECtrlDyn?.text ?? '').trim()) ?? prevE);

    final curW = double.tryParse((cvWCtrlDyn?.text ?? '').trim());
    final curE = double.tryParse((cvECtrlDyn?.text ?? '').trim());
    final usageW = curW == null ? null : (curW - displayPrevW);
    final usageE = curE == null ? null : (curE - displayPrevE);
    final validW = curW != null && curW >= displayPrevW;
    final validE = curE != null && curE >= displayPrevE;
    final canSaveNew = _isCurrentPeriod &&
        !_savingRoomIds.contains(roomId) &&
        existing == null &&
        validW &&
        validE &&
        curW != null &&
        curE != null;
    final canSaveEdit = _isCurrentPeriod &&
        !_savingRoomIds.contains(roomId) &&
        existing != null &&
        isEditing &&
        validW &&
        validE &&
        curW != null &&
        curE != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                  '$cate $roomNo',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_existingByRoom.containsKey(roomId))
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Chip(
                      label: Text('มีข้อมูลเดือนนี้'),
                      backgroundColor: Color(0xFFE8F5E9)),
                ),
            ],
          ),
          children: [
            if (existing != null && !isEditing) ...[
              // Read-only view when this month already has data and not in editing mode
              const SizedBox(height: 8),
              // If billed -> show utilities snapshot from invoice (each utility as a line)
              if ((existing['reading_status'] ?? '') == 'billed' &&
                  _invoiceUtilsByRoom.containsKey(roomId)) ...[
                ..._invoiceUtilsByRoom[roomId]!.where((u) {
                  final name =
                      (u['utility_name'] ?? '').toString().toLowerCase();
                  return name.contains('น้ำ') ||
                      name.contains('water') ||
                      name.contains('ไฟ') ||
                      name.contains('electric');
                }).map((u) {
                  final name = (u['utility_name'] ?? 'สาธารณูปโภค').toString();
                  final usage = (u['usage_amount'] ?? 0.0).toDouble();
                  final total = (u['total_amount'] ?? 0.0).toDouble();
                  final isWater = name.contains('น้ำ') ||
                      name.toLowerCase().contains('water');
                  final isElec = name.contains('ไฟ') ||
                      name.toLowerCase().contains('electric');
                  final color = isWater
                      ? Colors.blue[700]!
                      : isElec
                          ? Colors.orange[700]!
                          : const Color(0xFF10B981);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildInvoiceUtilityReadonlyLine(
                      label: name,
                      usage: usage,
                      total: total,
                      color: color,
                    ),
                  );
                }).toList(),
              ] else ...[
                _buildReadonlyLine(
                  label: 'ค่าน้ำ',
                  previous:
                      (existing['water_previous_reading'] ?? 0.0).toDouble(),
                  current:
                      (existing['water_current_reading'] ?? 0.0).toDouble(),
                  color: Colors.blue[700]!,
                ),
                const SizedBox(height: 8),
                _buildReadonlyLine(
                  label: 'ค่าไฟ',
                  previous:
                      (existing['electric_previous_reading'] ?? 0.0).toDouble(),
                  current:
                      (existing['electric_current_reading'] ?? 0.0).toDouble(),
                  color: Colors.orange[700]!,
                ),
              ],
              const SizedBox(height: 8),
              if ((existing['reading_notes'] ?? '').toString().isNotEmpty)
                Text('หมายเหตุ: ${existing['reading_notes']}',
                    style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_isCurrentPeriod) ...[
                    if ((existing['reading_status'] ?? '') != 'billed') ...[
                      OutlinedButton.icon(
                        onPressed: _savingRoomIds.contains(roomId)
                            ? null
                            : () {
                                // enter edit mode and prefill dynamic controllers
                                _editingRoomIds.add(roomId);
                                String? waterRateId;
                                String? electricRateId;
                                for (final rate in _meteredRates) {
                                  final r = Map<String, dynamic>.from(rate);
                                  final rid = (r['rate_id'] ?? '').toString();
                                  if (rid.isEmpty) continue;
                                  if (waterRateId == null && _isWaterRate(r))
                                    waterRateId = rid;
                                  if (electricRateId == null &&
                                      _isElectricRate(r)) electricRateId = rid;
                                }
                                if (waterRateId != null) {
                                  final curMap = _dynCurCtrls[roomId];
                                  final prevMap = _dynPrevCtrls[roomId];
                                  final curCtrl =
                                      curMap != null ? curMap[waterRateId!] : null;
                                  final prevCtrl =
                                      prevMap != null ? prevMap[waterRateId!] : null;
                                  curCtrl?.text =
                                      (existing['water_current_reading'] ?? '')
                                          .toString();
                                  prevCtrl?.text =
                                      (existing['water_previous_reading'] ?? '')
                                          .toString();
                                }
                                if (electricRateId != null) {
                                  final curMap = _dynCurCtrls[roomId];
                                  final prevMap = _dynPrevCtrls[roomId];
                                  final curCtrl = curMap != null
                                      ? curMap[electricRateId!]
                                      : null;
                                  final prevCtrl = prevMap != null
                                      ? prevMap[electricRateId!]
                                      : null;
                                  curCtrl?.text =
                                      (existing['electric_current_reading'] ??
                                              '')
                                          .toString();
                                  prevCtrl?.text =
                                      (existing['electric_previous_reading'] ??
                                              '')
                                          .toString();
                                }
                                nCtrl.text = (existing['reading_notes'] ?? '')
                                    .toString();
                                setState(() {});
                              },
                        icon: const Icon(Icons.edit),
                        label: const Text('แก้ไข'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _savingRoomIds.contains(roomId)
                            ? null
                            : () => _confirmDelete(
                                existing['reading_id'].toString(), roomId),
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('ลบ',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ] else ...[
                      // billed: no edit, only delete (delete invoice then reading)
                      TextButton.icon(
                        onPressed: _savingRoomIds.contains(roomId)
                            ? null
                            : () => _confirmDeleteBilled(
                                  existing['reading_id'].toString(),
                                  (_invoiceIdByRoom[roomId] ?? ''),
                                  roomId,
                                ),
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('ลบ (รวมบิลเดือนนี้)',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                  const Spacer(),
                  Text(
                      'เดือน ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ] else if (_isPastPeriod) ...[
              // Past period with no data: show previous month data if available
              const SizedBox(height: 8),
              _buildNoDataThisMonthLabel(),
              const SizedBox(height: 8),
              if (_prevMonthReadingByRoom.containsKey(roomId)) ...[
                _buildPrevMonthReadonly(roomId),
                const SizedBox(height: 8),
              ] else ...[
                _buildNoPrevMonthLabel(),
                const SizedBox(height: 8),
              ],
            ] else if (_isFuturePeriod) ...[
              // Future period: locked view
              const SizedBox(height: 8),
              _buildDisabledHelp(),
              const SizedBox(height: 8),
            ] else ...[
              // Input view (new or editing existing)
              const SizedBox(height: 8),
              // Dynamic meter lines from utility settings (UI only) — เฉพาะน้ำ/ไฟเท่านั้น
              ...() {
                final rates = _meteredRates.where((rate) {
                  final r = Map<String, dynamic>.from(rate);
                  return _isWaterRate(r) || _isElectricRate(r);
                }).toList();
                if (rates.isEmpty) return <Widget>[];
                return <Widget>[
                  ...rates.map((rate) {
                    final rateId = (rate['rate_id'] ?? '').toString();
                    if (rateId.isEmpty) return const SizedBox.shrink();
                    final name = (rate['rate_name'] ?? 'มิเตอร์').toString();
                    final prevMap = _dynPrevCtrls[roomId] ?? const {};
                    final curMap = _dynCurCtrls[roomId] ?? const {};
                    final pvCtrl = prevMap[rateId] ?? TextEditingController();
                    final cvCtrl = curMap[rateId] ?? TextEditingController();
                    final isWater =
                        _isWaterRate(Map<String, dynamic>.from(rate));
                    final isElec =
                        _isElectricRate(Map<String, dynamic>.from(rate));
                    final icon = isWater
                        ? const Icon(Icons.water_drop, color: Colors.blue)
                        : isElec
                            ? const Icon(Icons.electric_bolt,
                                color: Colors.orange)
                            : const Icon(Icons.speed_outlined,
                                color: Color(0xFF10B981));
                    final prevVal = double.tryParse(pvCtrl.text.trim()) ??
                        (isWater
                            ? prevW
                            : isElec
                                ? prevE
                                : 0.0);
                    final curVal = double.tryParse(cvCtrl.text.trim());
                    final usage = curVal == null ? null : (curVal - prevVal);
                    final err = (curVal != null && curVal < prevVal)
                        ? 'ต้องไม่ต่ำกว่าก่อนหน้า'
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInputLine(
                        label: name,
                        previous: prevVal,
                        controller: cvCtrl,
                        icon: icon,
                        error: err,
                        usage: usage,
                        usageColor: isWater
                            ? Colors.blue[700]!
                            : isElec
                                ? Colors.orange[700]!
                                : const Color(0xFF10B981),
                        onChanged: () => setState(() {}),
                        editablePrevious: true,
                        previousController: pvCtrl,
                      ),
                    );
                  }).toList(),
                ];
              }(),
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
                    ElevatedButton(
                      onPressed: canSaveNew ? () => _saveRow(room) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_savingRoomIds.contains(roomId))
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          if (_savingRoomIds.contains(roomId))
                            const SizedBox(width: 8),
                          const Text('บันทึกแถวนี้'),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: canSaveEdit ? () => _updateRow(roomId) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_savingRoomIds.contains(roomId))
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          if (_savingRoomIds.contains(roomId))
                            const SizedBox(width: 8),
                          const Text('บันทึกการแก้ไข'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _savingRoomIds.contains(roomId)
                          ? null
                          : () {
                              // Cancel edit
                              _editingRoomIds.remove(roomId);
                              nCtrl.clear();
                              setState(() {});
                            },
                      child: const Text('ยกเลิก'),
                    ),
                  ],
                  const Spacer(),
                  Text(
                      'เดือน ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- DataTable builders ---
  Widget _buildHorizontalTable(Widget table) {
    // ทำให้ DataTable กว้างเต็มหน้าจอ และเลื่อนแนวนอนได้เมื่อคอลัมน์ยาว
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: table,
          ),
        );
      },
    );
  }

  Widget _buildWaterDataTable(List<Map<String, dynamic>> rooms) {
    // หา rate id ของน้ำ
    String? waterRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (_isWaterRate(r)) {
        waterRateId = rid;
        break;
      }
    }

    final rows = rooms.map((room) {
      final roomId = (room['room_id'] ?? '').toString();
      final roomNo = (room['room_number'] ?? '-').toString();
      final tenant = (room['tenant_name'] ?? '-').toString();
      final existing = _existingByRoom[roomId];

      // previous/current for water
      final prev = (existing != null)
          ? (existing['water_previous_reading'] ?? 0.0).toDouble()
          : (_prevWaterByRoom[roomId] ?? 0.0).toDouble();
      final curMapForWater = _dynCurCtrls[roomId];
      final cvCtrl = (waterRateId != null && curMapForWater != null)
          ? curMapForWater[waterRateId!]
          : null;
      final current = (existing != null)
          ? (existing['water_current_reading'] ?? 0.0).toDouble()
          : double.tryParse((cvCtrl?.text ?? '').trim());
      final usage = (current != null) ? (current - prev) : null;
      final status = (existing == null)
          ? 'ยังไม่บันทึก'
          : ((existing['reading_status'] ?? '').toString() == 'billed'
              ? 'ออกบิลแล้ว'
              : 'ยืนยันแล้ว');

      final statusStr = (existing == null)
          ? 'ยังไม่บันทึก'
          : ((existing['reading_status'] ?? '').toString() == 'billed'
              ? 'ออกบิลแล้ว'
              : 'ยืนยันแล้ว');

      final canEdit = _isCurrentPeriod &&
          existing != null &&
          (existing['reading_status'] ?? '') != 'billed' &&
          !_savingRoomIds.contains(roomId);
      final canDelete = _isCurrentPeriod &&
          existing != null &&
          !_savingRoomIds.contains(roomId);

      return DataRow(cells: [
        DataCell(Text(roomNo)),
        DataCell(Text(tenant, overflow: TextOverflow.ellipsis)),
        DataCell(Text(prev.toStringAsFixed(0))),
        DataCell(Text(current != null ? current.toStringAsFixed(0) : '-')),
        DataCell(Text(usage != null ? usage.toStringAsFixed(2) : '-')),
        DataCell(Text(statusStr)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: canEdit ? () => _showEditDialog(roomId) : null,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('แก้ไข'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: canDelete
                  ? () {
                      final rid = (existing?['reading_id'] ?? '').toString();
                      final isBilled =
                          ((existing?['reading_status'] ?? '') == 'billed');
                      if (isBilled) {
                        _confirmDeleteBilled(
                          rid,
                          (_invoiceIdByRoom[roomId] ?? ''),
                          roomId,
                        );
                      } else {
                        _confirmDelete(rid, roomId);
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('ลบ', style: TextStyle(color: Colors.red)),
            ),
          ],
        )),
      ]);
    }).toList();

    return DataTable(
      columns: const [
        DataColumn(label: Text('ห้อง')),
        DataColumn(label: Text('ผู้เช่า')),
        DataColumn(label: Text('ก่อนหน้า')),
        DataColumn(label: Text('ปัจจุบัน')),
        DataColumn(label: Text('ใช้งาน')),
        DataColumn(label: Text('สถานะ')),
        DataColumn(label: Text('การกระทำ')),
      ],
      rows: rows,
      headingRowColor:
          MaterialStateProperty.all(Colors.blue.withOpacity(0.06)),
      dataRowColor: MaterialStateProperty.all(Colors.white),
      border: TableBorder.symmetric(
        inside: BorderSide(color: Colors.grey[300]!),
        outside: BorderSide.none,
      ),
    );
  }

  Widget _buildElectricDataTable(List<Map<String, dynamic>> rooms) {
    // หา rate id ของไฟ
    String? electricRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (_isElectricRate(r)) {
        electricRateId = rid;
        break;
      }
    }

    final rows = rooms.map((room) {
      final roomId = (room['room_id'] ?? '').toString();
      final roomNo = (room['room_number'] ?? '-').toString();
      final tenant = (room['tenant_name'] ?? '-').toString();
      final existing = _existingByRoom[roomId];

      final prev = (existing != null)
          ? (existing['electric_previous_reading'] ?? 0.0).toDouble()
          : (_prevElecByRoom[roomId] ?? 0.0).toDouble();
      final curMapForElec = _dynCurCtrls[roomId];
      final cvCtrl = (electricRateId != null && curMapForElec != null)
          ? curMapForElec[electricRateId!]
          : null;
      final current = (existing != null)
          ? (existing['electric_current_reading'] ?? 0.0).toDouble()
          : double.tryParse((cvCtrl?.text ?? '').trim());
      final usage = (current != null) ? (current - prev) : null;
      final status = (existing == null)
          ? 'ยังไม่บันทึก'
          : ((existing['reading_status'] ?? '').toString() == 'billed'
              ? 'ออกบิลแล้ว'
              : 'ยืนยันแล้ว');

      final canEdit = _isCurrentPeriod &&
          existing != null &&
          (existing['reading_status'] ?? '') != 'billed' &&
          !_savingRoomIds.contains(roomId);
      final canDelete = _isCurrentPeriod &&
          existing != null &&
          !_savingRoomIds.contains(roomId);

      return DataRow(cells: [
        DataCell(Text(roomNo)),
        DataCell(Text(tenant, overflow: TextOverflow.ellipsis)),
        DataCell(Text(prev.toStringAsFixed(0))),
        DataCell(Text(current != null ? current.toStringAsFixed(0) : '-')),
        DataCell(Text(usage != null ? usage.toStringAsFixed(2) : '-')),
        DataCell(Text(status)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: canEdit ? () => _showEditDialog(roomId) : null,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('แก้ไข'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: canDelete
                  ? () {
                      final rid = (existing?['reading_id'] ?? '').toString();
                      final isBilled =
                          ((existing?['reading_status'] ?? '') == 'billed');
                      if (isBilled) {
                        _confirmDeleteBilled(
                          rid,
                          (_invoiceIdByRoom[roomId] ?? ''),
                          roomId,
                        );
                      } else {
                        _confirmDelete(rid, roomId);
                      }
                    }
                  : null,
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('ลบ', style: TextStyle(color: Colors.red)),
            ),
          ],
        )),
      ]);
    }).toList();

    return DataTable(
      columns: const [
        DataColumn(label: Text('ห้อง')),
        DataColumn(label: Text('ผู้เช่า')),
        DataColumn(label: Text('ก่อนหน้า')),
        DataColumn(label: Text('ปัจจุบัน')),
        DataColumn(label: Text('ใช้งาน')),
        DataColumn(label: Text('สถานะ')),
        DataColumn(label: Text('การกระทำ')),
      ],
      rows: rows,
      headingRowColor:
          MaterialStateProperty.all(Colors.orange.withOpacity(0.06)),
      dataRowColor: MaterialStateProperty.all(Colors.white),
      border: TableBorder.symmetric(
        inside: BorderSide(color: Colors.grey[300]!),
        outside: BorderSide.none,
      ),
    );
  }

  Future<void> _showEditDialog(String roomId) async {
    final existing = _existingByRoom[roomId];
    if (existing == null) return;

    // Resolve rate IDs
    String? waterRateId;
    String? electricRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (waterRateId == null && _isWaterRate(r)) waterRateId = rid;
      if (electricRateId == null && _isElectricRate(r)) electricRateId = rid;
    }

    final curMap = _dynCurCtrls[roomId];
    final nCtrl = _noteCtrl[roomId] ??= TextEditingController();
    // Prefill current values from existing
    if (waterRateId != null && curMap != null) {
      final cvW = curMap[waterRateId!];
      cvW?.text = (existing['water_current_reading'] ?? '').toString();
    }
    if (electricRateId != null && curMap != null) {
      final cvE = curMap[electricRateId!];
      cvE?.text = (existing['electric_current_reading'] ?? '').toString();
    }
    nCtrl.text = (existing['reading_notes'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('แก้ไขค่ามิเตอร์เดือนนี้'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('ค่าน้ำ'),
                    const Spacer(),
                    Text('ก่อนหน้า: '
                        '${(existing['water_previous_reading'] ?? 0).toString()}'),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: waterRateId != null && curMap != null
                      ? curMap[waterRateId!]
                      : null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ปัจจุบัน (น้ำ)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.electric_bolt, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('ค่าไฟ'),
                    const Spacer(),
                    Text('ก่อนหน้า: '
                        '${(existing['electric_previous_reading'] ?? 0).toString()}'),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: electricRateId != null && curMap != null
                      ? curMap[electricRateId!]
                      : null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ปัจจุบัน (ไฟ)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateRow(roomId);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  bool _canIssueBill(String roomId) {
    final existing = _existingByRoom[roomId];
    if (existing == null) return false;
    final status = (existing['reading_status'] ?? '').toString();
    // ต้องบันทึกน้ำและไฟครบ และยังไม่ออกบิล
    final hasWater = existing['water_current_reading'] != null;
    final hasElec = existing['electric_current_reading'] != null;
    final notBilled = status != 'billed';
    return hasWater && hasElec && status == 'confirmed' && notBilled;
  }

  Future<void> _goToInvoiceFromRoom(String roomId) async {
    final existing = _existingByRoom[roomId];
    if (existing == null) return;
    final initial = {
      'branch_id': existing['branch_id'],
      'room_id': existing['room_id'],
      'tenant_id': existing['tenant_id'],
      'contract_id': existing['contract_id'],
      'reading_id': existing['reading_id'],
      'invoice_month': existing['reading_month'],
      'invoice_year': existing['reading_year'],
    };

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceAddPage(initialData: initial),
      ),
    );

    if (res is Map && res['success'] == true) {
      // Reload to update statuses
      await _loadRoomsAndPrevious();
    }
  }

  Widget _buildDisabledHelp() {
    final String msg = _isPastPeriod
        ? 'ดูข้อมูลย้อนหลังได้เท่านั้น ไม่อนุญาตให้บันทึกย้อนหลังในเดือนนี้'
        : 'เดือนอนาคตยังไม่เปิดให้บันทึก กรุณาเลือกเดือนปัจจุบัน';
    final Color bg =
        _isPastPeriod ? Colors.blueGrey.shade50 : Colors.amber.shade50;
    final IconData icon = _isPastPeriod ? Icons.info_outline : Icons.lock_clock;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }

  Widget _buildNoDataThisMonthLabel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ยังไม่มีข้อมูลของเดือนนี้ แสดงข้อมูลของเดือนก่อนแทน (เฉพาะเพื่อดู)',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPrevMonthLabel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black54),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ไม่มีข้อมูลของเดือนก่อน',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrevMonthReadonly(String roomId) {
    final prev = _prevMonthReadingByRoom[roomId]!;
    final int pm = (prev['reading_month'] ?? 0) as int;
    final int py = (prev['reading_year'] ?? 0) as int; // ค.ศ.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text('ข้อมูลเดือนก่อน: ${_getMonthName(pm)} ${py + 543}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        _buildReadonlyLine(
          label: 'ค่าน้ำ',
          previous: (prev['water_previous_reading'] ?? 0.0).toDouble(),
          current: (prev['water_current_reading'] ?? 0.0).toDouble(),
          color: Colors.blue[700]!,
        ),
        const SizedBox(height: 8),
        _buildReadonlyLine(
          label: 'ค่าไฟ',
          previous: (prev['electric_previous_reading'] ?? 0.0).toDouble(),
          current: (prev['electric_current_reading'] ?? 0.0).toDouble(),
          color: Colors.orange[700]!,
        ),
        if ((prev['reading_notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('หมายเหตุ: ${prev['reading_notes']}',
              style: const TextStyle(color: Colors.black87)),
        ],
      ],
    );
  }

  Widget _buildUtilityMissingHelper() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.settings_suggest, color: Colors.amber[800]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ยังไม่ตั้งค่า Utility สำหรับสาขานี้ — กรุณาไปที่ Utility Settings เพื่อเพิ่มเรตค่าน้ำ/ค่าไฟ ก่อนทำการบันทึก',
              style: TextStyle(color: Colors.black87),
            ),
          ),
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
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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

  Widget _buildInvoiceUtilityReadonlyLine({
    required String label,
    required double usage,
    required double total,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ใช้ ${usage.toStringAsFixed(2)} หน่วย • รวม ${total.toStringAsFixed(2)} บาท',
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
    bool editablePrevious = false,
    TextEditingController? previousController,
  }) {
    final prevText = previous.toStringAsFixed(2);
    final usageText =
        usage == null ? '' : (usage < 0 ? 'ผิด' : usage.toStringAsFixed(2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Previous (read-only or input) - equal width
            Expanded(
              child: editablePrevious && previousController != null
                  ? TextField(
                      controller: previousController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'ก่อนหน้า',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => onChanged(),
                    )
                  : TextField(
                      controller: TextEditingController(text: prevText),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'ก่อนหน้า',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Current input - equal width
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(width: 8),
            // Usage as read-only field - equal width
            Expanded(
              child: TextField(
                controller: TextEditingController(text: usageText),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'หน่วย',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: (usage == null || usage < 0) ? null : 'หน่วย',
                  suffixStyle: TextStyle(
                    color:
                        (usage == null || usage >= 0) ? usageColor : Colors.red,
                  ),
                ),
                style: TextStyle(
                  color:
                      (usage == null || usage >= 0) ? usageColor : Colors.red,
                ),
              ),
            ),
          ],
        ),
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
    final nCtrl = _noteCtrl[roomId]!;
    // Resolve water/electric rate IDs
    String? waterRateId;
    String? electricRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (waterRateId == null && _isWaterRate(r)) waterRateId = rid;
      if (electricRateId == null && _isElectricRate(r)) electricRateId = rid;
    }
    if (waterRateId == null || electricRateId == null) {
      _showErrorSnackBar(
          'กรุณาตั้งค่าเรตค่าน้ำและค่าไฟใน Utility Settings ก่อน');
      return;
    }
    final _prevMapForSave = _dynPrevCtrls[roomId];
    final _curMapForSave = _dynCurCtrls[roomId];
    final pvWCtrl = _prevMapForSave != null ? _prevMapForSave[waterRateId!] : null;
    final pvECtrl = _prevMapForSave != null ? _prevMapForSave[electricRateId!] : null;
    final cvWCtrl = _curMapForSave != null ? _curMapForSave[waterRateId!] : null;
    final cvECtrl = _curMapForSave != null ? _curMapForSave[electricRateId!] : null;

    double prevW = double.tryParse((pvWCtrl?.text ?? '').trim()) ??
        (_prevWaterByRoom[roomId] ?? 0.0);
    double prevE = double.tryParse((pvECtrl?.text ?? '').trim()) ??
        (_prevElecByRoom[roomId] ?? 0.0);
    final curW = double.tryParse((cvWCtrl?.text ?? '').trim());
    final curE = double.tryParse((cvECtrl?.text ?? '').trim());

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
        final warns = List.from(res['warnings'] ?? const []);
        if (warns.isNotEmpty) {
          _showWarnSnackBar('พบห้องข้อมูลผิดพลาด บางเดือนถัดไปไม่สามารถลบได้');
        }
        _savedRoomIds.add(roomId);
        // Store as existing for read-only view
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        _existingByRoom[roomId] = data;
        // Clear inputs and refresh previous suggestions for next month logic
        // Clear inputs
        cvWCtrl?.clear();
        cvECtrl?.clear();
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
    final nCtrl = _noteCtrl[roomId]!;

    final prevW = (existing['water_previous_reading'] ?? 0.0).toDouble();
    final prevE = (existing['electric_previous_reading'] ?? 0.0).toDouble();
    // Resolve current from dynamic controllers
    String? waterRateId;
    String? electricRateId;
    for (final rate in _meteredRates) {
      final r = Map<String, dynamic>.from(rate);
      final rid = (r['rate_id'] ?? '').toString();
      if (rid.isEmpty) continue;
      if (waterRateId == null && _isWaterRate(r)) waterRateId = rid;
      if (electricRateId == null && _isElectricRate(r)) electricRateId = rid;
    }
    if (waterRateId == null || electricRateId == null) {
      _showErrorSnackBar(
          'กรุณาตั้งค่าเรตค่าน้ำและค่าไฟใน Utility Settings ก่อน');
      return;
    }
    final _curMapForUpdate = _dynCurCtrls[roomId];
    final cvWCtrl = _curMapForUpdate != null ? _curMapForUpdate[waterRateId!] : null;
    final cvECtrl = _curMapForUpdate != null ? _curMapForUpdate[electricRateId!] : null;
    final curW = double.tryParse((cvWCtrl?.text ?? '').trim());
    final curE = double.tryParse((cvECtrl?.text ?? '').trim());

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
      final res =
          await MeterReadingService.updateMeterReading(readingId, payload);
      if (res['success'] == true) {
        _showSuccessSnackBar('บันทึกการแก้ไขสำเร็จ');
        final warns = List.from(res['warnings'] ?? const []);
        if (warns.isNotEmpty) {
          _showWarnSnackBar(
              'พบห้องข้อมูลผิดพลาด บางเดือนถัดไปออกบิลแล้ว ไม่สามารถลบเพื่อให้ต่อเนื่องได้');
        }
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        _existingByRoom[roomId] = data;
        _editingRoomIds.remove(roomId);
        // Clear inputs
        cvWCtrl?.clear();
        cvECtrl?.clear();
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _savingRoomIds.add(roomId));
    try {
      final res = await MeterReadingService.deleteMeterReading(readingId);
      if (res['success'] == true) {
        _showSuccessSnackBar('ลบข้อมูลสำเร็จ');
        final warns = List.from(res['warnings'] ?? const []);
        if (warns.isNotEmpty) {
          _showWarnSnackBar(
              'พบห้องข้อมูลผิดพลาด บางเดือนถัดไปออกบิลแล้ว ไม่สามารถลบเพื่อให้ต่อเนื่องได้');
        }
        _existingByRoom.remove(roomId);
        _savedRoomIds.remove(roomId);
        _editingRoomIds.remove(roomId);
        // Clear inputs
        try {
          String? waterRateId;
          String? electricRateId;
          for (final rate in _meteredRates) {
            final r = Map<String, dynamic>.from(rate);
            final rid = (r['rate_id'] ?? '').toString();
            if (rid.isEmpty) continue;
            if (waterRateId == null && _isWaterRate(r)) waterRateId = rid;
            if (electricRateId == null && _isElectricRate(r))
              electricRateId = rid;
          }
          if (waterRateId != null) {
            final curMap = _dynCurCtrls[roomId];
            final prevMap = _dynPrevCtrls[roomId];
            if (curMap != null) {
              curMap[waterRateId!]?.clear();
            }
            if (prevMap != null) {
              prevMap[waterRateId!]?.clear();
            }
          }
          if (electricRateId != null) {
            final curMap = _dynCurCtrls[roomId];
            final prevMap = _dynPrevCtrls[roomId];
            if (curMap != null) {
              curMap[electricRateId!]?.clear();
            }
            if (prevMap != null) {
              prevMap[electricRateId!]?.clear();
            }
          }
        } catch (_) {}
        _noteCtrl[roomId]?.clear();
        // Refresh previous suggestions (optional)
        try {
          final prev = await MeterReadingService.getPreviousForMonth(
              roomId, _selectedMonth, _selectedYear);
          _prevWaterByRoom[roomId] =
              (prev?['water_previous'] ?? 0.0).toDouble();
          _prevElecByRoom[roomId] =
              (prev?['electric_previous'] ?? 0.0).toDouble();
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

  Future<void> _confirmDeleteBilled(
      String readingId, String invoiceId, String roomId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ (รวมบิลเดือนนี้)'),
        content: const Text(
            'ต้องการลบข้อมูลค่ามิเตอร์และใบแจ้งหนี้ของเดือนนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบทั้งหมด')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _savingRoomIds.add(roomId));
    try {
      // 1) ลบบิลก่อน เพื่อปลดสถานะ billed ของ reading
      if (invoiceId.isNotEmpty) {
        final delInv = await InvoiceService.deleteInvoice(invoiceId);
        if (delInv['success'] != true) {
          _showErrorSnackBar(delInv['message'] ?? 'ลบใบแจ้งหนี้ไม่สำเร็จ');
          return;
        }
      }
      // 2) ลบค่ามิเตอร์ของเดือนนี้
      final delRead = await MeterReadingService.deleteMeterReading(readingId);
      if (delRead['success'] == true) {
        _showSuccessSnackBar('ลบข้อมูลและบิลของเดือนนี้สำเร็จ');
        _existingByRoom.remove(roomId);
        _savedRoomIds.remove(roomId);
        _editingRoomIds.remove(roomId);
        _invoiceUtilsByRoom.remove(roomId);
        _invoiceIdByRoom.remove(roomId);
        // Refresh previous suggestions
        try {
          final prev = await MeterReadingService.getPreviousForMonth(
              roomId, _selectedMonth, _selectedYear);
          _prevWaterByRoom[roomId] =
              (prev?['water_previous'] ?? 0.0).toDouble();
          _prevElecByRoom[roomId] =
              (prev?['electric_previous'] ?? 0.0).toDouble();
        } catch (_) {}
        setState(() {});
      } else {
        _showErrorSnackBar(delRead['message'] ?? 'ลบค่ามิเตอร์ไม่สำเร็จ');
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

  void _showWarnSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.amber[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
