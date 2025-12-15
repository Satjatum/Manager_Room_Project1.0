import 'package:flutter/material.dart';
// Services //
import '../../services/invoice_service.dart';
import '../../services/meter_service.dart';
import '../../services/payment_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';
// Utils //
import '../../utils/formatMonthy.dart';

class PaymentVerificationDetailUi extends StatefulWidget {
  final String? slipId;
  final String? invoiceId;
  const PaymentVerificationDetailUi({
    super.key,
    this.slipId,
    this.invoiceId,
  }) : assert(slipId != null || invoiceId != null,
            'ต้องระบุ slipId หรือ invoiceId อย่างน้อยหนึ่งค่า');

  @override
  State<PaymentVerificationDetailUi> createState() =>
      _PaymentVerificationDetailUiState();
}

class _PaymentVerificationDetailUiState
    extends State<PaymentVerificationDetailUi> {
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
          out.add(Map<String, dynamic>.from(e));
        }
      }
      return out;
    }
    return const [];
  }

  // Safe conversion: dynamic -> Map<String, dynamic>
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    if (v is List && v.isNotEmpty && v.first is Map) {
      return Map<String, dynamic>.from(v.first as Map);
    }
    return <String, dynamic>{};
  }

  String _thaiDate(String s) => Formatmonthy.formatThaiDateStr(s);

  String _formatBillingCycle(String monthStr, String yearStr) {
    final m = int.tryParse(monthStr);
    final y = int.tryParse(yearStr);
    if (m == null || y == null || m < 1 || m > 12) {
      return '$monthStr/$yearStr';
    }
    return Formatmonthy.formatBillingCycleTh(month: m, year: y);
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
        debugPrint('เกิดข้อผิดพลาดในการโหลดรายละเอียด: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดรายละเอียด');
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
                Icons.check_outlined,
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
                    'อนุมัติสลิปชำระเงิน',
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
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'จำนวนเงิน',
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
                  controller: noteCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ (ถ้ามี)',
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
                )
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ABC9C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'ยืนยัน',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) {
      debugPrint('จำนวนเงินไม่ถูกต้อง');
      SnackMessage.showError(context, 'จำนวนเงินไม่ถูกต้อง');
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
      debugPrint(
          'จำนวนเงินที่อนุมัติ (${amount.toStringAsFixed(2)}) ไม่สามารถเกินยอดคงเหลือ (${remaining.toStringAsFixed(2)}) ได้');
      SnackMessage.showError(context,
          'จำนวนเงินที่อนุมัติ (${amount.toStringAsFixed(2)}) ไม่สามารถเกินยอดคงเหลือ (${remaining.toStringAsFixed(2)}) ได้');

      return;
    }

    try {
      setState(() => _loading = true);
      // applyEarlyDiscountFromSettings() removed - Discount system disabled
      final result = await PaymentService.verifySlip(
        slipId: _slip!['slip_id'],
        approvedAmount: amount,
        paymentMethod: 'transfer',
        adminNotes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (mounted) {
        debugPrint(result['message'] ?? 'อนุมัติสำเร็จ');
        SnackMessage.showSuccess(context, 'อนุมัติสำเร็จ');
      }
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        debugPrint('อนุมัติไม่สำเร็จ: $e');
        SnackMessage.showError(context, 'อนุมัติไม่สำเร็จ');
      }
    }
  }

  Future<void> _reject() async {
    if (_slip == null) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ยืนยันการปฏิเสธสลิปชำระเงิน',
                    style: const TextStyle(
                      color: Colors.red,
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
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'ระบุเหตุผล',
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
            )),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'ปฏิเสธ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
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
        debugPrint(result['message'] ?? 'ปฏิเสธสำเร็จ');
        SnackMessage.showSuccess(context, 'ปฏิเสธสำเร็จ');
      }
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        debugPrint('ปฏิเสธไม่สำเร็จ: $e');
        SnackMessage.showError(context, 'ปฏิเสธไม่สำเร็จ');
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
                          'รายละเอียดสลิปชำระเงิน',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ตรวจสอบและติดตามสถานะการชำระ',
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    if (widget.slipId == null || _slip == null) return const SizedBox.shrink();
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
    final slipPending = !isVerified && !isRejected;
    final canAction =
        slipPending && invoiceStatus != 'paid' && invoiceStatus != 'cancelled';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canAction ? _reject : null,
              label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canAction ? _approve : null,
              label:
                  const Text('อนุมัติ', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showZoomViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final s = _slip!;
    final invFull = _asMap(_invoice ?? s['invoices']);
    final room = invFull.isNotEmpty ? (invFull['rooms'] ?? {}) : {};
    final tenant = invFull.isNotEmpty ? (invFull['tenants'] ?? {}) : {};

    // ฟิลด์แบบ flat (เผื่อโครงสร้างบางส่วนไม่ครบ)
    final invoiceNumber =
        (invFull['invoice_number'] ?? s['invoice_number'] ?? '-').toString();
    final invoiceMonthStr = (invFull['invoice_month'] ?? '-').toString();
    final invoiceYearStr = (invFull['invoice_year'] ?? '-').toString();
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
            const Divider(height: 20),
            // รายละเอียด #หัวเรื่อง
            const Text('รายละเอียดบิล',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _kv('เลขบิล', invoiceNumber),
            _kv('รอบบิลเดือน',
                _formatBillingCycle(invoiceMonthStr, invoiceYearStr)),
            _kv('ออกบิลวันที่', _thaiDate(issueDate)),
            _kv('ครบกำหนดชำระ', _thaiDate(dueDate)),
            // const SizedBox(height: 8),

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
              String sub = '';
              if (prev != null && curr != null) {
                sub = Formatmonthy.formatUtilitySubtext(
                  previous: prev,
                  current: curr,
                  usage: usage,
                  unitPrice: unitPrice,
                );
              } else if (usage > 0 || unitPrice > 0) {
                sub =
                    '${usage.toStringAsFixed(2)} (${unitPrice.toStringAsFixed(2)})';
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _moneyRow(name, total),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
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
            const Divider(height: 24),
            if (discountAmount > 0)
              _moneyRow('ส่วนลด', discountAmount, emphasis: true),
            _moneyRow('ค่าปรับล่าช้า', lateFeeAmount, emphasis: true),
            _moneyRow('ยอดรวม', totalAmount, bold: true),
            _moneyRow('ชำระแล้ว', paidAmount, color: Colors.green),
            _moneyRow('คงเหลือ', remaining,
                bold: true, color: Colors.redAccent),

            const SizedBox(height: 12),
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
      color: color ?? (emphasis ? Colors.black : null),
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
            const Text('สลิปที่อัปโหลด',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
                      onTap: () => _showZoomViewer(fu),
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
                GestureDetector(
                  onTap: () {
                    final url = (_slip?['slip_image'] ?? '').toString();
                    if (url.isNotEmpty) _showZoomViewer(url);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      (_slip?['slip_image'] ?? '').toString(),
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ]
            ],
          ],
        ),
      ),
    );
  }

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
      t = 'อนุมัติแล้ว';
    } else if (isRejected) {
      c = const Color(0xFFEF4444);
      t = 'ถูกปฏิเสธ';
    } else {
      c = const Color(0xFF3B82F6);
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
