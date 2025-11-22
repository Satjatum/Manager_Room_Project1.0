import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as fnd;
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/meter_service.dart';

class PaymentVerificationDetailPage extends StatefulWidget {
  final String? slipId;
  final String? invoiceId;
  const PaymentVerificationDetailPage({
    super.key,
    this.slipId,
    this.invoiceId,
  }) : assert(slipId != null || invoiceId != null,
            'Either slipId or invoiceId must be provided');

  @override
  State<PaymentVerificationDetailPage> createState() =>
      _PaymentVerificationDetailPageState();
}

class _PaymentVerificationDetailPageState
    extends State<PaymentVerificationDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _slip;
  Map<String, dynamic>? _invoice;
  // cache meter readings referenced by invoice_utilities.reading_id
  final Map<String, Map<String, dynamic>> _readingById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  // Safe conversion: dynamic -> List<Map<String, dynamic>>
  List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) {
      final out = <Map<String, dynamic>>[];
      for (final e in v) {
        if (e is Map) {
          out.add(Map<String, dynamic>.from(e as Map));
        }
      }
      return out;
    }
    return const [];
  }

  // Safe conversion: dynamic -> Map<String, dynamic>
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.from(v as Map);
    }
    if (v is List && v.isNotEmpty && v.first is Map) {
      return Map<String, dynamic>.from(v.first as Map);
    }
    return <String, dynamic>{};
  }

  String _thaiDate(String s) {
    if (s.isEmpty) return '-';
    final base =
        s.split(' ').first; // handle 'YYYY-MM-DD' or ISO 'YYYY-MM-DDTHH:mm'
    final iso = base.contains('T') ? base : base;
    final d = DateTime.tryParse(iso);
    if (d == null) return base;
    final y = d.year + 543;
    final m = d.month.toString().padLeft(2, '0');
    final d2 = d.day.toString().padLeft(2, '0');
    return '$d2/$m/$y';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.slipId != null) {
        final res = await PaymentService.getSlipById(widget.slipId!);
        Map<String, dynamic>? inv;
        // Load invoice details (with utilities/other charges/payments)
        final invId = (res?['invoice_id'] ?? '').toString();
        if (invId.isNotEmpty) {
          var invRaw = await InvoiceService.getInvoiceById(invId);
          // Hybrid: รีคอมพิวต์ค่าปรับล่าช้าเมื่อเปิดดูรายละเอียด
          try {
            final changed =
                await InvoiceService.recomputeLateFeeFromSettings(invId);
            if (changed) {
              invRaw = await InvoiceService.getInvoiceById(invId);
            }
          } catch (_) {}
          inv = _asMap(invRaw);
          // Preload meter reading(s) if present on utilities
          try {
            final utils = _asListOfMap(inv?['utilities']);
            final ids = utils
                .map((u) => (u['reading_id'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();
            if (ids.isNotEmpty) {
              final futures = ids.map((id) async {
                final r = await MeterReadingService.getMeterReadingById(id);
                if (r != null) _readingById[id] = r;
              }).toList();
              await Future.wait(futures);
            }
          } catch (_) {}
        }
        setState(() {
          _slip = res;
          _invoice = inv ?? _invoice;
          _loading = false;
        });
      } else if (widget.invoiceId != null) {
        var invRaw = await InvoiceService.getInvoiceById(widget.invoiceId!);
        try {
          // Hybrid: รีคอมพิวต์ค่าปรับล่าช้าเมื่อเปิดดูรายละเอียด
          final changed = await InvoiceService.recomputeLateFeeFromSettings(
              widget.invoiceId!);
          if (changed) {
            invRaw = await InvoiceService.getInvoiceById(widget.invoiceId!);
          }
        } catch (_) {}
        final inv = _asMap(invRaw);
        try {
          final utils = _asListOfMap(inv['utilities']);
          final ids = utils
              .map((u) => (u['reading_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          if (ids.isNotEmpty) {
            final futures = ids.map((id) async {
              final r = await MeterReadingService.getMeterReadingById(id);
              if (r != null) _readingById[id] = r;
            }).toList();
            await Future.wait(futures);
          }
        } catch (_) {}
        setState(() {
          _invoice = inv;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดรายละเอียดไม่สำเร็จ: $e')),
        );
      }
    }
  }

  String _firstFileUrl() {
    final files = _asListOfMap(_slip?['files']);
    if (files.isNotEmpty) {
      final u = (files.first['file_url'] ?? '').toString();
      if (u.isNotEmpty) return u;
    }
    return (_slip?['slip_image'] ?? '').toString();
  }

  Future<void> _openSlip() async {
    final urlStr = _firstFileUrl();
    if (urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบลิงก์สลิป')),
      );
      return;
    }
    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลิงก์สลิปไม่ถูกต้อง')),
      );
      return;
    }
    final ok = fnd.kIsWeb
        ? await launchUrl(uri, webOnlyWindowName: '_blank')
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดลิงก์ไม่สำเร็จ')),
        );
      }
    }
  }

  Future<void> _approve() async {
    if (_slip == null) return;
    final amtCtrl = TextEditingController(
      text: _asDouble(_slip!['paid_amount']).toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('อนุมัติการชำระเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'จำนวนเงินที่อนุมัติ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(),
              ),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง')),
      );
      return;
    }

    // ตรวจสอบจำนวนเงินที่อนุมัติไม่เกินบิล
    final invFull = _asMap(_invoice ?? _slip!['invoices']);
    final totalAmount = _asDouble(invFull['total_amount']);
    final paidAmount =
        _asDouble(invFull['paid_amount'] ?? _slip!['invoice_paid']);
    final remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'จำนวนเงินที่อนุมัติ (${amount.toStringAsFixed(2)}) ไม่สามารถเกินยอดคงเหลือ (${remaining.toStringAsFixed(2)}) ได้')),
      );
      return;
    }

    try {
      setState(() => _loading = true);
      // Hybrid: ใช้ส่วนลดยอดชำระก่อนกำหนดจาก Payment Settings ก่อนอนุมัติ
      try {
        final invId = (_slip!['invoice_id'] ?? '').toString();
        DateTime? payDate;
        final payDateStr = (_slip!['payment_date'] ?? '').toString();
        if (payDateStr.isNotEmpty) {
          payDate = DateTime.tryParse(payDateStr);
        }
        if (invId.isNotEmpty) {
          await InvoiceService.applyEarlyDiscountFromSettings(
            invoiceId: invId,
            paymentDate: payDate,
          );
        }
      } catch (_) {}
      final result = await PaymentService.verifySlip(
        slipId: _slip!['slip_id'],
        approvedAmount: amount,
        paymentMethod: 'transfer',
        adminNotes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'สำเร็จ')));
      }
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อนุมัติไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _reject() async {
    if (_slip == null) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปฏิเสธสลิป'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'ระบุเหตุผล (ไม่บังคับ)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);
      final result = await PaymentService.rejectSlip(
        slipId: _slip!['slip_id'],
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'สำเร็จ')));
      }
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (meterlist style)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบสลิปชำระเงิน',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ตรวจสอบ อนุมัติ/ปฏิเสธ และติดตามสถานะการชำระ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : (widget.slipId != null && _slip == null) ||
                          (widget.invoiceId != null && _invoice == null)
                      ? const Center(child: Text('ไม่พบข้อมูล'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (widget.slipId != null) ...[
                                    _buildHeaderCard(),
                                    const SizedBox(height: 12),
                                    _buildSlipFiles(),
                                    const SizedBox(height: 16),
                                    _buildActionBar(),
                                  ] else ...[
                                    _buildInvoiceHeaderCard(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final s = _slip!;
    final invFull = _asMap(_invoice ?? s['invoices']);
    final room = invFull.isNotEmpty ? (invFull['rooms'] ?? {}) : {};
    final br = room.isNotEmpty ? (room['branches'] ?? {}) : {};
    final tenant = invFull.isNotEmpty ? (invFull['tenants'] ?? {}) : {};

    // ฟิลด์แบบ flat (เผื่อโครงสร้างบางส่วนไม่ครบ)
    final invoiceNumber =
        (invFull['invoice_number'] ?? s['invoice_number'] ?? '-').toString();
    final invoiceMonth = (invFull['invoice_month'] ?? '-').toString();
    final invoiceYear = (invFull['invoice_year'] ?? '-').toString();
    final issueDate = (invFull['issue_date'] ?? '').toString();
    final dueDate = (invFull['due_date'] ?? '').toString();
    final tenantName = (s['tenant_name'] ??
            invFull['tenant_name'] ??
            tenant['tenant_fullname'] ??
            '-')
        .toString();
    final tenantPhone = (s['tenant_phone'] ??
            invFull['tenant_phone'] ??
            tenant['tenant_phone'] ??
            '-')
        .toString();
    final roomNumber = (s['room_number'] ??
            invFull['room_number'] ??
            room['room_number'] ??
            '-')
        .toString();
    final branchName =
        (s['branch_name'] ?? invFull['branch_name'] ?? br['branch_name'] ?? '-')
            .toString();
    final invoiceStatus =
        (s['invoice_status'] ?? invFull['invoice_status'] ?? '-').toString();

    // Amounts
    double rentalAmount = _asDouble(invFull['rental_amount']);
    double discountAmount = _asDouble(invFull['discount_amount']);
    double lateFeeAmount = _asDouble(invFull['late_fee_amount']);
    final totalAmount = _asDouble(invFull['total_amount']);
    final paidAmount = _asDouble(invFull['paid_amount'] ?? s['invoice_paid']);
    final double remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

    // Utilities detail lines
    final utils = _asListOfMap(invFull['utilities']);
    final otherLines = _asListOfMap(invFull['other_charge_lines']);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '#$invoiceNumber',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _slipStatusChip(_slip),
              ],
            ),
            const SizedBox(height: 8),
            // ช่องรูปที่ผู้เช่าแนบมา (thumbnail)
            _buildInlineSlipThumbnails(),
            const Divider(height: 20),

            // รายละเอียด #หัวเรื่อง
            const Text('รายละเอียดบิล',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _kv('เลขบิล', invoiceNumber),
            _kv('รอบบิลเดือน', '$invoiceMonth/$invoiceYear'),
            _kv('ออกบิลวันที่', issueDate.toString().split('T').first),
            _kv('ครบกำหนดชำระ', dueDate.toString().split('T').first),
            const SizedBox(height: 8),

            // ผู้เช่า/ห้อง/สาขา
            _kv('ผู้เช่า', tenantName),
            _kv('เบอร์', tenantPhone),
            _kv('ห้อง', roomNumber),

            const Divider(height: 24),
            const Text('ค่าใช้จ่าย',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _moneyRow('ค่าเช่า', rentalAmount),
            // ค่าน้ำ/ค่าไฟ แยกรายการพร้อม subtext แสดงตัวเลขเท่านั้น
            ...utils.map((u) {
              final name = (u['utility_name'] ?? '').toString();
              final unitPrice = _asDouble(u['unit_price']);
              final usage = _asDouble(u['usage_amount']);
              final total = _asDouble(u['total_amount']);
              final readingId = (u['reading_id'] ?? '').toString();
              double? prev;
              double? curr;
              if (readingId.isNotEmpty && _readingById.containsKey(readingId)) {
                final r = _readingById[readingId]!;
                if (name.contains('น้ำ')) {
                  prev = _asDouble(r['water_previous_reading']);
                  curr = _asDouble(r['water_current_reading']);
                } else if (name.contains('ไฟ')) {
                  prev = _asDouble(r['electric_previous_reading']);
                  curr = _asDouble(r['electric_current_reading']);
                }
              }
              // subtext ตัวเลขเท่านั้น
              final parts = <String>[];
              if (prev != null && curr != null) {
                parts.add(
                    '${prev.toStringAsFixed(2)} - ${curr.toStringAsFixed(2)} = ${usage.toStringAsFixed(2)}');
              } else {
                parts.add(usage.toStringAsFixed(2));
              }
              if (unitPrice > 0) {
                parts.add(unitPrice.toStringAsFixed(2));
              }
              final sub = parts.join(' • ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _moneyRow(name, total),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              );
            }).toList(),

            // ค่าใช้จ่ายอื่นๆ
            if (otherLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('ค่าใช้จ่ายอื่นๆ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...otherLines.map((o) {
                final title = (o['charge_name'] ?? '').toString();
                final amt = _asDouble(o['charge_amount']);
                final desc = (o['charge_desc'] ?? '').toString();
                final label = desc.isNotEmpty ? '$title ($desc)' : title;
                return _moneyRow(label, amt);
              }).toList(),
            ],

            if (discountAmount > 0)
              _moneyRow('ส่วนลด', -discountAmount, emphasis: true),
            if (lateFeeAmount > 0)
              _moneyRow('ค่าปรับล่าช้า', lateFeeAmount, emphasis: true),

            const Divider(height: 24),
            _moneyRow('ยอดรวม', totalAmount, bold: true),
            _moneyRow('ชำระแล้ว', paidAmount, color: Colors.green),
            _moneyRow('คงเหลือ', remaining,
                bold: true, color: Colors.redAccent),

            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text((s['payment_date'] ?? '').toString().split('T').first),
                if ((s['payment_time'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text((s['payment_time'] ?? '').toString()),
                ]
              ],
            ),
            if ((s['tenant_notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('หมายเหตุผู้เช่า: ${s['tenant_notes']}'),
            ],
          ],
        ),
      ),
    );
  }

  // แถว key:value แบบกะทัดรัด
  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // แถวแสดงจำนวนเงิน พร้อมตัวเลือกเน้นสี/ตัวหนา
  Widget _moneyRow(String label, double amount,
      {bool bold = false, bool emphasis = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color ?? (emphasis ? AppTheme.primary : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${amount.toStringAsFixed(2)} บาท', style: style),
        ],
      ),
    );
  }

  // แสดง thumbnail ของสลิปใน Header (กดเพื่อเปิดเต็ม)
  Widget _buildInlineSlipThumbnails() {
    final files = _asListOfMap(_slip?['files']);
    final hasAny = files.isNotEmpty ||
        ((_slip?['slip_image'] ?? '').toString().isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('หลักฐานการชำระ',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              onPressed: _openSlip,
              icon: const Icon(Icons.open_in_new),
              tooltip: 'เปิดในเบราว์เซอร์',
            )
          ],
        ),
        const SizedBox(height: 8),
        if (files.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final fu = (files[i]['file_url'] ?? '').toString();
                return GestureDetector(
                  onTap: _openSlip,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(fu,
                        height: 80, width: 80, fit: BoxFit.cover),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: files.length,
            ),
          )
        else
          GestureDetector(
            onTap: _openSlip,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network((_slip?['slip_image'] ?? '').toString(),
                  height: 100, fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }

  Widget _buildInvoiceHeaderCard() {
    final inv = _asMap(_invoice);
    final room = inv['rooms'] ?? {};
    final br = room['branches'] ?? {};
    final tenant = inv['tenants'] ?? {};

    final invoiceNumber = (inv['invoice_number'] ?? '-').toString();
    final invoiceMonth = (inv['invoice_month'] ?? '-').toString();
    final invoiceYear = (inv['invoice_year'] ?? '-').toString();
    final issueDate = (inv['issue_date'] ?? '').toString();
    final dueDate = (inv['due_date'] ?? '').toString();
    final tenantName =
        (inv['tenant_name'] ?? tenant['tenant_fullname'] ?? '-').toString();
    final tenantPhone =
        (inv['tenant_phone'] ?? tenant['tenant_phone'] ?? '-').toString();
    final roomNumber =
        (inv['room_number'] ?? room['room_number'] ?? '-').toString();
    final branchName =
        (inv['branch_name'] ?? br['branch_name'] ?? '-').toString();
    final invoiceStatus = (inv['invoice_status'] ?? '-').toString();

    double rentalAmount = _asDouble(inv['rental_amount']);
    double utilitiesAmount = _asDouble(inv['utilities_amount']);
    double otherCharges = _asDouble(inv['other_charges']);
    double discountAmount = _asDouble(inv['discount_amount']);
    double lateFeeAmount = _asDouble(inv['late_fee_amount']);
    final totalAmount = _asDouble(inv['total_amount']);
    final paidAmount = _asDouble(inv['paid_amount']);
    final double remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

    final utils = _asListOfMap(inv['utilities']);
    final otherLines = _asListOfMap(inv['other_charge_lines']);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '#$invoiceNumber',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // แสดงเฉพาะสถานะสลิปในหน้านี้ หากเปิดด้วย invoice อย่างเดียวจะไม่มีป้ายสถานะ
              ],
            ),
            const Divider(height: 20),
            const Text('รายละเอียดบิล',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _kv('เลขบิล', invoiceNumber),
            _kv('รอบบิลเดือน', '$invoiceMonth/$invoiceYear'),
            _kv('ออกบิลวันที่', _thaiDate(issueDate)),
            _kv('ครบกำหนดชำระ', _thaiDate(dueDate)),
            const SizedBox(height: 8),
            _kv('ผู้เช่า', tenantName),
            _kv('เบอร์', tenantPhone),
            _kv('ห้อง', roomNumber),
            const Divider(height: 24),
            const Text('ค่าใช้จ่าย',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _moneyRow('ค่าเช่า', rentalAmount),
            ...utils.map((u) {
              final name = (u['utility_name'] ?? '').toString();
              final unitPrice = _asDouble(u['unit_price']);
              final usage = _asDouble(u['usage_amount']);
              final total = _asDouble(u['total_amount']);
              final readingId = (u['reading_id'] ?? '').toString();
              double? prev;
              double? curr;
              if (readingId.isNotEmpty && _readingById.containsKey(readingId)) {
                final r = _readingById[readingId]!;
                if (name.contains('น้ำ')) {
                  prev = _asDouble(r['water_previous_reading']);
                  curr = _asDouble(r['water_current_reading']);
                } else if (name.contains('ไฟ')) {
                  prev = _asDouble(r['electric_previous_reading']);
                  curr = _asDouble(r['electric_current_reading']);
                }
              }
              final parts = <String>[];
              if (prev != null && curr != null) {
                parts.add(
                    '${prev.toStringAsFixed(2)} - ${curr.toStringAsFixed(2)} = ${usage.toStringAsFixed(2)}');
              } else {
                parts.add(usage.toStringAsFixed(2));
              }
              if (unitPrice > 0) {
                parts.add(unitPrice.toStringAsFixed(2));
              }
              final sub = parts.join(' • ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _moneyRow(name, total),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              );
            }).toList(),
            if (otherLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('ค่าใช้จ่ายอื่นๆ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...otherLines.map((o) {
                final title = (o['charge_name'] ?? '').toString();
                final amt = _asDouble(o['charge_amount']);
                final desc = (o['charge_desc'] ?? '').toString();
                final label = desc.isNotEmpty ? '$title ($desc)' : title;
                return _moneyRow(label, amt);
              }).toList(),
            ],
            if (discountAmount > 0)
              _moneyRow('ส่วนลด', -discountAmount, emphasis: true),
            if (lateFeeAmount > 0)
              _moneyRow('ค่าปรับล่าช้า', lateFeeAmount, emphasis: true),
            const Divider(height: 24),
            _moneyRow('ยอดรวม', totalAmount, bold: true),
            _moneyRow('ชำระแล้ว', paidAmount, color: Colors.green),
            _moneyRow('คงเหลือ', remaining,
                bold: true, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('ยังไม่มีสลิปการชำระเงินสำหรับบิลนี้',
                style: TextStyle(color: Colors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipFiles() {
    final files = _asListOfMap(_slip?['files']);
    final hasAny = files.isNotEmpty ||
        ((_slip?['slip_image'] ?? '').toString().isNotEmpty);
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('สลิปที่อัปโหลด',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed: _openSlip,
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'เปิดในเบราว์เซอร์',
                )
              ],
            ),
            const SizedBox(height: 8),
            if (!hasAny)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(child: Text('ไม่มีรูปสลิป')),
              )
            else ...[
              if (files.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: files.map((f) {
                    final fu = (f['file_url'] ?? '').toString();
                    if (fu.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () async {
                        final uri = Uri.tryParse(fu);
                        if (uri != null) {
                          final ok = fnd.kIsWeb
                              ? await launchUrl(uri,
                                  webOnlyWindowName: '_blank')
                              : await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('เปิดลิงก์ไม่สำเร็จ')),
                            );
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fu,
                          height: 160,
                          width: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else ...[
                // Fallback to legacy single slip_image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    (_slip?['slip_image'] ?? '').toString(),
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              ]
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final inv = _slip?['invoices'] ?? {};
    final invoiceStatus =
        (_slip?['invoice_status'] ?? inv['invoice_status'] ?? 'pending')
            .toString();
    final isVerified = (_slip?['payment_id'] != null &&
        _slip!['payment_id'].toString().isNotEmpty);
    final isRejected = (!isVerified &&
        (_slip?['rejection_reason'] != null ||
            (_slip?['verified_at'] != null &&
                _slip!['verified_at'].toString().isNotEmpty)));
    final slipPending = !isVerified &&
        !isRejected; // = ยังไม่มี payment และยังไม่มี verified_at
    final canAction =
        slipPending && invoiceStatus != 'paid' && invoiceStatus != 'cancelled';
    String? bannerText;
    if (!slipPending) {
      bannerText = isVerified
          ? 'สลิปนี้อนุมัติแล้ว ไม่สามารถดำเนินการซ้ำได้'
          : 'สลิปนี้ถูกปฏิเสธแล้ว ผู้เช่าสามารถส่งใหม่ได้';
    } else if (invoiceStatus == 'paid' || invoiceStatus == 'cancelled') {
      bannerText = invoiceStatus == 'paid'
          ? 'บิลนี้ชำระแล้ว ไม่สามารถดำเนินการได้'
          : 'บิลนี้ถูกยกเลิกแล้ว ไม่สามารถดำเนินการได้';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bannerText != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerText,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAction ? _reject : null,
                icon: const Icon(Icons.close, color: Colors.red),
                label:
                    const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canAction ? _approve : null,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('อนุมัติ',
                    style: TextStyle(color: Colors.white)),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ยกเลิกป้ายสถานะบิล: ในหน้านี้แสดงเฉพาะสถานะของสลิป

  // ป้ายสถานะของสลิป (pending/approved/rejected)
  Widget _slipStatusChip(Map<String, dynamic>? slip) {
    final isVerified = (slip?['payment_id'] != null &&
        slip!['payment_id'].toString().isNotEmpty);
    final isRejected = (!isVerified &&
        (slip?['rejection_reason'] != null ||
            (slip?['verified_at'] != null &&
                slip!['verified_at'].toString().isNotEmpty)));
    Color c;
    String t;
    if (isVerified) {
      c = const Color(0xFF22C55E);
      t = 'สลิป: อนุมัติแล้ว';
    } else if (isRejected) {
      c = const Color(0xFFEF4444);
      t = 'สลิป: ถูกปฏิเสธ';
    } else {
      c = const Color(0xFF3B82F6);
      t = 'สลิป: รอตรวจสอบ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
