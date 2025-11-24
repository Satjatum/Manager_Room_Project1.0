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
      var inv = await InvoiceService.getInvoiceById(widget.invoiceId);
      // Hybrid: รีคอมพิวต์ค่าปรับล่าช้า ก่อนกรอกจำนวนเงินเริ่มต้น
      try {
        final changed =
            await InvoiceService.recomputeLateFeeFromSettings(widget.invoiceId);
        if (changed) {
          inv = await InvoiceService.getInvoiceById(widget.invoiceId);
        }
      } catch (_) {}
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
          .where((e) => (e['promptpay_id'] == null ||
              e['promptpay_id'].toString().isEmpty))
          .toList();

      setState(() {
        _invoice = inv;
        _bankAccounts = banks;
        _selectedQrId =
            banks.isNotEmpty ? banks.first['qr_id']?.toString() : null;
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
    if (kIsWeb) {
      await _pickSlipsWeb();
    } else {
      await _pickSlipsMobile();
    }
  }

  Future<void> _pickSlipsWeb() async {
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

  Future<void> _pickSlipsMobile() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'เลือกภาพสลิป',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                Navigator.pop(context, ImageSource.camera),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.camera_alt,
                                      size: 40, color: AppTheme.primary),
                                  SizedBox(height: 8),
                                  Text('กล้อง',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                Navigator.pop(context, ImageSource.gallery),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.photo_library,
                                      size: 40, color: AppTheme.primary),
                                  SizedBox(height: 8),
                                  Text('แกลเลอรี่',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('ยกเลิก',
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        // For gallery, allow multiple selection
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
      } else {
        // For camera, allow single image
        if (_slipFiles.length >= _maxFiles) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('แนบรูปได้ไม่เกิน $_maxFiles รูปต่อบิล')),
            );
          }
          return;
        }
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 2000,
          maxHeight: 2000,
        );
        if (image != null) {
          setState(() => _slipFiles.add(image));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เลือกภาพไม่สำเร็จ: $e')));
    }
  }

  void _removeSlip(int index) {
    setState(() => _slipFiles.removeAt(index));
  }

  Future<void> _pickTimeBottomSheet() async {
    int h = _selectedTime?.hour ?? TimeOfDay.now().hour;
    int m = _selectedTime?.minute ?? TimeOfDay.now().minute;
    final hours = List<int>.generate(24, (i) => i);
    final minutes = List<int>.generate(60, (i) => i);
    final hourCtrl = FixedExtentScrollController(initialItem: h);
    final minCtrl =
        FixedExtentScrollController(initialItem: minutes.indexOf(m));
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('เลือกเวลา',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ตกลง'),
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: hourCtrl,
                          itemExtent: 40,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => h = i,
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: hours.length,
                            builder: (_, i) => Center(
                              child: Text(hours[i].toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                        ),
                      ),
                      const Text(':', style: TextStyle(fontSize: 18)),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: minCtrl,
                          itemExtent: 40,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => m = minutes[i],
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: minutes.length,
                            builder: (_, i) => Center(
                              child: Text(minutes[i].toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (res == true) {
      setState(() => _selectedTime = TimeOfDay(hour: h, minute: m));
    }
  }

  Future<void> _submit() async {
    if (_invoice == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกวันที่และเวลาในการชำระ')));
      return;
    }
    if (_slipFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาอัปโหลดรูปสลิปอย่างน้อย 1 รูป')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // Pre-check resubmission rule (Option C) to avoid uploading files unnecessarily
      try {
        final latest = await PaymentService.getLatestSlipForInvoice(
          widget.invoiceId,
          tenantId: (_invoice!['tenant_id'] ?? '').toString(),
        );
        final paymentId = (latest?['payment_id'] ?? '').toString();
        final verifiedAt = (latest?['verified_at'] ?? '').toString();
        if (paymentId.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('บิลนี้มีสลิปที่อนุมัติแล้ว ไม่สามารถส่งซ้ำได้')));
          }
          return;
        }
        if (latest != null && verifiedAt.isEmpty && paymentId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('มีสลิปรอตรวจสอบอยู่ กรุณารอผลก่อนส่งใหม่')));
          }
          return;
        }
      } catch (_) {}

      // Upload all images first
      final urls = <String>[];
      for (final f in _slipFiles) {
        late Map<String, dynamic> up;
        if (kIsWeb) {
          final bytes = await f.readAsBytes();
          up = await ImageService.uploadImageFromBytes(
            bytes,
            f.name,
            'payment-slips',
            folder: widget.invoiceId,
            prefix: 'slip',
            context: 'invoice_${widget.invoiceId}',
          );
        } else {
          up = await ImageService.uploadImage(
            File(f.path),
            'payment-slips',
            folder: widget.invoiceId,
            prefix: 'slip',
            context: 'invoice_${widget.invoiceId}',
          );
        }
        if (up['success'] == true && (up['url'] ?? '').toString().isNotEmpty) {
          urls.add(up['url']);
        } else {
          throw up['message'] ?? 'อัปโหลดรูปไม่สำเร็จ';
        }
      }

      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Create slip with first image
      final res = await PaymentService.submitPaymentSlip(
        invoiceId: widget.invoiceId,
        tenantId: _invoice!['tenant_id'],
        qrId: _selectedQrId,
        paidAmount: amount,
        paymentDateTime: dt,
        slipImageUrl: urls.first,
        tenantNotes:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'ส่งสลิปไม่สำเร็จ')));
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
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('QrCode',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SizedBox(
                      width: 240,
                      height: 240,
                      child:
                          QrImageView(data: accNum, version: QrVersions.auto)),
                ),
                const SizedBox(height: 8),
                Text('$bankName • $accNum',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
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
                            child: _buildBankDropdownWithQrButton(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'รายละเอียดการชำระ',
                            icon: Icons.payments_outlined,
                            child: _buildPaymentDetails(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'อัปโหลดสลิป (สูงสุด $_maxFiles รูป)',
                            icon: Icons.upload_file_outlined,
                            child: _buildSlipUploader(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'หมายเหตุ',
                            icon: Icons.sticky_note_2_outlined,
                            child: _buildNoteBox(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
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
                  'บิลค่าเช่า',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ดูและจัดการบิลค่าเช่าของคุณ',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
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
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // Dropdown + QR button (popup)
  Widget _buildBankDropdownWithQrButton() {
    if (_bankAccounts.isEmpty) {
      return const Text('ยังไม่มีบัญชีธนาคารให้เลือก');
    }
    final items = _bankAccounts.map((q) {
      final id = (q['qr_id'] ?? '').toString();
      final title = "${q['bank_name'] ?? ''} • ${q['account_number'] ?? ''}";
      return DropdownMenuItem<String>(
        value: id,
        child: Text(title, overflow: TextOverflow.ellipsis),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: (_selectedQrId != null && _selectedQrId!.isNotEmpty)
              ? _selectedQrId
              : null,
          items: items,
          dropdownColor: Colors.white,
          onChanged: (v) {
            if (v == null || v.isEmpty) return;
            setState(() => _selectedQrId = v);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(Icons.account_balance),
            hintText: 'เลือกบัญชีธนาคาร',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _selectedQrId == null ? null : _showQrDialog,
            label: const Text(
              'แสดง QR',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
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
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.payments),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
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
                onPressed: () async {
                  final now = DateTime.now();

                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppTheme.primary, // สีไฮไลต์วันที่เลือก
                            onPrimary: Colors.white, // สีตัวอักษรบนวันที่เลือก
                            onSurface: Colors.black, // สีตัวอักษรปกติ
                          ),
                          dialogBackgroundColor:
                              Colors.white, // สีพื้นหลัง dialog
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, color: Colors.grey),
                label: Text(
                  _selectedDate == null
                      ? 'เลือกวันที่'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                  style: TextStyle(color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTimeBottomSheet,
                icon: const Icon(Icons.schedule, color: Colors.grey),
                label: Text(
                  _selectedTime == null
                      ? 'เลือกเวลา'
                      : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _slipFiles.length >= _maxFiles ? null : _pickSlips,
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: Colors.grey),
            label: Text(
              _slipFiles.isEmpty
                  ? 'เลือกภาพสลิป'
                  : 'เพิ่มภาพ (เหลือ ${_maxFiles - _slipFiles.length})',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_slipFiles.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _slipFiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (ctx, i) {
              final f = _slipFiles[i];
              Widget img;
              if (kIsWeb) {
                img = FutureBuilder(
                  future: f.readAsBytes(),
                  builder: (ctx, snap) {
                    if (snap.hasData) {
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    }
                    return const SizedBox.shrink();
                  },
                );
              } else {
                img = Image.file(File(f.path), fit: BoxFit.cover);
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: () => _removeSlip(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildNoteBox() {
    return TextField(
      controller: _noteCtrl,
      maxLines: 3,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSubmitButton() {
    final amountOk = (double.tryParse(_amountCtrl.text) ?? 0) > 0;
    final isValid = amountOk &&
        _selectedDate != null &&
        _selectedTime != null &&
        _slipFiles.isNotEmpty &&
        _selectedQrId != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_submitting || !isValid) ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.upload, color: Colors.white),
            label: Text(
              _submitting ? 'กำลังส่ง...' : 'ส่งสลิปเพื่อรอตรวจสอบ',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
