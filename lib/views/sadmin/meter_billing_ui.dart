import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/colors.dart';
import '../../services/meter_service.dart';
import 'invoice_add_ui.dart';

class MeterBillingPage extends StatefulWidget {
  final bool hideBottomNav;
  final String? branchId;
  final String? branchName;

  const MeterBillingPage({
    Key? key,
    this.hideBottomNav = false,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<MeterBillingPage> createState() => _MeterBillingPageState();
}

class _MeterBillingPageState extends State<MeterBillingPage> {
  // Controller for the search TextField. Used to capture and clear the search input.
  final TextEditingController _searchController = TextEditingController();

  // Stores the current search query string. When this changes, _applyFilters
  // updates the underlying _roomFilter used by the list filter.
  String _searchQuery = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _loading = false;
  List<Map<String, dynamic>> _readings = [];
  String _roomFilter = '';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void dispose() {
    // Dispose of controllers to free resources when this widget is removed.
    _searchController.dispose();
    super.dispose();
  }

  /// Applies the current search query and other filters to update the room filter.
  void _applyFilters() {
    setState(() {
      // Trim and assign the search query to _roomFilter which is used by
      // _getFilteredReadings to filter the list. This keeps the search and
      // filtering logic consistent.
      _roomFilter = _searchQuery.trim();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final list = await MeterReadingService.getAllMeterReadings(
        branchId: widget.branchId,
        status: 'confirmed',
        readingMonth: _selectedMonth,
        readingYear: _selectedYear,
        includeInitial: false,
        limit: 10000,
        orderBy: 'room_id',
        ascending: true,
      );

      // Filter only readings that are not yet billed
      _readings = list.where((r) => (r['invoice_id'] == null)).toList();
      // Sort by room number
      _readings.sort((a, b) => (a['room_number'] ?? '')
          .toString()
          .compareTo((b['room_number'] ?? '').toString()));

      // Build categories from readings
      final cats = _readings
          .map((r) => (r['room_category_name'] ?? '').toString())
          .where((s) => s.trim().isNotEmpty && s.trim() != '-')
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      // Do not include 'ทั้งหมด' here; the UI will provide a dedicated
      // 'ทั้งหมด' (All) option with a null value.
      _categories = cats;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredReadings() {
    final roomKey = _roomFilter.trim().toLowerCase();
    final category = _selectedCategory;
    return _readings.where((r) {
      final rn = (r['room_number'] ?? '').toString().toLowerCase();
      final rc = (r['room_category_name'] ?? '').toString();
      final roomMatch = roomKey.isEmpty || rn.contains(roomKey);
      final catMatch = category == null || rc == category;
      return roomMatch && catMatch;
    }).toList();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (white)
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
                          'ออกบิล',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'เลือกเดือนและปีเพื่อแสดงรายการที่พร้อมออกบิล',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    // Update the search query and apply filters whenever the user types.
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
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
                              _applyFilters();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Filters and list within responsive container
            Expanded(
              child: Column(
                children: [
                  // Filters for category, month and year using custom styled dropdowns
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // หมวดหมู่ห้อง
                        Row(
                          children: [
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
                                                  child:
                                                      Text(_getMonthName(m))))
                                              .toList(),
                                          onChanged: (val) async {
                                            setState(() => _selectedMonth =
                                                val ?? _selectedMonth);
                                            await _loadData();
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
                                          items: List.generate(
                                                  6,
                                                  (i) =>
                                                      DateTime.now().year - i)
                                              .map((y) => DropdownMenuItem(
                                                  value: y,
                                                  child: Text('${y + 543}')))
                                              .toList(),
                                          onChanged: (val) async {
                                            setState(() => _selectedYear =
                                                val ?? _selectedYear);
                                            await _loadData();
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
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary))
                        : _getFilteredReadings().isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                color: AppTheme.primary,
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  itemCount: _getFilteredReadings().length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) =>
                                      _buildReadingTile(
                                          _getFilteredReadings()[index]),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, color: Colors.grey[400], size: 56),
          const SizedBox(height: 8),
          Text(
            'ไม่มีรายการพร้อมออกบิลสำหรับ ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTile(Map<String, dynamic> r) {
    final roomNo = (r['room_number'] ?? '-').toString();
    final tenant = (r['tenant_name'] ?? '-').toString();
    final roomCate = (r['room_category_name'] ?? '-').toString();
    final monthName = _getMonthName(r['reading_month'] ?? _selectedMonth);
    final yearDisplay = (_selectedYear + 543).toString();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _goToInvoice(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading icon/avatar
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.meeting_room, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tenant name
                    Text(
                      tenant,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // A wrap of info chips to adapt to various widths
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _infoItem(Icons.tag, 'ห้อง: $roomNo'),
                        _infoItem(Icons.category, 'ประเภท: $roomCate'),
                        _infoItem(Icons.calendar_today,
                            'รอบบิลเดือน$monthName $yearDisplay'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Trailing arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[500],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a small info item with an icon and text used inside the reading
  /// tile. This widget uses a Row with minimal spacing and a smaller font size
  /// to display secondary details. It helps keep `_buildReadingTile` concise.
  Widget _infoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.grey[600], size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
        ),
      ],
    );
  }

  Future<void> _goToInvoice(Map<String, dynamic> r) async {
    final initial = {
      'branch_id': r['branch_id'],
      'room_id': r['room_id'],
      'tenant_id': r['tenant_id'],
      'contract_id': r['contract_id'],
      'reading_id': r['reading_id'],
      'invoice_month': r['reading_month'],
      'invoice_year': r['reading_year'],
    };

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceAddPage(initialData: initial),
      ),
    );

    if (res is Map && res['success'] == true) {
      // After successful invoice creation, refresh list (the item should disappear)
      await _loadData();
    }
  }
}
