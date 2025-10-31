import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ออกบิลค่ามิเตอร์'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
                            value: m, child: Text(_getMonthName(m))))
                        .toList(),
                    onChanged: (v) async {
                      setState(() => _selectedMonth = v ?? _selectedMonth);
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
                    items: List.generate(6, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(
                            value: y, child: Text('${y + 543}')))
                        .toList(),
                    onChanged: (v) async {
                      setState(() => _selectedYear = v ?? _selectedYear);
                      await _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'รีเฟรช',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _readings.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _readings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _buildReadingTile(_readings[index]),
                        ),
                      ),
          ),
        ],
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: const Icon(Icons.meeting_room, color: AppTheme.primary),
        ),
        title: Text('ห้อง $roomNo — $tenant',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            'เดือน ${_getMonthName(r['reading_month'] ?? _selectedMonth)} ${_selectedYear + 543}\nน้ำ: ${water.toStringAsFixed(0)} หน่วย  |  ไฟ: ${elec.toStringAsFixed(0)} หน่วย'),
        isThreeLine: true,
        trailing: ElevatedButton.icon(
          onPressed: () => _goToInvoice(r),
          icon: const Icon(Icons.assignment_add),
          label: const Text('ออกบิล'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
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
