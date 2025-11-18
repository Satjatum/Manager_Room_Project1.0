import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/image_service.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TenantPayBillUi extends StatefulWidget {
  final String invoiceId;
  const TenantPayBillUi({super.key, required this.invoiceId});

  @override
  State<TenantPayBillUi> createState() => _TenantPayBillUiState();
}

class _TenantPayBillUiState extends State<TenantPayBillUi> {
  bool _loading = true;
  bool _submitting = false;

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _bankAccounts = [];
  String? _selectedQrId; // branch_payment_qr.qr_id (bank only)

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final List<XFile> _slipFiles = [];
  static const int _maxFiles = 5;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final inv = await InvoiceService.getInvoiceById(widget.invoiceId);
      if (inv == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ไม่พบบิล')));
        Navigator.pop(context);
        return;
      }

      final total = _asDouble(inv['total_amount']);
      final paid = _asDouble(inv['paid_amount']);
      final remain = (total - paid);
      _amountCtrl.text = remain > 0 ? remain.toStringAsFixed(2) : '0.00';

      // Load branch bank accounts only
      final branchId = inv['rooms']?['branch_id'];
      List<Map<String, dynamic>> qrs = [];
      if (branchId != null && branchId.toString().isNotEmpty) {
        qrs = await PaymentService.getBranchQRCodes(branchId);
      }
      final banks = qrs
          .where((e) => (e['promptpay_id'] == null || e['promptpay_id'].toString().isEmpty))
          .toList();

      setState(() {
        _invoice = inv;
        _bankAccounts = banks;
        _selectedQrId = banks.isNotEmpty ? banks.first['qr_id']?.toString() : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _pickSlips() async {
    final picker = ImagePicker();
    try {
      final List<XFile> files = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (files.isEmpty) return;
      if (_slipFiles.length + files.length > _maxFiles) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('แนบรูปได้ไม่เกิน $_maxFiles รูปต่อบิล')),
          );
        }
      }
      final space = _maxFiles - _slipFiles.length;
      setState(() => _slipFiles.addAll(files.take(space)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เลือกภาพไม่สำเร็จ: $e')));
    }
  }

