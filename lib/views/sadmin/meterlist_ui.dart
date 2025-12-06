import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Models //
import '../../models/user_models.dart';
// Services //
import '../../services/meter_service.dart';
import '../../services/auth_service.dart';
import '../../services/utility_rate_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';
// Utils //
import '../../utils/formatMonthy.dart';

// Enhanced data structure to reduce state complexity
class MeterReadingData {
  final Map<String, dynamic> room;
  final Map<String, dynamic>? existing;
  final double previous;
  final double? current;
  final double? usage;
  final String statusStr;
  final bool isNew;
  final bool canCreate;
  final String? rateId;

  MeterReadingData({
    required this.room,
    this.existing,
    required this.previous,
    this.current,
    this.usage,
    required this.statusStr,
    required this.isNew,
    required this.canCreate,
    this.rateId,
  });

  String get roomId => (room['room_id'] ?? '').toString();
  String get roomNo => (room['room_number'] ?? '-').toString();
  String get tenant => (room['tenant_name'] ?? '-').toString();
  String get category => (room['room_category_name'] ?? '-').toString();
}

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
  // Core state
  UserModel? _currentUser;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _meteredRates = [];
  bool _isLoading = true;

  // Filter state
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  // Previous readings and dynamic controllers - simplified
  final Map<String, double> _prevReadings = {}; // key: roomId_utilityType
  final Map<String, TextEditingController> _controllers =
      {}; // key: roomId_rateId_type
  final Map<String, Map<String, dynamic>> _existingByRoom = {};
  final Set<String> _savingRoomIds = {};

  // UI state
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedRowId;

  // Computed properties
  bool get _isCurrentPeriod {
    final now = DateTime.now();
    return _selectedMonth == now.month && _selectedYear == now.year;
  }

  // Utility functions
  String? _getRateId(String utilityType) {
    for (final rate in _meteredRates) {
      final name = (rate['rate_name'] ?? '').toString().toLowerCase();
      final isMatch = utilityType == 'water'
          ? (name.contains('น้ำ') || name.contains('water'))
          : (name.contains('ไฟ') || name.contains('electric'));

      if (isMatch) return (rate['rate_id'] ?? '').toString();
    }
    return null;
  }

  String _getStatusString(Map<String, dynamic>? existing) {
    if (existing == null) return 'ยังไม่บันทึก';
    return ((existing['reading_status'] ?? '').toString() == 'billed')
        ? 'ออกบิลแล้ว'
        : 'ยืนยันแล้ว';
  }

  // Unified data preparation method
  List<MeterReadingData> _prepareReadingData(
      List<Map<String, dynamic>> rooms, String utilityType) {
    final rateId = _getRateId(utilityType);
    final previousKey = utilityType == 'water'
        ? 'water_previous_reading'
        : 'electric_previous_reading';
    final currentKey = utilityType == 'water'
        ? 'water_current_reading'
        : 'electric_current_reading';

    return rooms.map((room) {
      final roomId = (room['room_id'] ?? '').toString();
      final existing = _existingByRoom[roomId];

      // Fix: Use previous from existing data if available, otherwise use _prevReadings
      final previous = existing != null
          ? (existing[previousKey] ?? 0.0).toDouble()
          : _prevReadings['${roomId}_$utilityType'] ?? 0.0;

      final controller = _controllers['${roomId}_${rateId}_current'];
      final current = existing != null
          ? (existing[currentKey] ?? 0.0).toDouble()
          : double.tryParse(controller?.text ?? '');

      final usage = current != null ? (current - previous) : null;
      final statusStr = _getStatusString(existing);
      final isNew = existing == null;
      final canCreate =
          _isCurrentPeriod && isNew && !_savingRoomIds.contains(roomId);

      return MeterReadingData(
        room: room,
        existing: existing,
        previous: previous,
        current: current,
        usage: usage,
        statusStr: statusStr,
        isNew: isNew,
        canCreate: canCreate,
        rateId: rateId,
      );
    }).toList();
  }

  // Unified tap handler
  Future<void> _onTapRow(MeterReadingData data) async {
    setState(() {
      _selectedRowId = (_selectedRowId == data.roomId) ? null : data.roomId;
    });

    if (data.isNew) {
      if (data.canCreate) await _showCreateDialog(data.room);
    } else {
      await _showEditDialog(data.roomId);
    }
  }

  // Unified DataTable builder
  Widget _buildDataTable(
      List<MeterReadingData> readingData, String utilityType) {
    final isWater = utilityType == 'water';
    final headerColor = isWater ? Colors.blue : Colors.orange;

    return DataTable(
      showCheckboxColumn: false,
      columns: [
        DataColumn(label: _buildHeaderLabel('ผู้เช่า')),
        DataColumn(label: _buildHeaderLabel('เลขที่')),
        DataColumn(label: _buildHeaderLabel('ประเภท')),
        DataColumn(label: _buildHeaderLabel('ก่อนหน้า')),
        DataColumn(label: _buildHeaderLabel('ปัจจุบัน')),
        DataColumn(label: _buildHeaderLabel('ใช้งาน')),
        DataColumn(label: _buildHeaderLabel('สถานะ')),
        DataColumn(label: _buildHeaderLabel('')),
      ],
      rows: readingData.map((data) => _buildDataRow(data, isWater)).toList(),
      headingRowColor: MaterialStateProperty.all(headerColor.withOpacity(0.06)),
      dataRowColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return headerColor.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return Colors.grey.withOpacity(0.08);
        }
        return Colors.white;
      }),
      border: TableBorder.symmetric(
        inside: BorderSide(color: Colors.grey[300]!),
        outside: BorderSide.none,
      ),
    );
  }

  Widget _buildHeaderLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
  }

  DataRow _buildDataRow(MeterReadingData data, bool isWater) {
    return DataRow(
      selected: _selectedRowId == data.roomId,
      onSelectChanged: null,
      cells: [
        _buildDataCell(
            Text(data.tenant, overflow: TextOverflow.ellipsis), data),
        _buildDataCell(Text(data.roomNo), data),
        _buildDataCell(Text(data.category), data),
        _buildDataCell(Text(data.previous.toStringAsFixed(0)), data),
        _buildDataCell(
            Text(data.current != null ? data.current!.toStringAsFixed(0) : '-'),
            data),
        _buildDataCell(
            Text(data.usage != null ? data.usage!.toStringAsFixed(2) : '-'),
            data),
        _buildDataCell(_buildStatusChip(data.statusStr), data),
        _buildDataCell(_buildPopupMenu(data), data),
      ],
    );
  }

  DataCell _buildDataCell(Widget child, MeterReadingData data) {
    return DataCell(
      child,
      onTap: () => _onTapRow(data),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    if (status == 'ออกบิลแล้ว') {
      color = Colors.green;
    } else if (status == 'ยืนยันแล้ว') {
      color = Colors.blue;
    } else {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPopupMenu(MeterReadingData data) {
    return PopupMenuButton<String>(
      color: Colors.white,
      tooltip: 'ตัวเลือก',
      icon: const Icon(Icons.more_horiz, size: 20),
      onSelected: (value) => _handleMenuAction(value, data),
      itemBuilder: (context) => _buildMenuItems(data),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(MeterReadingData data) {
    final billed =
        (data.existing?['reading_status'] ?? '').toString() == 'billed';
    final items = <PopupMenuEntry<String>>[];

    // กรณี 1: ยังไม่มีข้อมูล + เป็นเดือนปัจจุบัน → แก้ไขได้ทั้งหมด
    if (data.isNew && data.canCreate) {
      items.add(
        PopupMenuItem(
          value: 'create',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Color(0xFF14B8A6)),
              SizedBox(width: 12),
              Text('กรอก'),
            ],
          ),
        ),
      );
    }

    // กรณี 2: มีข้อมูลแล้ว + เป็นเดือนปัจจุบัน → แก้ไขได้เฉพาะมิเตอร์ปัจจุบัน
    if (!data.isNew && _isCurrentPeriod && !billed) {
      items.add(
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Color(0xFF14B8A6)),
              SizedBox(width: 12),
              Text('แก้ไข'),
            ],
          ),
        ),
      );
    }

    // กรณี 3: เดือนที่ผ่านมา → ไม่สามารถแก้ไข/ลบได้
    // เฉพาะเดือนปัจจุบันเท่านั้นที่แสดงปุ่มลบ
    if (!data.isNew && _isCurrentPeriod) {
      final action = billed ? 'delete_billed' : 'delete';
      items.add(
        PopupMenuItem(
          value: action,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('ลบสาขา', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    return items;
  }

  Future<void> _handleMenuAction(String action, MeterReadingData data) async {
    switch (action) {
      case 'create':
        if (data.canCreate) await _showCreateDialog(data.room);
        break;
      case 'edit':
        await _showEditDialog(data.roomId);
        break;
      case 'delete':
        await _deleteMeterReading(data);
        break;
      case 'delete_billed':
        await _deleteBilledMeterReading(data);
        break;
    }
  }

  // Simplified horizontal table wrapper
  Widget _buildHorizontalTable(Widget table) {
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

  // Main build method (simplified)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.of(context).maybePop(),
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
                Row(
                  children: [
                    const Icon(Icons.date_range,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'รอบเดือน: ${Formatmonthy.formatBillingCycleTh(month: _selectedMonth, year: _selectedYear)}',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    // Simplified filters implementation
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Search field
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
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[600], size: 20),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Month and year selectors
          Row(
            children: [
              Expanded(child: _buildMonthSelector()),
              const SizedBox(width: 8),
              Expanded(child: _buildYearSelector()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          dropdownColor: Colors.white,
          value: _selectedMonth,
          isExpanded: true,
          items: List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(Formatmonthy.monthName(m)),
                  ))
              .toList(),
          onChanged: (val) async {
            setState(() => _selectedMonth = val ?? _selectedMonth);
            await _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          dropdownColor: Colors.white,
          value: _selectedYear,
          isExpanded: true,
          items: List.generate(6, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text('${y + 543}'),
                  ))
              .toList(),
          onChanged: (val) async {
            setState(() => _selectedYear = val ?? _selectedYear);
            await _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text('กำลังโหลดข้อมูล...',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    final filteredRooms = _getFilteredRooms();

    return Column(
      children: [
        _buildSummaryBar(filteredRooms),
        DefaultTabController(
          length: 2,
          child: Expanded(
            child: Column(
              children: [
                const TabBar(
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primary,
                  tabs: [
                    Tab(
                        icon: Icon(Icons.water_drop, color: Colors.blue),
                        text: 'ค่าน้ำ'),
                    Tab(
                        icon: Icon(Icons.electric_bolt, color: Colors.orange),
                        text: 'ค่าไฟ'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTabContent(filteredRooms, 'water'),
                      _buildTabContent(filteredRooms, 'electric'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(List<Map<String, dynamic>> rooms) {
    final totalCount = rooms.length;
    final savedCount = rooms
        .where(
            (r) => _existingByRoom.containsKey((r['room_id'] ?? '').toString()))
        .length;
    final pendingCount = totalCount - savedCount;
    final billedCount = rooms.where((r) {
      final existing = _existingByRoom[(r['room_id'] ?? '').toString()];
      return existing != null &&
          (existing['reading_status'] ?? '').toString() == 'billed';
    }).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCountChip(
                Icons.list_alt, 'ทั้งหมด', totalCount, Colors.blueGrey),
            const SizedBox(width: 8),
            _buildCountChip(
                Icons.edit_note, 'รอกรอก', pendingCount, Colors.orange),
            const SizedBox(width: 8),
            _buildCountChip(
                Icons.check_circle, 'บันทึกแล้ว', savedCount, AppTheme.second),
            const SizedBox(width: 8),
            _buildCountChip(
                Icons.receipt_long, 'ออกบิลแล้ว', billedCount, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 4),
          Text(count.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTabContent(
      List<Map<String, dynamic>> rooms, String utilityType) {
    final readingData = _prepareReadingData(rooms, utilityType);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildHorizontalTable(_buildDataTable(readingData, utilityType)),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredRooms() {
    return _rooms.where((r) {
      if (_searchQuery.isNotEmpty) {
        final room = (r['room_number'] ?? '').toString().toLowerCase();
        final tenant = (r['tenant_name'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!room.contains(q) && !tenant.contains(q)) return false;
      }

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        final cat = (r['room_category_name'] ?? '').toString();
        if (cat != _selectedCategory) return false;
      }

      return true;
    }).toList();
  }

  // Lifecycle methods
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await AuthService.getCurrentUser();
      if (_currentUser == null) return;
      await _loadData();
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      if (mounted) {
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    // Load metered rates
    try {
      final branchId = widget.branchId;
      if (branchId?.isNotEmpty == true) {
        final rates = await UtilityRatesService.getMeteredRates(branchId!);
        if (mounted) {
          _meteredRates = rates.where((r) {
            final name = (r['rate_name'] ?? '').toString().toLowerCase();
            return name.contains('น้ำ') ||
                name.contains('water') ||
                name.contains('ไฟ') ||
                name.contains('electric');
          }).toList();
        }
      }
    } catch (e) {
      if (mounted) {
        _meteredRates = [];
      }
    }

    // Load rooms
    try {
      _rooms = await MeterReadingService.getActiveRoomsForMeterReading(
        branchId: widget.branchId,
      );

      if (!mounted) return;

      // Sort and prepare categories
      _rooms.sort((a, b) {
        final an = (a['room_number'] ?? '').toString();
        final bn = (b['room_number'] ?? '').toString();
        return an.compareTo(bn);
      });

      final setCats = <String>{};
      for (final r in _rooms) {
        final c = (r['room_category_name'] ?? '').toString();
        if (c.isNotEmpty) setCats.add(c);
      }

      // Load existing readings and setup controllers
      await _loadExistingReadings();
      if (mounted) {
        _initializeControllers();
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadExistingReadings() async {
    _existingByRoom.clear();

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
        }

        // Load previous readings from the month before the selected month/year
        final prev = await MeterReadingService.getPreviousForMonth(
            roomId, _selectedMonth, _selectedYear);

        if (prev != null) {
          // Fix: Use correct keys from service response
          _prevReadings['${roomId}_water'] =
              (prev['water_previous'] ?? 0.0) is double
                  ? prev['water_previous']
                  : (prev['water_previous'] as num).toDouble();
          _prevReadings['${roomId}_electric'] =
              (prev['electric_previous'] ?? 0.0) is double
                  ? prev['electric_previous']
                  : (prev['electric_previous'] as num).toDouble();
        } else {
          // If no previous reading found, set to 0
          _prevReadings['${roomId}_water'] = 0.0;
          _prevReadings['${roomId}_electric'] = 0.0;
        }
      } catch (e) {
        // Handle error silently - set default values
        debugPrint('Error loading meter readings for room $roomId: $e');
        _prevReadings['${roomId}_water'] = 0.0;
        _prevReadings['${roomId}_electric'] = 0.0;
      }
    }));
  }

  void _initializeControllers() {
    // Safely dispose existing controllers
    final oldControllers =
        Map<String, TextEditingController>.from(_controllers);
    _controllers.clear();

    // Create new controllers for each room and rate
    for (final room in _rooms) {
      final roomId = (room['room_id'] ?? '').toString();
      for (final rate in _meteredRates) {
        final rateId = (rate['rate_id'] ?? '').toString();
        if (rateId.isNotEmpty) {
          _controllers['${roomId}_${rateId}_previous'] =
              TextEditingController();
          _controllers['${roomId}_${rateId}_current'] = TextEditingController();
        }
      }
    }

    // Dispose old controllers after creating new ones
    Future.microtask(() {
      for (final controller in oldControllers.values) {
        controller.dispose();
      }
    });
  }

  Future<void> _showCreateDialog(Map<String, dynamic> room) async {
    final roomId = room['room_id']?.toString();
    if (roomId == null) return;

    // กรณี 3: ถ้าไม่ใช่เดือนปัจจุบัน ไม่อนุญาตให้เพิ่มข้อมูล
    if (!_isCurrentPeriod) {
      SnackMessage.showError(
          context, 'ไม่สามารถเพิ่มข้อมูลในเดือนที่ผ่านมาแล้วได้');
      return;
    }

    final waterRateId = _getRateId('water');
    final electricRateId = _getRateId('electric');

    final waterPrevController = TextEditingController();
    final waterCurrentController = TextEditingController();
    final electricPrevController = TextEditingController();
    final electricCurrentController = TextEditingController();

    // กรณี 1: ยังไม่มีข้อมูล → แก้ไขได้ทั้งหมด (แต่ค่าก่อนหน้ายังต้อง readonly)
    waterPrevController.text =
        (_prevReadings['${roomId}_water'] ?? 0.0).toStringAsFixed(0);
    electricPrevController.text =
        (_prevReadings['${roomId}_electric'] ?? 0.0).toStringAsFixed(0);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กรอกข้อมูลมิเตอร์',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ผู้เช่า: ${room['tenant_name'] ?? '-'}'),
                  const SizedBox(height: 20),

                  // Water meter section
                  const Text('ค่าน้ำ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: waterPrevController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าน้ำก่อนหน้า *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: waterCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าน้ำปัจจุบัน *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Electric meter section
                  const Text('ค่าไฟ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: electricPrevController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าไฟก่อนหน้า *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: electricCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าไฟปัจจุบัน *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      waterPrevController.dispose();
                      waterCurrentController.dispose();
                      electricPrevController.dispose();
                      electricCurrentController.dispose();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveMeterReadings(
                        roomId,
                        waterRateId,
                        electricRateId,
                        waterPrevController.text,
                        waterCurrentController.text,
                        electricPrevController.text,
                        electricCurrentController.text,
                      );

                      waterPrevController.dispose();
                      waterCurrentController.dispose();
                      electricPrevController.dispose();
                      electricCurrentController.dispose();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'บันทึก',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(String roomId) async {
    final existingReading = _existingByRoom[roomId];
    if (existingReading == null) return;

    // กรณี 3: ถ้าไม่ใช่เดือนปัจจุบัน ไม่อนุญาตให้แก้ไข
    if (!_isCurrentPeriod) {
      SnackMessage.showError(
          context, 'ไม่สามารถแก้ไขข้อมูลในเดือนที่ผ่านมาแล้วได้');
      return;
    }

    // ตรวจสอบว่าออกบิลแล้วหรือยัง
    final isBilled =
        (existingReading['reading_status'] ?? '').toString() == 'billed';
    if (isBilled) {
      SnackMessage.showError(context, 'ไม่สามารถแก้ไขข้อมูลที่ออกบิลแล้วได้');
      return;
    }

    // Create temporary controllers for the dialog
    final waterPrevController = TextEditingController();
    final waterCurrentController = TextEditingController();
    final electricPrevController = TextEditingController();
    final electricCurrentController = TextEditingController();

    // กรณี 2: มีข้อมูลเดือนก่อนแล้ว → แก้ไขได้เฉพาะมิเตอร์ปัจจุบัน (ล็อคค่าก่อนหน้า)
    // Set existing values
    waterPrevController.text =
        (existingReading['water_previous_reading'] ?? 0.0).toStringAsFixed(0);
    waterCurrentController.text =
        (existingReading['water_current_reading'] ?? 0.0).toStringAsFixed(0);
    electricPrevController.text =
        (existingReading['electric_previous_reading'] ?? 0.0)
            .toStringAsFixed(0);
    electricCurrentController.text =
        (existingReading['electric_current_reading'] ?? 0.0).toStringAsFixed(0);

    final room = _rooms.firstWhere((r) => r['room_id']?.toString() == roomId,
        orElse: () => {'room_number': '', 'tenant_name': ''});

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'แก้ไขข้อมูลมิเตอร์',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ผู้เช่า: ${room['tenant_name'] ?? '-'}'),
                  const SizedBox(height: 20),

                  // Water meter section
                  const Text('ค่าน้ำ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: waterPrevController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าน้ำก่อนหน้า *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: waterCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าน้ำปัจจุบัน *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Electric meter section
                  const Text('ค่าไฟ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: electricPrevController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าไฟก่อนหน้า *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: electricCurrentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'มิเตอร์ค่าไฟปัจจุบัน *',
                      labelStyle: TextStyle(
                        color: Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      waterPrevController.dispose();
                      waterCurrentController.dispose();
                      electricPrevController.dispose();
                      electricCurrentController.dispose();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _updateMeterReadings(
                        existingReading['reading_id']?.toString(),
                        waterPrevController.text,
                        waterCurrentController.text,
                        electricPrevController.text,
                        electricCurrentController.text,
                      );

                      waterPrevController.dispose();
                      waterCurrentController.dispose();
                      electricPrevController.dispose();
                      electricCurrentController.dispose();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'แก้ไข',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ],
        );
      },
    );
  }

  // Save meter readings for new entry
  Future<void> _saveMeterReadings(
    String roomId,
    String? waterRateId,
    String? electricRateId,
    String waterPrev,
    String waterCurrent,
    String electricPrev,
    String electricCurrent,
  ) async {
    if (_savingRoomIds.contains(roomId)) return;

    setState(() => _savingRoomIds.add(roomId));

    try {
      final waterCurrentVal = double.tryParse(waterCurrent);
      final electricCurrentVal = double.tryParse(electricCurrent);

      if (waterCurrentVal == null || electricCurrentVal == null) {
        SnackMessage.showError(
            context, 'กรุณากรอกเลขมิเตอร์ปัจจุบันให้ถูกต้อง');
        return;
      }

      final waterPrevVal = double.tryParse(waterPrev) ?? 0.0;
      final electricPrevVal = double.tryParse(electricPrev) ?? 0.0;

      if (waterCurrentVal < waterPrevVal ||
          electricCurrentVal < electricPrevVal) {
        SnackMessage.showError(context,
            'เลขมิเตอร์ปัจจุบันต้องมากกว่าหรือเท่ากับเลขมิเตอร์ก่อนหน้า');
        return;
      }

      // Get tenant_id and contract_id from room data
      final room = _rooms.firstWhere((r) => r['room_id']?.toString() == roomId,
          orElse: () => {});
      final tenantId = room['tenant_id']?.toString();
      final contractId = room['contract_id']?.toString();

      if (tenantId == null || contractId == null) {
        SnackMessage.showError(context, 'ไม่พบข้อมูลผู้เช่าหรือสัญญาเช่า');
        return;
      }

      final result = await MeterReadingService.createMeterReading({
        'room_id': roomId,
        'tenant_id': tenantId,
        'contract_id': contractId,
        'reading_month': _selectedMonth,
        'reading_year': _selectedYear,
        'water_previous_reading': waterPrevVal,
        'water_current_reading': waterCurrentVal,
        'electric_previous_reading': electricPrevVal,
        'electric_current_reading': electricCurrentVal,
      });

      if (result['success'] == true) {
        if (mounted) {
          SnackMessage.showSuccess(context, 'บันทึกข้อมูลสำเร็จ');
          await _loadData(); // Refresh data
        }
      } else {
        if (mounted) {
          SnackMessage.showError(
              context, result['message'] ?? 'เกิดข้อผิดพลาดในการบันทึก');
        }
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
      if (mounted) {
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการบันทึกข้อมูล');
      }
    } finally {
      if (mounted) {
        setState(() => _savingRoomIds.remove(roomId));
      }
    }
  }

  // Update existing meter readings
  Future<void> _updateMeterReadings(
    String? readingId,
    String waterPrev,
    String waterCurrent,
    String electricPrev,
    String electricCurrent,
  ) async {
    if (readingId == null) return;

    try {
      final waterCurrentVal = double.tryParse(waterCurrent);
      final electricCurrentVal = double.tryParse(electricCurrent);

      if (waterCurrentVal == null || electricCurrentVal == null) {
        SnackMessage.showError(
            context, 'กรุณากรอกเลขมิเตอร์ปัจจุบันให้ถูกต้อง');
        return;
      }

      final waterPrevVal = double.tryParse(waterPrev) ?? 0.0;
      final electricPrevVal = double.tryParse(electricPrev) ?? 0.0;

      if (waterCurrentVal < waterPrevVal ||
          electricCurrentVal < electricPrevVal) {
        SnackMessage.showError(
            context, 'เลขมิเตอร์ปัจจุบันต้องมากกว่าเลขมิเตอร์ก่อนหน้า');
        return;
      }

      final result = await MeterReadingService.updateMeterReading(readingId, {
        'water_previous_reading': waterPrevVal,
        'water_current_reading': waterCurrentVal,
        'electric_previous_reading': electricPrevVal,
        'electric_current_reading': electricCurrentVal,
      });

      if (result['success'] == true) {
        SnackMessage.showSuccess(context, 'อัปเดตข้อมูลสำเร็จ');
        await _loadData(); // Refresh data
      } else {
        SnackMessage.showError(
            context, result['message'] ?? 'เกิดข้อผิดพลาดในการอัปเดต');
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการอัปเดตข้อมูล: $e');
      SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการอัปเดตข้อมูล');
    }
  }

  // Delete meter reading (not billed)
  Future<void> _deleteMeterReading(MeterReadingData data) async {
    // กรณี 3: ถ้าไม่ใช่เดือนปัจจุบัน ไม่อนุญาตให้ลบ
    if (!_isCurrentPeriod) {
      SnackMessage.showError(
          context, 'ไม่สามารถลบข้อมูลในเดือนที่ผ่านมาแล้วได้');
      return;
    }

    final readingId = data.existing?['reading_id']?.toString();
    if (readingId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
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
                'ลบข้อมูลมิเตอร์นี้หรือไม่?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Warning Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ข้อมูลมิเตอร์ทั้งน้ำและไฟจะถูกลบอย่างถาวร',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
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
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ลบ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

    if (confirm == true) {
      try {
        // Show loading dialog
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
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                    'กำลังลบข้อมูล',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await MeterReadingService.deleteMeterReading(readingId);
        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        if (mounted) {
          if (result['success']) {
            SnackMessage.showSuccess(context, 'ลบข้อมูลสำเร็จ');
            await _loadData();
          } else {
            SnackMessage.showError(
                context, result['message'] ?? 'เกิดข้อผิดพลาดในการลบ');
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          debugPrint('เกิดข้อผิดพลาดในการลบข้อมูล: $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการลบข้อมูล');
        }
      }
    }
  }

  // Delete billed meter reading (requires confirmation)
  Future<void> _deleteBilledMeterReading(MeterReadingData data) async {
    // กรณี 3: ถ้าไม่ใช่เดือนปัจจุบัน ไม่อนุญาตให้ลบ
    if (!_isCurrentPeriod) {
      SnackMessage.showError(
          context, 'ไม่สามารถลบข้อมูลในเดือนที่ผ่านมาแล้วได้');
      return;
    }

    final readingId = data.existing?['reading_id']?.toString();
    if (readingId == null) return;

    final roomNumber = data.roomNo;
    final tenantName = data.tenant;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
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
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'ลบข้อมูลที่ออกบิลแล้ว?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Room Info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.meeting_room,
                            size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ห้อง $roomNumber',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenantName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Warning Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ข้อมูลนี้ได้ออกบิลแล้ว การลบอาจส่งผลต่อบิลที่เกี่ยวข้อง',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                          height: 1.4,
                        ),
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
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ยืนยันลบ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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

    if (confirm == true) {
      try {
        // Show loading dialog
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
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                    'กำลังลบข้อมูล',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await MeterReadingService.deleteMeterReading(readingId);
        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        if (mounted) {
          if (result['success']) {
            SnackMessage.showSuccess(context, 'ลบข้อมูลสำเร็จ');
            await _loadData();
          } else {
            SnackMessage.showError(
                context, result['message'] ?? 'เกิดข้อผิดพลาดในการลบ');
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          debugPrint('เกิดข้อผิดพลาดในการลบข้อมูล: $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการลบข้อมูล');
        }
      }
    }
  }
}
