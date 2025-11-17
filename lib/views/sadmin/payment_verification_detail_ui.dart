import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as fnd;
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:manager_room_project/services/invoice_service.dart';

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.slipId != null) {
        final res = await PaymentService.getSlipById(widget.slipId!);
        setState(() {
          _slip = res;
          _loading = false;
        });
      } else if (widget.invoiceId != null) {
        final inv = await InvoiceService.getInvoiceById(widget.invoiceId!);
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

  Future<void> _openSlip() async {
    final urlStr = (_slip?['slip_image'] ?? '').toString();
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

    try {
      setState(() => _loading = true);
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
            hintText: 'ระบุเหตุผล',
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
        reason: reasonCtrl.text.trim(),
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
      appBar: AppBar(
        title: Text(widget.slipId != null
            ? 'รายละเอียดสลิปชำระเงิน'
            : 'รายละเอียดใบแจ้งหนี้'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.slipId != null)
            IconButton(
              onPressed: _openSlip,
              icon: const Icon(Icons.download),
              tooltip: 'เปิด/ดาวน์โหลดสลิป',
            )
        ],
      ),
      body: _loading
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
                            _buildSlipImage(),
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
    );
  }

  Widget _buildHeaderCard() {
    final s = _slip!;
    final inv = s['invoices'] ?? {};
    final room = inv.isNotEmpty ? (inv['rooms'] ?? {}) : {};
    final br = room.isNotEmpty ? (room['branches'] ?? {}) : {};
    final tenant = inv.isNotEmpty ? (inv['tenants'] ?? {}) : {};

    // ฟิลด์แบบ flat (กรณี PromptPay pseudo)
    final invoiceNumber = (s['invoice_number'] ?? inv['invoice_number'] ?? '-').toString();
    final tenantName = (s['tenant_name'] ?? tenant['tenant_fullname'] ?? '-').toString();
    final tenantPhone = (s['tenant_phone'] ?? tenant['tenant_phone'] ?? '-').toString();
    final roomNumber = (s['room_number'] ?? room['room_number'] ?? '-').toString();
    final branchName = (s['branch_name'] ?? br['branch_name'] ?? '-').toString();
    final invoiceStatus = (inv['invoice_status'] ?? '-').toString();
    final slipStatus = (s['slip_status'] ?? 'pending').toString();

    return Card(
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
                    invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _invoiceStatusChip(invoiceStatus),
                const SizedBox(width: 6),
                _slipStatusChip(slipStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text('ผู้เช่า: $tenantName'),
            Text('เบอร์: $tenantPhone'),
            Text('ห้อง: $roomNumber'),
            Text('สาขา: $branchName'),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.payments, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  '${_asDouble(s['paid_amount']).toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const Spacer(),
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

  Widget _buildInvoiceHeaderCard() {
    final inv = _invoice!;
    final room = inv['rooms'] ?? {};
    final br = room['branches'] ?? {};
    final tenant = inv['tenants'] ?? {};

    final invoiceNumber = (inv['invoice_number'] ?? '-').toString();
    final tenantName = (inv['tenant_name'] ?? tenant['tenant_fullname'] ?? '-').toString();
    final tenantPhone = (inv['tenant_phone'] ?? tenant['tenant_phone'] ?? '-').toString();
    final roomNumber = (inv['room_number'] ?? room['room_number'] ?? '-').toString();
    final branchName = (inv['branch_name'] ?? br['branch_name'] ?? '-').toString();
    final roomcate = (inv['roomcate_name'] ?? room['room_categories']?['roomcate_name'] ?? '-').toString();
    final invoiceStatus = (inv['invoice_status'] ?? '-').toString();
    final total = _asDouble(inv['total_amount']);
    final dueDate = (inv['due_date'] ?? '').toString();

    return Card(
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
                    invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _invoiceStatusChip(invoiceStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text('ผู้เช่า: $tenantName'),
            Text('เบอร์: $tenantPhone'),
            Text('$roomcate เลขที่ $roomNumber'),
            Text('สาขา: $branchName'),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.payments, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  '${total.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text(dueDate.toString().split('T').first),
              ],
            ),
            const SizedBox(height: 8),
            const Text('ยังไม่มีสลิปการชำระเงินสำหรับบิลนี้',
                style: TextStyle(color: Colors.orange)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipImage() {
    final url = (_slip?['slip_image'] ?? '').toString();
    return Card(
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
            if (url.isEmpty)
              Container(
                height: 220,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('ไม่มีรูปสลิป')),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final status = (_slip?['slip_status'] ?? 'pending').toString();
    final canAction = status == 'pending';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canAction ? _reject : null,
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canAction ? _approve : null,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('อนุมัติ', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  // ป้ายสถานะของบิลตาม Database
  Widget _invoiceStatusChip(String status) {
    Color c;
    String t;
    switch (status) {
      case 'paid':
        c = const Color(0xFF22C55E);
        t = 'ชำระแล้ว';
        break;
      case 'overdue':
        c = const Color(0xFFEF4444);
        t = 'เกินกำหนด';
        break;
      case 'partial':
        c = const Color(0xFFF59E0B);
        t = 'ชำระบางส่วน';
        break;
      case 'cancelled':
        c = Colors.grey;
        t = 'ยกเลิก';
        break;
      case 'pending':
      default:
        c = const Color(0xFF3B82F6);
        t = 'รอดำเนินการ';
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

  // ป้ายสถานะของสลิป (pending/verified/rejected)
  Widget _slipStatusChip(String status) {
    Color c;
    String t;
    switch (status) {
      case 'verified':
        c = Colors.green;
        t = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        c = Colors.red;
        t = 'ถูกปฏิเสธ';
        break;
      default:
        c = Colors.orange;
        t = 'รอตรวจสอบ';
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
