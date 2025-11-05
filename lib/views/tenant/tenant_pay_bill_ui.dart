import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/image_service.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
// Use app theme via Theme.of(context).colorScheme instead of fixed colors

class TenantPayBillUi extends StatefulWidget {
  final String invoiceId;
  const TenantPayBillUi({super.key, required this.invoiceId});

  @override
  State<TenantPayBillUi> createState() => _TenantPayBillUiState();
}

class _TenantPayBillUiState extends State<TenantPayBillUi> {
  bool _loading = true;
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _branchQrs = [];
  String? _selectedQrId;
  // ประเภทการจ่ายที่เลือกในหน้าเทนแนนท์: bank | promptpay
  String _payType = 'bank';

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  XFile? _slipFile;
  bool _submitting = false;

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

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final inv = await InvoiceService.getInvoiceById(widget.invoiceId);
      if (inv == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบบิล')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final total = _asDouble(inv['total_amount']);
      final paid = _asDouble(inv['paid_amount']);
      final remain = (total - paid);
      _amountCtrl.text = remain > 0 ? remain.toStringAsFixed(2) : '0.00';

      final branchId = inv['rooms']?['branch_id'];
      List<Map<String, dynamic>> qrs = [];
      if (branchId != null && branchId.toString().isNotEmpty) {
        qrs = await PaymentService.getBranchQRCodes(branchId);
      }

      // กำหนดค่าเริ่มต้นการเลือกประเภท/บัญชี:
      // - ถ้ามีบัญชีธนาคาร ให้เริ่มที่ bank ก่อน ไม่งั้นใช้ promptpay
      // - เลือกบัญชีหลัก (is_primary) ของประเภทนั้นก่อน ถ้าไม่มีให้เลือกอันแรกของประเภทนั้น
      String initialType = 'bank';
      final bankList = qrs.where((e) => (e['promptpay_id'] == null || e['promptpay_id'].toString().isEmpty)).toList();
      final ppList = qrs.where((e) => (e['promptpay_id'] != null && e['promptpay_id'].toString().isNotEmpty)).toList();
      if (bankList.isEmpty && ppList.isNotEmpty) initialType = 'promptpay';

      String? initialQrId;
      if (initialType == 'bank') {
        initialQrId = (bankList.firstWhere(
                (e) => (e['is_primary'] ?? false) == true,
                orElse: () => bankList.isNotEmpty ? bankList.first : {})
            ['qr_id']) as String?;
      } else {
        initialQrId = (ppList.firstWhere(
                (e) => (e['is_primary'] ?? false) == true,
                orElse: () => ppList.isNotEmpty ? ppList.first : {})
            ['qr_id']) as String?;
      }

      setState(() {
        _invoice = inv;
        _branchQrs = qrs;
        _payType = initialType;
        _selectedQrId = initialQrId;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSlip() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (file != null) {
      setState(() => _slipFile = file);
    }
  }

  Future<void> _submit() async {
    if (_invoice == null) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่และเวลาในการชำระ')),
      );
      return;
    }
    if (_slipFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาอัปโหลดสลิปการโอนเงิน')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // compose payment datetime from user selection
      final paymentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      Map<String, dynamic> uploadResult;
      if (kIsWeb) {
        final bytes = await _slipFile!.readAsBytes();
        uploadResult = await ImageService.uploadImageFromBytes(
          bytes,
          _slipFile!.name,
          'payment-slips',
          folder: widget.invoiceId,
          prefix: 'slip',
          context: 'invoice_${widget.invoiceId}',
        );
      } else {
        uploadResult = await ImageService.uploadImage(
          File(_slipFile!.path),
          'payment-slips',
          folder: widget.invoiceId,
          prefix: 'slip',
          context: 'invoice_${widget.invoiceId}',
        );
      }

      if (uploadResult['success'] != true) {
        throw uploadResult['message'] ?? 'อัปโหลดสลิปไม่สำเร็จ';
      }

      final result = await PaymentService.submitPaymentSlip(
        invoiceId: widget.invoiceId,
        tenantId: _invoice!['tenant_id'],
        qrId: _selectedQrId,
        paidAmount: amount,
        paymentDateTime: paymentDateTime,
        slipImageUrl: uploadResult['url'],
        tenantNotes:
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'ส่งสลิปสำเร็จ')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'ส่งสลิปไม่สำเร็จ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.primary)),
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
                            title: 'เลือกบัญชี/QR สำหรับโอน',
                            icon: Icons.qr_code_2_outlined,
                            child: _buildQrListContent(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'รายละเอียดการชำระ',
                            icon: Icons.payments_outlined,
                            child: _buildAmountAndDateTimeContent(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'อัปโหลดสลิป (บังคับ)',
                            icon: Icons.upload_file_outlined,
                            child: _buildSlipUploadContent(),
                          ),
                          const SizedBox(height: 12),
                          _buildSection(
                            title: 'หมายเหตุผู้เช่า (ถ้ามี)',
                            icon: Icons.sticky_note_2_outlined,
                            child: _buildNoteContent(),
                          ),
                          const SizedBox(height: 16),
                          _buildSubmitButton(scheme),
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

  // Content builders for sections (no outer container)
  Widget _buildQrListContent() {
    final scheme = Theme.of(context).colorScheme;
    if (_branchQrs.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline, color: scheme.tertiary),
          const SizedBox(width: 8),
          const Expanded(child: Text('ยังไม่มีบัญชี/QR สำหรับสาขานี้')),
        ],
      );
    }

    // แยกตามประเภท: ธนาคาร vs พร้อมเพย์
    final bankList = _branchQrs
        .where((e) => (e['promptpay_id'] == null || e['promptpay_id'].toString().isEmpty))
        .toList();
    final ppList = _branchQrs
        .where((e) => (e['promptpay_id'] != null && e['promptpay_id'].toString().isNotEmpty))
        .toList();

    // อัปเดตการเลือกเริ่มต้นเมื่อสลับประเภท หาก _selectedQrId ไม่อยู่ในประเภทปัจจุบัน
    List<Map<String, dynamic>> currentList = _payType == 'bank' ? bankList : ppList;
    if (currentList.isNotEmpty &&
        (currentList.every((e) => e['qr_id'].toString() != (_selectedQrId ?? '')))) {
      final initId = (currentList.firstWhere(
              (e) => (e['is_primary'] ?? false) == true,
              orElse: () => currentList.first))['qr_id']
          .toString();
      _selectedQrId = initId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ปุ่มเลือกประเภทการชำระ
        Row(
          children: [
            ChoiceChip(
              label: const Text('โอนผ่านธนาคาร'),
              selected: _payType == 'bank',
              onSelected: (s) {
                if (!s) return;
                setState(() => _payType = 'bank');
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('PromptPay'),
              selected: _payType == 'promptpay',
              onSelected: (s) {
                if (!s) return;
                setState(() => _payType = 'promptpay');
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_payType == 'bank' && bankList.isEmpty)
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.tertiary),
              const SizedBox(width: 8),
              const Expanded(child: Text('ยังไม่มีบัญชีธนาคารให้เลือก')),
            ],
          ),
        if (_payType == 'promptpay' && ppList.isEmpty)
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.tertiary),
              const SizedBox(width: 8),
              const Expanded(child: Text('ยังไม่มี PromptPay ให้เลือก')),
            ],
          ),

