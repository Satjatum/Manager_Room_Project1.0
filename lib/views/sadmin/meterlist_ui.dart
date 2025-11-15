import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/meter_service.dart';
import '../../services/utility_rate_service.dart';
import '../../services/invoice_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';
import '../widgets/colors.dart';

class MeterListUi extends StatefulWidget {
  final bool hideBottomNav;
  final String? branchId;
  final String? branchName;

  const MeterListUi({
    Key? key,
    this.hideBottomNav = false,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<MeterListUi> createState() => _MeterListUiState();
}

class _MeterListUiState extends State<MeterListUi> {
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

  // Hovered column index per tab (-1/null = none)
  int? _hoveredWaterCol;
  int? _hoveredElectricCol;
  // Selected row id per tab
  String? _selectedWaterRowId;
  String? _selectedElectricRowId;

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
      // Load active rooms for selected branch (restrict to branch)
      _rooms = await MeterReadingService.getActiveRoomsForMeterReading(
        branchId: widget.branchId,
      );

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
            // If previous equals 0, allow user to input previous manually
            if ((_prevWaterByRoom[roomId] ?? 0.0) == 0.0) {
              _needsPrevWaterInput.add(roomId);
            }
            if ((_prevElecByRoom[roomId] ?? 0.0) == 0.0) {
              _needsPrevElecInput.add(roomId);
            }
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
                          'ลงค่ามิเตอร์รายเดือน',
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
                        hintText: 'ค้นหา',
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
                                        dropdownColor: Colors.white,
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
                                            child: Text('ทั้งหมด'),
                                          ),
                                          ..._categories
                                              .map(
                                                (c) =>
                                                    DropdownMenuItem<String?>(
                                                        value: c,
                                                        child: Text(c)),
                                              )
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
                                        dropdownColor: Colors.white,
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
                                        dropdownColor: Colors.white,
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

  Widget _buildPeriodBanner() {
    if (_isCurrentPeriod) return const SizedBox.shrink();
    String message;
    Color color;
    IconData icon;
    if (_isPastPeriod) {
      message = 'เกินกำหนดรอบบิล ไม่สามารถบันทึกข้อมูลได้';
      color = Colors.blueGrey.shade50;
      icon = Icons.info_outline;
    } else {
      message = 'ยังไม่ถึงรอบบิล ไม่สามารถบันทึกข้อมูลได้';
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
                  Tab(
                      icon: Icon(Icons.water_drop, color: Colors.blue),
                      text: 'ค่าน้ำ'),
                  Tab(
                      icon: Icon(Icons.electric_bolt, color: Colors.orange),
                      text: 'ค่าไฟ'),
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
                    child:
                        _buildHorizontalTable(_buildWaterDataTable(filtered)),
                  ),
                  // Electric tab
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildHorizontalTable(
                        _buildElectricDataTable(filtered)),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  // --- Hover helpers ---
  Color _hoverBg(bool isHovered, {required bool isWater}) {
    // ปิดเอฟเฟกต์ hover รายคอลัมน์ ให้เหลือเฉพาะ hover แถวเทาอ่อน
    return Colors.transparent;
  }

  Widget _hoverHeaderLabel(String text, int col, {required bool isWater}) {
    final hovered =
        isWater ? _hoveredWaterCol == col : _hoveredElectricCol == col;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _hoverBg(hovered, isWater: isWater),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _wrapHoverCell({
    required Widget child,
    required int col,
    required bool isWater,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        if (isWater) {
          _hoveredWaterCol = col;
        } else {
          _hoveredElectricCol = col;
        }
      }),
      onExit: (_) => setState(() {
        if (isWater) {
          _hoveredWaterCol = null;
        } else {
          _hoveredElectricCol = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: _hoverBg(
              (isWater ? _hoveredWaterCol == col : _hoveredElectricCol == col),
              isWater: isWater),
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      ),
    );
  }

  // --- Row tap helpers to ensure selection toggles on ANY cell tap ---
  Future<void> _onTapWaterRow(String roomId, Map<String, dynamic> room,
      bool isNew, bool canCreate) async {
    // Mobile: แสดง active highlight เมื่อแตะ
    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    if (isMobileApp) {
      setState(() {
        _selectedWaterRowId = (_selectedWaterRowId == roomId) ? null : roomId;
      });
    }
    if (isNew) {
      if (canCreate) await _showCreateDialog(room);
    } else {
      await _showEditDialog(roomId);
    }
  }

  Future<void> _onTapElectricRow(String roomId, Map<String, dynamic> room,
      bool isNew, bool canCreate) async {
    // Mobile: แสดง active highlight เมื่อแตะ
    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    if (isMobileApp) {
      setState(() {
        _selectedElectricRowId =
            (_selectedElectricRowId == roomId) ? null : roomId;
      });
    }
    if (isNew) {
      if (canCreate) await _showCreateDialog(room);
    } else {
      await _showEditDialog(roomId);
    }
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

      final isNew = existing == null;
      final canCreate =
          _isCurrentPeriod && isNew && !_savingRoomIds.contains(roomId);

      return DataRow(cells: [
        DataCell(Text(tenant, overflow: TextOverflow.ellipsis),
            onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(roomNo), onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(room['room_category_name']?.toString() ?? '-'),
            onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(prev.toStringAsFixed(0)), onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(current != null ? current.toStringAsFixed(0) : '-'),
            onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(usage != null ? usage.toStringAsFixed(2) : '-'),
            onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(Text(statusStr), onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
        DataCell(const Icon(Icons.edit_note, size: 18), onTap: () async {
          if (isNew) {
            if (canCreate) await _showCreateDialog(room);
          } else {
            await _showEditDialog(roomId);
          }
        }),
      ]);
    }).toList();

    return DataTable(
      showCheckboxColumn: false,
      columns: [
        DataColumn(label: _hoverHeaderLabel('ผู้เช่า', 0, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('เลขที่', 1, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('ประเภท', 2, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('ก่อนหน้า', 3, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('ปัจจุบัน', 4, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('ใช้งาน', 5, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('สถานะ', 6, isWater: true)),
        DataColumn(label: _hoverHeaderLabel('', 7, isWater: true)),
      ],
      rows: rooms.map((room) {
        final roomId = (room['room_id'] ?? '').toString();
        final roomNo = (room['room_number'] ?? '-').toString();
        final tenant = (room['tenant_name'] ?? '-').toString();
        final existing = _existingByRoom[roomId];

        // previous/current for water
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
        final statusStr = (existing == null)
            ? 'ยังไม่บันทึก'
            : ((existing['reading_status'] ?? '').toString() == 'billed'
                ? 'ออกบิลแล้ว'
                : 'ยืนยันแล้ว');

        final isNew = existing == null;
        final canCreate =
            _isCurrentPeriod && isNew && !_savingRoomIds.contains(roomId);

        final platform = Theme.of(context).platform;
        final bool isMobileApp = !kIsWeb &&
            (platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS);
        return DataRow(
            selected: isMobileApp && _selectedWaterRowId == roomId,
            onSelectChanged: isMobileApp
                ? (sel) {
                    setState(() {
                      _selectedWaterRowId =
                          (_selectedWaterRowId == roomId) ? null : roomId;
                    });
                  }
                : null,
            cells: [
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 0,
                  child: Text(tenant, overflow: TextOverflow.ellipsis),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(isWater: true, col: 1, child: Text(roomNo)),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 2,
                  child: Text(room['room_category_name']?.toString() ?? '-'),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 3,
                  child: Text(prev.toStringAsFixed(0)),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 4,
                  child:
                      Text(current != null ? current.toStringAsFixed(0) : '-'),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 5,
                  child: Text(usage != null ? usage.toStringAsFixed(2) : '-'),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 6,
                  child: Text(statusStr),
                ),
                onTap: () => _onTapWaterRow(roomId, room, isNew, canCreate),
              ),
              DataCell(
                _wrapHoverCell(
                  isWater: true,
                  col: 7,
                  child: PopupMenuButton<String>(
                    color: Colors.white,
                    tooltip: 'ตัวเลือก',
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (value) async {
                      if (value == 'create') {
                        if (canCreate) await _showCreateDialog(room);
                      } else if (value == 'edit') {
                        await _showEditDialog(roomId);
                      } else if (value == 'delete') {
                        final readingId =
                            (existing?['reading_id'] ?? '').toString();
                        if (readingId.isNotEmpty) {
                          await _confirmDelete(readingId, roomId);
                        }
                      } else if (value == 'delete_billed') {
                        final readingId =
                            (existing?['reading_id'] ?? '').toString();
                        final invoiceId = (_invoiceIdByRoom[roomId] ?? '');
                        if (readingId.isNotEmpty) {
                          await _confirmDeleteBilled(
                              readingId, invoiceId, roomId);
                        }
                      }
                    },
                    itemBuilder: (context) {
                      final billed =
                          ((existing?['reading_status'] ?? '').toString() ==
                              'billed');
                      final items = <PopupMenuEntry<String>>[];
                      if (isNew && canCreate) {
                        items.add(
                          const PopupMenuItem(
                            value: 'create',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Color(0xFF14B8A6),
                                ),
                                SizedBox(width: 12),
                                Text('กรอก'),
                              ],
                            ),
                          ),
                        );
                      }
                      if (!isNew && _isCurrentPeriod && !billed) {
                        items.add(
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Color(0xFF14B8A6),
                                ),
                                SizedBox(width: 12),
                                Text('แก้ไข'),
                              ],
                            ),
                          ),
                        );
                      }
                      if (!isNew && _isCurrentPeriod) {
                        items.add(
                          PopupMenuItem(
                            value: billed ? 'delete_billed' : 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  billed ? 'ลบ' : 'ลบ',
                                  style: TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return items;
                    },
                  ),
                ),
              ),
            ]);
      }).toList(),
      headingRowColor: MaterialStateProperty.all(Colors.blue.withOpacity(0.06)),
      dataRowColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.blue.withOpacity(0.12); // แถวที่คลิก (น้ำ)
        }
        if (states.contains(MaterialState.hovered)) {
          return Colors.grey.withOpacity(0.08); // hover แถวเป็นสีเทาอ่อน
        }
        return Colors.white;
      }),
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

      final isNew = existing == null;
      final canCreate =
          _isCurrentPeriod && isNew && !_savingRoomIds.contains(roomId);

      return DataRow(
          selected: _selectedElectricRowId == roomId,
          onSelectChanged: (sel) {
            setState(() {
              _selectedElectricRowId =
                  (_selectedElectricRowId == roomId) ? null : roomId;
            });
          },
          cells: [
            DataCell(Text(tenant, overflow: TextOverflow.ellipsis),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(roomNo),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(room['room_category_name']?.toString() ?? '-'),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(prev.toStringAsFixed(0)),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(current != null ? current.toStringAsFixed(0) : '-'),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(usage != null ? usage.toStringAsFixed(2) : '-'),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(Text(status),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
            DataCell(const Icon(Icons.edit_note, size: 18),
                onTap: () => _onTapElectricRow(roomId, room, isNew, canCreate)),
          ]);
    }).toList();

    return DataTable(
      showCheckboxColumn: false,
      columns: [
        DataColumn(label: _hoverHeaderLabel('ผู้เช่า', 0, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('เลขที่', 1, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('ประเภท', 2, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('ก่อนหน้า', 3, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('ปัจจุบัน', 4, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('ใช้งาน', 5, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('สถานะ', 6, isWater: false)),
        DataColumn(label: _hoverHeaderLabel('', 7, isWater: false)),
      ],
      rows: rooms.map((room) {
        final roomId = (room['room_id'] ?? '').toString();
        final roomNo = (room['room_number'] ?? '-').toString();
        final tenant = (room['tenant_name'] ?? '-').toString();
        final existing = _existingByRoom[roomId];

        // previous/current for electric
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

        final isNew = existing == null;
        final canCreate =
            _isCurrentPeriod && isNew && !_savingRoomIds.contains(roomId);

        final platform = Theme.of(context).platform;
        final bool isMobileApp = !kIsWeb &&
            (platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS);
        return DataRow(
          selected: isMobileApp && _selectedElectricRowId == roomId,
          onSelectChanged: isMobileApp
              ? (sel) {
                  setState(() {
                    _selectedElectricRowId =
                        (_selectedElectricRowId == roomId) ? null : roomId;
                  });
                }
              : null,
          cells: [
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 0,
              child: Text(tenant, overflow: TextOverflow.ellipsis),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(isWater: false, col: 1, child: Text(roomNo)),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 2,
              child: Text(room['room_category_name']?.toString() ?? '-'),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 3,
              child: Text(prev.toStringAsFixed(0)),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 4,
              child: Text(current != null ? current.toStringAsFixed(0) : '-'),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 5,
              child: Text(usage != null ? usage.toStringAsFixed(2) : '-'),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 6,
              child: Text(status),
            ),
            onTap: () async {
              if (isNew) {
                if (canCreate) await _showCreateDialog(room);
              } else {
                await _showEditDialog(roomId);
              }
            },
          ),
          DataCell(
            _wrapHoverCell(
              isWater: false,
              col: 7,
              child: PopupMenuButton<String>(
                tooltip: 'ตัวเลือก',
                icon: const Icon(Icons.more_horiz, size: 20),
                onSelected: (value) async {
                  if (value == 'create') {
                    if (canCreate) await _showCreateDialog(room);
                  } else if (value == 'edit') {
                    await _showEditDialog(roomId);
                  } else if (value == 'delete') {
                    final readingId =
                        (existing?['reading_id'] ?? '').toString();
                    if (readingId.isNotEmpty) {
                      await _confirmDelete(readingId, roomId);
                    }
                  } else if (value == 'delete_billed') {
                    final readingId =
                        (existing?['reading_id'] ?? '').toString();
                    final invoiceId = (_invoiceIdByRoom[roomId] ?? '');
                    if (readingId.isNotEmpty) {
                      await _confirmDeleteBilled(readingId, invoiceId, roomId);
                    }
                  }
                },
                itemBuilder: (context) {
                  final billed =
                      ((existing?['reading_status'] ?? '').toString() ==
                          'billed');
                  final items = <PopupMenuEntry<String>>[];
                  if (isNew && canCreate) {
                    items.add(
                      const PopupMenuItem(
                        value: 'create',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF14B8A6),
                            ),
                            SizedBox(width: 12),
                            Text('กรอก'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!isNew && _isCurrentPeriod && !billed) {
                    items.add(
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF14B8A6),
                            ),
                            SizedBox(width: 12),
                            Text('แก้ไข'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!isNew && _isCurrentPeriod) {
                    items.add(
                      PopupMenuItem(
                        value: billed ? 'delete_billed' : 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text(
                              billed ? 'ลบ' : 'ลบ',
                              style: TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return items;
                },
              ),
            ),
          ),
        ]);
      }).toList(),
      headingRowColor:
          MaterialStateProperty.all(Colors.orange.withOpacity(0.06)),
      dataRowColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.orange.withOpacity(0.12); // แถวที่คลิก (ไฟ)
        }
        if (states.contains(MaterialState.hovered)) {
          return Colors.grey.withOpacity(0.08); // hover แถวเป็นสีเทาอ่อน
        }
        return Colors.white;
      }),
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
    // Prefill current values from existing
    if (waterRateId != null && curMap != null) {
      final cvW = curMap[waterRateId!];
      cvW?.text = (existing['water_current_reading'] ?? '').toString();
    }
    if (electricRateId != null && curMap != null) {
      final cvE = curMap[electricRateId!];
      cvE?.text = (existing['electric_current_reading'] ?? '').toString();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          title: const Text('แก้ไขค่ามิเตอร์เดือนนี้'),
          content: SizedBox(
            width: 420,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.water_drop,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Text('ค่าน้ำ'),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ค่าน้ำเดือนก่อน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (existing['water_previous_reading'] ?? 0)
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: waterRateId != null && curMap != null
                        ? curMap[waterRateId!]
                        : null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ค่าน้ำเดือนปัจจุบัน',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xff10B981),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(
                        Icons.electric_bolt,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Text('ค่าไฟ'),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ค่าไฟเดือนก่อน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (existing['electric_previous_reading'] ?? 0)
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: electricRateId != null && curMap != null
                        ? curMap[electricRateId!]
                        : null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ค่าไฟเดือนปัจจุบัน',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xff10B981),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, // เขียว
                    ),
                    onPressed: () async {
                      await _updateRow(roomId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateDialog(Map<String, dynamic> room) async {
    final roomId = (room['room_id'] ?? '').toString();

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
    final prevMap = _dynPrevCtrls[roomId];
    final nCtrl = _noteCtrl[roomId] ??= TextEditingController();
    // Clear current values for fresh input
    if (waterRateId != null && curMap != null) {
      curMap[waterRateId!]?.text = '';
    }
    if (electricRateId != null && curMap != null) {
      curMap[electricRateId!]?.text = '';
    }
    nCtrl.text = '';

    final prevW = (_prevWaterByRoom[roomId] ?? 0.0).toDouble();
    final prevE = (_prevElecByRoom[roomId] ?? 0.0).toDouble();
    final needPrevWater = _needsPrevWaterInput.contains(roomId) || prevW == 0.0;
    final needPrevElec = _needsPrevElecInput.contains(roomId) || prevE == 0.0;
    final pvWCtrl =
        (waterRateId != null && prevMap != null) ? prevMap[waterRateId!] : null;
    final pvECtrl = (electricRateId != null && prevMap != null)
        ? prevMap[electricRateId!]
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          title: const Text('กรอกข้อมูลค่ามิเตอร์เดือนนี้'),
          content: SizedBox(
            width: 420,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.water_drop, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('ค่าน้ำ'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (needPrevWater)
                    TextField(
                      controller: pvWCtrl,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ค่าน้ำเดือนก่อน',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xff10B981),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                      ),
                    )
                  else
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'เดือนก่อน: ${prevW.toStringAsFixed(0)}',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xff10B981),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: waterRateId != null && curMap != null
                        ? curMap[waterRateId!]
                        : null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ค่าน้ำเดือนปัจจุบัน',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xff10B981),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.electric_bolt, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('ค่าไฟ'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (needPrevElec)
                    TextField(
                      controller: pvECtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ค่าไฟเดือนก่อน',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xff10B981),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                      ),
                    )
                  else
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'เดือนก่อน: ${prevE.toStringAsFixed(0)}',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xff10B981),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: electricRateId != null && curMap != null
                        ? curMap[electricRateId!]
                        : null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ค่าไฟเดือนปัจจุบัน',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xff10B981),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, // เขียว
                    ),
                    onPressed: () async {
                      await _updateRow(roomId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      },
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
              'ยังไม่ได้ตั้งค่าค่าน้ำ - ค่าไฟ',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
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
    final pvWCtrl =
        _prevMapForSave != null ? _prevMapForSave[waterRateId!] : null;
    final pvECtrl =
        _prevMapForSave != null ? _prevMapForSave[electricRateId!] : null;
    final cvWCtrl =
        _curMapForSave != null ? _curMapForSave[waterRateId!] : null;
    final cvECtrl =
        _curMapForSave != null ? _curMapForSave[electricRateId!] : null;

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
    if (curW <= prevW) {
      _showErrorSnackBar('ค่าน้ำปัจจุบันต้องมากกว่าค่าก่อนหน้า');
      return;
    }
    if (curE <= prevE) {
      _showErrorSnackBar('ค่าไฟปัจจุบันต้องมากกว่าค่าก่อนหน้า');
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
    // If there is no existing reading for this room/month, treat this as create
    if (existing == null) {
      final room = _rooms.firstWhere(
        (r) => (r['room_id']?.toString() ?? '') == roomId,
        orElse: () => <String, dynamic>{},
      );
      if (room.isNotEmpty) {
        await _saveRow(room);
      } else {
        _showErrorSnackBar('ไม่พบข้อมูลห้อง');
      }
      return;
    }
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
    final cvWCtrl =
        _curMapForUpdate != null ? _curMapForUpdate[waterRateId!] : null;
    final cvECtrl =
        _curMapForUpdate != null ? _curMapForUpdate[electricRateId!] : null;
    final curW = double.tryParse((cvWCtrl?.text ?? '').trim());
    final curE = double.tryParse((cvECtrl?.text ?? '').trim());

    if (curW == null || curE == null) {
      _showErrorSnackBar('กรุณากรอกตัวเลขให้ถูกต้อง');
      return;
    }
    if (curW <= prevW) {
      _showErrorSnackBar('ค่าน้ำปัจจุบันต้องมากกว่าค่าก่อนหน้า');
      return;
    }
    if (curE <= prevE) {
      _showErrorSnackBar('ค่าไฟปัจจุบันต้องมากกว่าค่าก่อนหน้า');
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
    final tenantName = (() {
      try {
        final r = _rooms.firstWhere(
          (e) => (e['room_id']?.toString() ?? '') == roomId,
          orElse: () => <String, dynamic>{},
        );
        return (r['tenant_name'] ?? '').toString();
      } catch (_) {
        return '';
      }
    })();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'ยืนยันการลบผู้เช่า',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Tenant label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tenantName.isEmpty ? '-' : tenantName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.shade100,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'การลบนี้ไม่สามารถกู้คืนได้',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ยืนยันการลบ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );

    if (confirm != true) return;

    // Loading dialog while deleting
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 3,
                      ),
                    ),
                    Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                      size: 28,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'กำลังลบข้อมูลผู้เช่า',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณารอสักครู่...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );

    setState(() => _savingRoomIds.add(roomId));
    try {
      final res = await MeterReadingService.deleteMeterReading(readingId);
      if (mounted) Navigator.of(context).pop(); // close loading dialog
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
      if (mounted) Navigator.of(context).pop(); // close loading dialog
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
