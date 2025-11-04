import 'package:flutter/material.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/views/tenant/tenant_pay_bill_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class TenantBillDetailUi extends StatelessWidget {
  final String invoiceId;
  const TenantBillDetailUi({super.key, required this.invoiceId});

  Future<Map<String, dynamic>?> _load() async {
    return InvoiceService.getInvoiceById(invoiceId);
  }

  String _thaiMonth(int month) {
    const months = [
      '',
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
      'ธันวาคม',
    ];
    if (month < 1 || month > 12) return '';
    return months[month];
  }

  String _thaiFullDateFromDynamic(dynamic value) {
    if (value == null) return '-';
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else {
      final s = value.toString();
      dt = DateTime.tryParse(s);
    }
    if (dt == null) return value.toString();
    final buddhistYear = dt.year + 543;
    return '${dt.day} ${_thaiMonth(dt.month)} $buddhistYear';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('ไม่พบบิล'));
          }

          final status = (data['invoice_status'] ?? '').toString();
          final rental = _asDouble(data['rental_amount']);
          final utilities = _asDouble(data['utilities_amount']);
          final others = _asDouble(data['other_charges']);
          final discount = _asDouble(data['discount_amount']);
          final lateFee = _asDouble(data['late_fee_amount']);
          final subtotal = _asDouble(data['subtotal']);
          final total = _asDouble(data['total_amount']);
          final paid = _asDouble(data['paid_amount']);
          final remain = (total - paid);

          final utilLines =
              (data['utilities'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
          final otherLines =
              (data['other_charges'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
          final payments =
              (data['payments'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];

          final roomcate =
              (data['roomcate'] ?? data['room_category'] ?? data['room_type'] ?? data['room_cate'])?.toString();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                // Header row with back button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                        side: BorderSide(color: Colors.grey[300]!),
                        foregroundColor: Colors.black87,
                        backgroundColor: Colors.white,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'รายละเอียดบิล',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Summary Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลขบิล: ${data['invoice_number'] ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'เดือน/ปี: ${_thaiMonth(data['invoice_month'] ?? 0)} พ.ศ. ${(data['invoice_year'] ?? 0) + 543}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                            if (data['issue_date'] != null) ...[
                              const SizedBox(height: 4),
                              Text('ออกบิล: ${_thaiFullDateFromDynamic(data['issue_date'])}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            ],
                            if (data['due_date'] != null) ...[
                              const SizedBox(height: 2),
                              Text('ครบกำหนด: ${_thaiFullDateFromDynamic(data['due_date'])}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              runSpacing: 6,
                              spacing: 12,
                              children: [
                                Text('ห้อง: ${data['room_number'] ?? '-'}'),
                                if ((roomcate ?? '').isNotEmpty)
                                  Text('ประเภทห้อง: $roomcate'),
                                Text('ผู้เช่า: ${data['tenant_name'] ?? '-'}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Charges Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('ค่าใช้จ่าย'),
                      _kv('ค่าเช่า', rental),
                      _kv('ค่าสาธารณูปโภค (รวม)', utilities),
                      if (utilLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: utilLines.map((u) {
                              final name = (u['utility_name'] ?? '').toString();
                              final unit = _asDouble(u['unit_price']);
                              final usage = _asDouble(u['usage_amount']);
                              final fixed = _asDouble(u['fixed_amount']);
                              final add = _asDouble(u['additional_charge']);
                              final amount = _asDouble(u['total_amount']);
                              String meta = '';
                              if (unit > 0 && usage > 0) {
                                meta = '($usage x ${unit.toStringAsFixed(2)})';
                              } else if (fixed > 0) {
                                meta = '(เหมาจ่าย ${fixed.toStringAsFixed(2)})';
                              }
                              if (add > 0) {
                                meta = meta.isEmpty
                                    ? '(+${add.toStringAsFixed(2)})'
                                    : '$meta (+${add.toStringAsFixed(2)})';
                              }
                              return _line(name, amount, meta: meta);
                            }).toList(),
                          ),
                        ),
                      ],
                      _kv('ค่าใช้จ่ายอื่น (รวม)', others),
                      if (otherLines.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: otherLines.map((o) {
                              final name = (o['charge_name'] ?? '').toString();
                              final amount = _asDouble(o['charge_amount']);
                              return _line(name, amount);
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Totals Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _kv('ส่วนลด', -discount),
                      _kv('ค่าปรับล่าช้า', lateFee),
                      const Divider(height: 24),
                      _kv('ยอดก่อนชำระ', subtotal),
                      _kv('ยอดรวม', total, emphasize: true),
                      _kv('ชำระแล้ว', paid),
                      _kv('คงเหลือ', remain, emphasize: true),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Payments history Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('ประวัติการชำระเงิน'),
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('— ไม่มีรายการ —'),
                        )
                      else
                        Column(
                          children: payments.map((p) {
                            final amount = _asDouble(p['payment_amount']);
                            final dateStr = _thaiFullDateFromDynamic(p['payment_date']);
                            final pstatus = (p['payment_status'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(amount.toStringAsFixed(2)),
                              subtitle: Text(dateStr),
                              trailing: Text(pstatus),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    if (status != 'paid')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TenantPayBillUi(
                                  invoiceId: invoiceId,
                                ),
                              ),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('ชำระเงิน/อัปโหลดสลิป'),
                        ),
                      ),
                    if (status == 'paid')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ดาวน์โหลดสลิป: ยังไม่รองรับ')),
                            );
                          },
                          child: const Text('ดาวน์โหลดสลิป'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String label, double value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasize ? 16 : 14,
            ),
          )
        ],
      ),
    );
  }

  Widget _line(String label, double value, {String? meta}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      title: Text(label),
      subtitle: meta == null || meta.isEmpty ? null : Text(meta),
      trailing: Text(value.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color().withOpacity(0.3)),
      ),
      child: Text(
        _label(),
        style: TextStyle(color: _color(), fontWeight: FontWeight.w700),
      ),
    );
  }
}