        ...currentList.map((q) {
          final id = q['qr_id'].toString();
          final image = (q['qr_code_image'] ?? '').toString();
          final isPrimary = (q['is_primary'] ?? false) == true;
          final isPromptPay =
              (q['promptpay_id'] != null && q['promptpay_id'].toString().isNotEmpty);

          // แสดงหัวเรื่องแตกต่างกันตามประเภท
          final title = isPromptPay
              ? 'PromptPay • ${q['promptpay_id'] ?? ''}'
              : '${q['bank_name'] ?? ''} • ${q['account_number'] ?? ''}';
          final sub1 = isPromptPay
              ? 'ประเภท: ${q['promptpay_type'] ?? '-'}'
              : (q['account_name'] ?? '');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: _selectedQrId == id ? scheme.primary : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RadioListTile<String>(
              value: id,
              groupValue: _selectedQrId,
              onChanged: (v) => setState(() => _selectedQrId = v),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sub1.toString().isNotEmpty) Text(sub1.toString()),
                  if (isPrimary)
                    Text('บัญชีหลัก',
                        style: TextStyle(color: scheme.secondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAmountAndDateTimeContent() {
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
            fillColor: Colors.white, // TextField สีขาว
          ),
        ),
        const SizedBox(height: 16),
        const Text('วันที่ชำระ', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? 'เลือกวันที่'
                    : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white, // Button สีขาว
                side: BorderSide(color: Colors.grey[300]!), // ขอบเทา
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _selectedTime = picked);
              },
              icon: const Icon(Icons.schedule),
              label: Text(
                _selectedTime == null
                    ? 'เลือกเวลา'
                    : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white, // Button สีขาว
                side: BorderSide(color: Colors.grey[300]!), // ขอบเทา
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildSlipUploadContent() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        if (_slipFile == null)
          SizedBox(
            width: double.infinity, // ปุ่มเลือกสลิปเต็มความกว้าง
            child: OutlinedButton.icon(
              onPressed: _pickSlip,
              icon: const Icon(Icons.upload_file),
              label: const Text('เลือกไฟล์สลิป'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white, // Button สีขาว
                side: BorderSide(color: Colors.grey[300]!), // ขอบเทา
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kIsWeb)
                FutureBuilder(
                  future: _slipFile!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          snapshot.data!,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_slipFile!.path),
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickSlip,
                    icon: const Icon(Icons.refresh),
                    label: const Text('เปลี่ยนรูป'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _slipFile = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      foregroundColor: scheme.error,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                    ),
                  ),
                ],
              )
            ],
          ),
      ],
    );
  }

  Widget _buildNoteContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'เช่น โอนผ่านบัญชี xxx เวลา xx:xx น.',
            filled: true,
            fillColor: Colors.white, // TextField สีขาว
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ColorScheme scheme) {
    final isValid = (_slipFile != null) &&
        (_selectedDate != null) &&
        (_selectedTime != null) &&
        ((double.tryParse(_amountCtrl.text) ?? 0) > 0);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: (_submitting || !isValid) ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                ),
              )
            : const Icon(Icons.upload),
        label: const Text('ส่งสลิปเพื่อรอตรวจสอบ'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white, // Button สีขาว
          side: BorderSide(color: Colors.grey[300]!), // ขอบเทา
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