  void _removeSlip(int index) {
    setState(() => _slipFiles.removeAt(index));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTimeBottomSheet() async {
    final now = TimeOfDay.now();
    int h = _selectedTime?.hour ?? now.hour;
    int m = _selectedTime?.minute ?? (now.minute - (now.minute % 5));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('เลือกเวลา',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ตกลง'),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: FixedExtentScrollController(initialItem: h),
                          onSelectedItemChanged: (v) => h = v,
                          itemExtent: 36,
                          physics: const FixedExtentScrollPhysics(),
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (c, i) => i == null || i < 0 || i > 23
                                ? null
                                : Center(child: Text(i.toString().padLeft(2, '0'))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: FixedExtentScrollController(initialItem: (m / 5).round()),
                          onSelectedItemChanged: (v) => m = v * 5,
                          itemExtent: 36,
                          physics: const FixedExtentScrollPhysics(),
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (c, i) => i == null || i < 0 || i > 11
                                ? null
                                : Center(child: Text((i * 5).toString().padLeft(2, '0'))),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
    if (ok == true) setState(() => _selectedTime = TimeOfDay(hour: h, minute: m));
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกวันที่และเวลาในการชำระ')));
      return;
    }
    if (_slipFiles.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาอัปโหลดรูปสลิปอย่างน้อย 1 รูป')));
      return;
    }

    setState(() => _submitting = true);
    try {
      // Upload all slip images first
      final urls = <String>[];
      for (final f in _slipFiles) {
        final up = await ImageService.uploadFile(File(f.path));
        if (up['success'] == true && (up['url'] ?? '').toString().isNotEmpty) {
          urls.add(up['url']);
        } else {
          throw up['message'] ?? 'อัปโหลดรูปไม่สำเร็จ';
        }
      }

      final d = _selectedDate!;
      final t = _selectedTime!;
      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);

      // Create slip with first image
      final res = await PaymentService.submitPaymentSlip(
        invoiceId: widget.invoiceId,
        tenantId: _invoice!['tenant_id'],
        qrId: _selectedQrId,
        paidAmount: amount,
        paymentDateTime: dt,
        slipImageUrl: urls.first,
        tenantNotes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (res['success'] == true) {
        // attach remaining files
        final data = res['data'] as Map<String, dynamic>;
        final slipId = (data['slip_id'] ?? '').toString();
        if (slipId.isNotEmpty && urls.length > 1) {
          for (final url in urls.skip(1)) {
            await PaymentService.addSlipFile(slipId: slipId, fileUrl: url);
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res['message'] ?? 'สำเร็จ')));
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res['message'] ?? 'ส่งสลิปไม่สำเร็จ')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showQrDialog() {
    if (_selectedQrId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชีธนาคาร')));
      return;
    }
    final acct = _bankAccounts.firstWhere(
      (q) => (q['qr_id']?.toString() ?? '') == (_selectedQrId ?? ''),
      orElse: () => {},
    );
    final accNum = (acct['account_number'] ?? '').toString();
    final bankName = (acct['bank_name'] ?? '').toString();
    final accName = (acct['account_name'] ?? '').toString();
    if (accNum.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชีธนาคาร')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('QR สำหรับโอน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: accNum,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 8),
              Text('$bankName • $accNum', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (accName.isNotEmpty)
                Text(accName, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                    const SizedBox(height: 12),
                    const Text('กำลังโหลด...'),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            title: 'เลือกบัญชีธนาคารเพื่อโอน',
                            icon: Icons.account_balance_outlined,
                            child: Column(
                              children: [
                                _buildBankList(),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _selectedQrId == null ? null : _showQrDialog,
                                    icon: const Icon(Icons.qr_code_2_outlined),
                                    label: const Text('แสดง QR'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'รายละเอียดการชำระ',
                            icon: Icons.payments_outlined,
                            child: _buildPaymentDetails(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'อัปโหลดสลิป (ได้หลายรูป สูงสุด $_maxFiles รูป)',
                            icon: Icons.upload_file_outlined,
                            child: _buildSlipUploader(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'หมายเหตุ (ถ้ามี)',
                            icon: Icons.sticky_note_2_outlined,
                            child: _buildNoteBox(),
                          ),
                          const SizedBox(height: 16),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ชำระบิล/อัปโหลดสลิป',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildBankList() {
    if (_bankAccounts.isEmpty) {
      return const Text('ยังไม่มีบัญชีธนาคารให้เลือก');
    }
    return Column(
      children: _bankAccounts.map((q) {
        final id = q['qr_id'].toString();
        final title = '${q['bank_name'] ?? ''} • ${q['account_number'] ?? ''}';
        final sub = (q['account_name'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: RadioListTile<String>(
            value: id,
            groupValue: _selectedQrId,
            onChanged: (v) => setState(() => _selectedQrId = v),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: sub.isEmpty ? null : Text(sub),
            secondary: TextButton.icon(
              onPressed: () async {
                final acc = (q['account_number'] ?? '').toString();
                if (acc.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: acc));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกเลขบัญชีแล้ว')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('คัดลอกเลขบัญชี'),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('จำนวนเงินที่ชำระ',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.payments),
            border: OutlineInputBorder(),
            hintText: 'เช่น 5000.00',
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text('วันที่และเวลา',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _selectedDate == null
                      ? 'เลือกวันที่'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTimeBottomSheet,
                icon: const Icon(Icons.schedule),
                label: Text(
                  _selectedTime == null
                      ? 'เลือกเวลา'
                      : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlipUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _slipFiles.isEmpty
                    ? 'ยังไม่ได้เพิ่มรูป'
                    : 'เลือกรูปแล้ว ${_slipFiles.length} ไฟล์',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _slipFiles.length >= _maxFiles ? null : _pickSlips,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _slipFiles.isEmpty
                    ? 'เลือกภาพสลิป'
                    : 'เพิ่มภาพ (เหลือ ${_maxFiles - _slipFiles.length})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_slipFiles.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _slipFiles.length,
            itemBuilder: (context, index) {
              final f = _slipFiles[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(f.path, fit: BoxFit.cover)
                          : Image.file(File(f.path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeSlip(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  )
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildNoteBox() {
    return TextFormField(
      controller: _noteCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'เช่น โอนผ่านบัญชี xxx เวลา xx:xx น.',
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload),
        label: Text(_submitting ? 'กำลังส่ง...' : 'ส่งสลิปเพื่อรอตรวจสอบ'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}