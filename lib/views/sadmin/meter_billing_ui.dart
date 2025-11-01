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
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _loading = false;
  List<Map<String, dynamic>> _readings = [];

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
                          'ออกบิลค่ามิเตอร์',
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

            // Filters and list within responsive container
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = _maxContentWidth(constraints.maxWidth);
                  final content = Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 6,
                                  spreadRadius: -2),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedMonth,
                                  decoration: const InputDecoration(
                                    labelText: 'เดือน',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: List.generate(12, (i) => i + 1)
                                      .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(_getMonthName(m))))
                                      .toList(),
                                  onChanged: (v) async {
                                    setState(() =>
                                        _selectedMonth = v ?? _selectedMonth);
                                    await _loadData();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedYear,
                                  decoration: const InputDecoration(
                                    labelText: 'ปี (พ.ศ.)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: List.generate(
                                          6, (i) => DateTime.now().year - i)
                                      .map((y) => DropdownMenuItem(
                                          value: y, child: Text('${y + 543}')))
                                      .toList(),
                                  onChanged: (v) async {
                                    setState(() =>
                                        _selectedYear = v ?? _selectedYear);
                                    await _loadData();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary))
                            : _readings.isEmpty
                                ? _buildEmpty()
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    color: AppTheme.primary,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 0, 24, 24),
                                      itemCount: _readings.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) =>
                                          _buildReadingTile(_readings[index]),
                                    ),
                                  ),
                      ),
                    ],
                  );

                  // Center on mobile, left-align on larger screens for readability
                  if (isMobileApp) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: content,
                      ),
                    );
                  }
                  return Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: content,
                    ),
                  );
                },
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
    final water = ((r['water_usage'] ?? 0.0) as num).toDouble();
    final elec = ((r['electric_usage'] ?? 0.0) as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.meeting_room, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ห้อง $roomNo — $tenant',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เดือน ${_getMonthName(r['reading_month'] ?? _selectedMonth)} ${_selectedYear + 543}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _goToInvoice(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: const Text('ออกบิล'),
            ),
          ],
        ),
      ),
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

// Responsive content widths (Mobile S/M/L, Tablet, Laptop, Laptop L, 4K)
double _maxContentWidth(double screenWidth) {
  if (screenWidth >= 2560) return 1280; // 4K
  if (screenWidth >= 1440) return 1100; // Laptop L
  if (screenWidth >= 1200) return 1000; // Laptop
  if (screenWidth >= 900) return 860; // Tablet landscape / small desktop
  if (screenWidth >= 600) return 560; // Mobile L / Tablet portrait
  return screenWidth; // Mobile S/M
}
