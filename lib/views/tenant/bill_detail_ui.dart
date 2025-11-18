import 'package:flutter/material.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
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
    final inv = await InvoiceService.getInvoiceById(invoiceId);
    if (inv != null) {
      try {
        final slip = await PaymentService.getLatestSlipForInvoice(invoiceId);
        if (slip != null) inv['latest_slip'] = slip;
      } catch (_) {}
    }
    return inv;
  }

  String _thaiMonth(int month) {
    const months = [
      '',
      'à¸¡à¸à¸£à¸²à¸„à¸¡',
      'à¸à¸¸à¸¡à¸ à¸²à¸žà¸±à¸™à¸˜à¹Œ',
      'à¸¡à¸µà¸™à¸²à¸„à¸¡',
      'à¹€à¸¡à¸©à¸²à¸¢à¸™',
      'à¸žà¸¤à¸©à¸ à¸²à¸„à¸¡',
      'à¸¡à¸´à¸–à¸¸à¸™à¸²à¸¢à¸™',
      'à¸à¸£à¸à¸Žà¸²à¸„à¸¡',
      'à¸ªà¸´à¸‡à¸«à¸²à¸„à¸¡',
      'à¸à¸±à¸™à¸¢à¸²à¸¢à¸™',
      'à¸•à¸¸à¸¥à¸²à¸„à¸¡',
      'à¸žà¸¤à¸¨à¸ˆà¸´à¸à¸²à¸¢à¸™',
      'à¸˜à¸±à¸™à¸§à¸²à¸„à¸¡',
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
    return FutureBuilder<Map<String, dynamic>?>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('à¹„à¸¡à¹ˆà¸žà¸šà¸šà¸´à¸¥')),
          );
        }

        final status = (data['invoice_status'] ?? '').toString();
        final latestSlip =
            (data['latest_slip'] as Map<String, dynamic>?) ?? const {};
        // à¸ªà¸„à¸µà¸¡à¸²à¹ƒà¸«à¸¡à¹ˆ: à¹„à¸¡à¹ˆà¸¡à¸µ slip_status à¹à¸¥à¹‰à¸§
        final isRejectedSlip =
            ((latestSlip['rejection_reason'] ?? '').toString()).isNotEmpty;
        final hasPendingSlip = latestSlip.isNotEmpty &&
            latestSlip['payment_id'] == null &&
            !isRejectedSlip;
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
        final otherLines = (data['other_charge_lines'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            const [];
        final payments =
            (data['payments'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                // Header row with back button
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
                      tooltip: 'à¸¢à¹‰à¸­à¸™à¸à¸¥à¸±à¸š',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'à¸£à¸²à¸¢à¸¥à¸°à¹€à¸­à¸µà¸¢à¸”à¸šà¸´à¸¥à¸„à¹ˆà¸²à¹€à¸Šà¹ˆà¸²',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸šà¸£à¸²à¸¢à¸¥à¸°à¹€à¸­à¸µà¸¢à¸”à¸šà¸´à¸¥à¸„à¹ˆà¸²à¹€à¸Šà¹ˆà¸²à¸‚à¸­à¸‡à¸„à¸¸à¸“',
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
                              'à¹€à¸¥à¸‚à¸šà¸´à¸¥: ${data['invoice_number'] ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'à¹€à¸”à¸·à¸­à¸™/à¸›à¸µ: ${_thaiMonth(data['invoice_month'] ?? 0)} à¸ž.à¸¨. ${(data['invoice_year'] ?? 0) + 543}',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13),
                            ),
                            if (data['issue_date'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                  'à¸­à¸­à¸à¸šà¸´à¸¥: ${_thaiFullDateFromDynamic(data['issue_date'])}',
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 13)),
                            ],
                            if (data['due_date'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                  'à¸„à¸£à¸šà¸à¸³à¸«à¸™à¸”: ${_thaiFullDateFromDynamic(data['due_date'])}',
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                      _StatusChip(
                        status: status,
                        overrideLabel: hasPendingSlip ? 'à¸£à¸­à¸•à¸£à¸§à¸ˆà¸ªà¸­à¸š' : null,
                        overrideColor: hasPendingSlip ? Colors.orange : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (isRejectedSlip)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'à¸ªà¸¥à¸´à¸›à¸¥à¹ˆà¸²à¸ªà¸¸à¸”à¸–à¸¹à¸à¸›à¸à¸´à¹€à¸ªà¸˜ à¸à¸£à¸¸à¸“à¸²à¸­à¸±à¸›à¹‚à¸«à¸¥à¸”à¹ƒà¸«à¸¡à¹ˆ',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),

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
                      const _SectionHeader('à¸„à¹ˆà¸²à¹ƒà¸Šà¹‰à¸ˆà¹ˆà¸²à¸¢'),
                      _kv('à¸„à¹ˆà¸²à¹€à¸Šà¹ˆà¸²', rental),
                      _kv('à¸„à¹ˆà¸²à¸ªà¸²à¸˜à¸²à¸£à¸“à¸¹à¸›à¹‚à¸ à¸„', utilities),
                      _kv('à¸„à¹ˆà¸²à¹ƒà¸Šà¹‰à¸ˆà¹ˆà¸²à¸¢à¸­à¸·à¹ˆà¸™', others),
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
                              String final metaParts = <String>[]; if (usage > 0) { metaParts.add(usage.toStringAsFixed(2)); } if (unit > 0) { metaParts.add(unit.toStringAsFixed(2)); } final meta = metaParts.join(' � ');
                              if (unit > 0 && usage > 0) {
                                final metaParts = <String>[]; if (usage > 0) { metaParts.add(usage.toStringAsFixed(2)); } if (unit > 0) { metaParts.add(unit.toStringAsFixed(2)); } final meta = metaParts.join(' � ');
                              } else if (fixed > 0) {
                                final metaParts = <String>[]; if (usage > 0) { metaParts.add(usage.toStringAsFixed(2)); } if (unit > 0) { metaParts.add(unit.toStringAsFixed(2)); } final meta = metaParts.join(' � ');
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
                      ]
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
                      _kv('à¸ªà¹ˆà¸§à¸™à¸¥à¸”', -discount),
                      _kv('à¸„à¹ˆà¸²à¸›à¸£à¸±à¸šà¸¥à¹ˆà¸²à¸Šà¹‰à¸²', lateFee),
                      const Divider(height: 24),
                      _kv('à¸¢à¸­à¸”à¸£à¸§à¸¡', total, emphasize: true),
                      _kv('à¸Šà¸³à¸£à¸°à¹à¸¥à¹‰à¸§', paid),
                      _kv('à¸„à¸‡à¹€à¸«à¸¥à¸·à¸­', remain, emphasize: true),
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
                      const _SectionHeader('à¸›à¸£à¸°à¸§à¸±à¸•à¸´à¸à¸²à¸£à¸Šà¸³à¸£à¸°à¹€à¸‡à¸´à¸™'),
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('â€” à¹„à¸¡à¹ˆà¸¡à¸µà¸£à¸²à¸¢à¸à¸²à¸£ â€”'),
                        )
                      else
                        Column(
                          children: payments.map((p) {
                            final amount = _asDouble(p['payment_amount']);
                            final dateStr =
                                _thaiFullDateFromDynamic(p['payment_date']);
                            final pstatus =
                                (p['payment_status'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(amount.toStringAsFixed(2)),
                              subtitle: Text(dateStr),
                              trailing: Text(pstatus),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
          bottomNavigationBar: (status != 'paid' && !hasPendingSlip)
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        )
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,\r\n                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        child: const Text(
                          'à¸Šà¸³à¸£à¸°à¹€à¸‡à¸´à¸™/à¸­à¸±à¸›à¹‚à¸«à¸¥à¸”à¸ªà¸¥à¸´à¸›',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
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
        return 'à¸Šà¸³à¸£à¸°à¹à¸¥à¹‰à¸§';
      case 'partial':
        return 'à¸Šà¸³à¸£à¸°à¸šà¸²à¸‡à¸ªà¹ˆà¸§à¸™';
      case 'overdue':
        return 'à¹€à¸à¸´à¸™à¸à¸³à¸«à¸™à¸”';
      case 'cancelled':
        return 'à¸¢à¸à¹€à¸¥à¸´à¸';
      case 'pending':
        return 'à¸„à¹‰à¸²à¸‡à¸Šà¸³à¸£à¸°';
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


