import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/views/tenant/bill_detail_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

class TenantBillsListPage extends StatefulWidget {
  const TenantBillsListPage({super.key});

  @override
  State<TenantBillsListPage> createState() => _TenantBillsListPageState();
}

class _TenantBillsListPageState extends State<TenantBillsListPage> {
  String _status = 'all';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<List<Map<String, dynamic>>> _loadBills() async {
    final user = await AuthMiddleware.getCurrentUser();
    if (user == null || user.tenantId == null) return [];

    return InvoiceService.getAllInvoices(
      tenantId: user.tenantId,
      invoiceMonth: _selectedMonth,
      invoiceYear: _selectedYear,
      status: _status,
      orderBy: 'invoice_year',
      ascending: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'บิลของฉัน',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ตรวจสอบและชำระบิลของคุณ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFilters(),
            ),

            const SizedBox(height: 8),

            // List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadBills(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 3,
                      ),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final bill = items[index];
                      final month = bill['invoice_month'] ?? _selectedMonth;
                      final year = bill['invoice_year'] ?? _selectedYear;
                      final total = _asDouble(bill['total_amount']);
                      final status = (bill['invoice_status'] ?? '').toString();
                      final number = (bill['invoice_number'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TenantBillDetailUi(
                                    invoiceId: bill['invoice_id'],
                                  ),
                                ),
                              );
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left: title & subtitle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'เดือน $month/$year',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'เลขบิล: $number',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Right: amount & status
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          total.toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _StatusChip(status: status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    InputBorder _border(Color color) => OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 1),
          borderRadius: BorderRadius.circular(8),
        );

    final baseDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: _border(Colors.grey[300]!),
      focusedBorder: _border(AppTheme.primary),
    );

    return Row(
      children: [
        // Month
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedMonth,
            decoration: baseDecoration.copyWith(labelText: 'เดือน'),
            items: List.generate(12, (i) => i + 1)
                .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                .toList(),
            onChanged: (v) => setState(() => _selectedMonth = v ?? _selectedMonth),
          ),
        ),
        const SizedBox(width: 12),

        // Year (current +/- 1)
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: baseDecoration.copyWith(labelText: 'ปี'),
            items: _yearOptions()
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
          ),
        ),
        const SizedBox(width: 12),

        // Status
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _status,
            decoration: baseDecoration.copyWith(labelText: 'สถานะ'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
              DropdownMenuItem(value: 'pending', child: Text('ค้างชำระ')),
              DropdownMenuItem(value: 'partial', child: Text('ชำระบางส่วน')),
              DropdownMenuItem(value: 'paid', child: Text('ชำระแล้ว')),
              DropdownMenuItem(value: 'overdue', child: Text('เกินกำหนด')),
              DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
        ),
        const SizedBox(width: 12),

        OutlinedButton(
          onPressed: () => setState(() {}),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.primary, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('กรอง'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'ไม่พบรายการบิล',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ลองเปลี่ยนตัวกรอง หรือเลือกเดือน/ปีอื่น',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return [now - 1, now, now + 1];
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _label() {
    switch (status) {
      case 'paid':
        return 'ชำระแล้ว';
      case 'partial':
        return 'ชำระบางส่วน';
      case 'overdue':
        return 'เกินกำหนด';
      case 'cancelled':
        return 'ยกเลิก';
      case 'pending':
        return 'ค้างชำระ';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color().withOpacity(0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
            color: _color(), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
