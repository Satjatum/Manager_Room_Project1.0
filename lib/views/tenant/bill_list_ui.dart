import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
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
  bool _loading = false;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<List<Map<String, dynamic>>> _loadBills() async {
    setState(() => _loading = true);
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (user == null || user.tenantId == null) return [];

      final bills = await InvoiceService.getAllInvoices(
        tenantId: user.tenantId,
        invoiceMonth: _selectedMonth,
        invoiceYear: _selectedYear,
        status: _status,
        orderBy: 'invoice_year',
        ascending: false,
      );

      // ติดธงว่าบิลใดมีสลิปรอตรวจสอบอยู่
      final invoiceIds = bills
          .map((b) => (b['invoice_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      if (invoiceIds.isNotEmpty) {
        final pendingSet = await PaymentService.getInvoicesWithPendingSlip(
          invoiceIds: invoiceIds,
          tenantId: user.tenantId,
        );
        for (final b in bills) {
          final id = (b['invoice_id'] ?? '').toString();
          b['has_pending_slip'] = pendingSet.contains(id);
        }
      }
      return bills;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
        );
      }
      return [];
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

  String _thaiMonthYear(int month, int year) {
    final buddhistYear = year + 543;
    return '${_getMonthName(month)}  $buddhistYear';
  }

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    tooltip: 'ย้อนกลับ',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'รายการบิลค่าเช่า',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ตรวจสอบและจัดการบิลค่าเช่าของคุณ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Filter Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    items: List.generate(12, (i) => i + 1)
                                        .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(_getMonthName(m))))
                                        .toList(),
                                    onChanged: (val) async {
                                      setState(() => _selectedMonth =
                                          val ?? _selectedMonth);
                                      await _loadBills();
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
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    items: List.generate(
                                            6, (i) => DateTime.now().year - i)
                                        .map((y) => DropdownMenuItem(
                                            value: y,
                                            child: Text('${y + 543}')))
                                        .toList(),
                                    onChanged: (val) async {
                                      setState(() =>
                                          _selectedYear = val ?? _selectedYear);
                                      await _loadBills();
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
                  const SizedBox(height: 12),
                  // Status Dropdown
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            child: DropdownButton<String>(
                              value: _status,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 20),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('ทั้งหมด')),
                                DropdownMenuItem(
                                    value: 'pending', child: Text('ค้างชำระ')),
                                DropdownMenuItem(
                                    value: 'partial',
                                    child: Text('ชำระบางส่วน')),
                                DropdownMenuItem(
                                    value: 'paid', child: Text('ชำระแล้ว')),
                                DropdownMenuItem(
                                    value: 'overdue', child: Text('เกินกำหนด')),
                                DropdownMenuItem(
                                    value: 'cancelled', child: Text('ยกเลิก')),
                              ],
                              onChanged: (val) async {
                                setState(() => _status = val ?? _status);
                                await _loadBills();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Content Section
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadBills(),
                        builder: (context, snapshot) {
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return _buildEmpty();
                          }

                          return RefreshIndicator(
                            onRefresh: _loadBills,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) =>
                                  _buildBillCard(items[index]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบรายการบิล',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ไม่มีบิลสำหรับ ${_getMonthName(_selectedMonth)} ${_selectedYear + 543}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    // Match style to _invoiceCard in payment_verification_ui.dart
    final total = _asDouble(bill['total_amount']);
    final status = (bill['invoice_status'] ?? '').toString();
    final number = (bill['invoice_number'] ?? '-').toString();
    final tenantName = (bill['tenant_name'] ?? '-').toString();
    final roomNumber = (bill['room_number'] ?? '-').toString();
    final roomcate = (bill['roomcate_name'] ?? '-').toString();
    final due = (bill['due_date'] ?? '').toString();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = const Color(0xFF22C55E);
        statusLabel = 'ชำระแล้ว';
        break;
      case 'overdue':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'เกินกำหนด';
        break;
      case 'partial':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'ชำระบางส่วน';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = 'ยกเลิก';
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'ค้างชำระ';
    }

    String _formatThaiDate(String iso) {
      if (iso.isEmpty) return '-';
      DateTime? dt = DateTime.tryParse(iso);
      dt ??= DateTime.now();
      const thMonths = [
        '',
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.'
      ];
      final y = dt.year + 543;
      final m = thMonths[dt.month];
      final d = dt.day.toString();
      return '$d $m $y';
    }

    String _formatMoney(double v) {
      final s = v.toStringAsFixed(2);
      final parts = s.split('.');
      final intPart = parts[0];
      final dec = parts[1];
      final buf = StringBuffer();
      for (int i = 0; i < intPart.length; i++) {
        buf.write(intPart[i]);
        final left = intPart.length - i - 1;
        if (left > 0 && left % 3 == 0) buf.write(',');
      }
      return buf.toString() + '.' + dec;
    }

    return InkWell(
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row (dot + label) same as _invoiceCard
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),

            const SizedBox(height: 8),

            // Title: tenant - roomcate เลขที่ห้อง
            Text(
              '$tenantName - $roomcate เลขที่ $roomNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),
            // Sub: Bill #... • due date (พ.ศ.)
            Text(
              'Bill #$number • ${_formatThaiDate(due)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                const Text('ยอดรวม',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Text(
                  '${_formatMoney(total)} บาท',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String? overrideLabel;
  final Color? overrideColor;
  const _StatusChip(
      {required this.status, this.overrideLabel, this.overrideColor});

  Color _color() {
    if (overrideColor != null) return overrideColor!;
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
    if (overrideLabel != null && overrideLabel!.isNotEmpty) {
      return overrideLabel!;
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _color().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
