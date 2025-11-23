import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../../services/contract_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ContractEditUI extends StatefulWidget {
  final String contractId;

  const ContractEditUI({
    Key? key,
    required this.contractId,
  }) : super(key: key);

  @override
  State<ContractEditUI> createState() => _ContractEditUIState();
}

class _ContractEditUIState extends State<ContractEditUI> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _contract;
  DateTime? _startDate;
  DateTime? _endDate;
  int _paymentDay = 1;
  bool _contractPaid = false;

  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _noteController = TextEditingController();

  // Document upload
  String? _documentPath;
  String? _documentName;
  Uint8List? _documentBytes;
  String? _currentDocumentUrl;
  bool _documentChanged = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contract = await ContractService.getContractById(widget.contractId);

      if (contract != null && mounted) {
        setState(() {
          _contract = contract;
          if (contract['start_date'] != null) {
            _startDate = DateTime.parse(contract['start_date']);
          }
          if (contract['end_date'] != null) {
            _endDate = DateTime.parse(contract['end_date']);
          }
          _paymentDay = (contract['payment_day'] is int)
              ? contract['payment_day'] as int
              : int.tryParse(contract['payment_day']?.toString() ?? '') ?? 1;
          _contractPaid = contract['contract_paid'] ?? false;
          _contractPriceController.text =
              contract['contract_price']?.toString() ?? '';
          _contractDepositController.text =
              contract['contract_deposit']?.toString() ?? '';
          _noteController.text = contract['contract_note'] ?? '';
          _currentDocumentUrl = contract['contract_document'];
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      // Allow historical dates for start date; end date cannot be before start date
      firstDate: isStartDate ? DateTime(2000) : (_startDate ?? DateTime(2000)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: Localizations.localeOf(context),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary, // สีของ header และวันที่เลือก
              onPrimary: Colors.white, // สีของตัวอักษรใน header
              onSurface: Colors.black, // สีของวันที่ในปฏิทิน
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black, // สีของปุ่ม Cancel และ OK
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate == null) {
            _endDate = picked.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // เลือกไฟล์เอกสารสัญญา
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _documentPath = file.path ?? '';
          _documentName = file.name;
          _documentBytes = file.bytes;
          _documentChanged = true;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาดในการเลือกไฟล์: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // Helper function to get content type from extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _updateContract() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('กรุณาเลือกวันที่เริ่มและสิ้นสุดสัญญา')),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? documentUrl = _currentDocumentUrl;

      // Upload new document if changed
      if (_documentChanged && _documentBytes != null && _documentName != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('กำลังอัปโหลดเอกสาร...'),
              ],
            ),
          ),
        );

        try {
          // ดึง extension ของไฟล์เอกสาร
          final extension =
              path.extension(_documentName!).toLowerCase().replaceAll('.', '');

          // ดึงชื่อจากเลขสัญญา
          final contractNum = _contract?['contract_num'] ?? 'contract';

          // สร้างชื่อไฟล์แบบ sequential
          final now = DateTime.now();
          final dateStr =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

          // หาเลขลำดับถัดไป
          final files = await _supabase.storage.from('contracts').list();
          int maxSeq = 0;
          final pattern = RegExp(
              '^contracts_${dateStr}_${RegExp.escape(contractNum)}_\\d{3}\\.$extension\$');

          for (final f in files) {
            if (pattern.hasMatch(f.name)) {
              final parts = f.name.split('_');
              if (parts.length >= 4) {
                final seqWithExt = parts.last;
                final seqStr = seqWithExt.split('.').first;
                final seq = int.tryParse(seqStr) ?? 0;
                if (seq > maxSeq) maxSeq = seq;
              }
            }
          }

          final nextSeq = (maxSeq + 1).toString().padLeft(3, '0');
          final fileName =
              'contracts_${dateStr}_${contractNum}_$nextSeq.$extension';

          // อัปโหลดไฟล์
          await _supabase.storage.from('contracts').uploadBinary(
                fileName,
                _documentBytes!,
                fileOptions: FileOptions(
                  upsert: false,
                  contentType: _getContentType(extension),
                ),
              );

          documentUrl =
              _supabase.storage.from('contracts').getPublicUrl(fileName);

          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          throw Exception('ไม่สามารถอัปโหลดเอกสารได้: $e');
        }
      }

      final data = {
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'contract_price': double.tryParse(_contractPriceController.text) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text) ?? 0,
        'payment_day': _paymentDay,
        'contract_paid': _contractPaid,
        'contract_note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'contract_document': documentUrl,
      };

      final result =
          await ContractService.updateContract(widget.contractId, data);

      if (mounted) {
        setState(() => _isSaving = false);

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text(result['message'])),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text(result['message'])),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildWhiteHeader(),
            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: EdgeInsets.all(20),
                        children: [
                          _buildContractEditSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Top bar with back button
          Padding(
            padding: EdgeInsets.all(24),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'แก้ไขข้อมูลสัญญา',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'สำหรับแก้ไขข้อมูลผู้เช่า',
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
          ),
        ],
      ),
    );
  }

  Widget _buildContractEditSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'รายละเอียดสัญญา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.assignment,
            label: 'เลขที่สัญญา',
            value: '${_contract?['contract_num'] ?? '-'}',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.home,
            label: 'ปรเภท${_contract?['roomcate_name'] ?? '-'}',
            value: 'เลขที่ ${_contract?['room_number'] ?? '-'}',
          ),
          const SizedBox(height: 24),
          // วันที่เริ่มสัญญา
          InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่เริ่มสัญญา',
                prefixIcon: const Icon(Icons.date_range),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xff10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _startDate != null
                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year + 543}'
                    : 'เลือกวันที่',
                style: TextStyle(
                  color: _startDate != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // วันที่สิ้นสุดสัญญา
          InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่สิ้นสุดสัญญา',
                prefixIcon: const Icon(Icons.event_busy),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xff10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year + 543}'
                    : 'เลือกวันที่',
                style: TextStyle(
                  color: _endDate != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ค่าเช่า
          TextFormField(
            controller: _contractPriceController,
            decoration: InputDecoration(
              labelText: 'ค่าเช่า',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกค่าเช่า';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'กรุณากรอกตัวเลขเท่านั้น';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ค่าประกัน
          TextFormField(
            controller: _contractDepositController,
            decoration: InputDecoration(
              labelText: 'ค่าประกัน',
              prefixIcon: const Icon(Icons.security),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกค่าประกัน';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'กรุณากรอกตัวเลขเท่านั้น';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // วันที่ชำระประจำเดือน
          DropdownButtonFormField<int>(
            dropdownColor: Colors.white,
            value: _paymentDay,
            decoration: InputDecoration(
              labelText: 'วันที่ชำระประจำเดือน',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: List.generate(31, (index) => index + 1)
                .map((day) => DropdownMenuItem(
                      value: day,
                      child: Text('วันที่ $day'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _paymentDay = value ?? 1;
              });
            },
          ),
          const SizedBox(height: 16),

          // ชำระค่าประกันแล้ว
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SwitchListTile(
              title: const Text('ชำระค่าประกันแล้ว'),
              subtitle: Text(
                _contractPaid
                    ? 'ผู้เช่าชำระค่าประกันเรียบร้อยแล้ว'
                    : 'ผู้เช่ายังไม่ได้ชำระค่าประกัน',
                style: TextStyle(
                  fontSize: 12,
                  color: _contractPaid
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
              value: _contractPaid,
              onChanged: (value) {
                setState(() {
                  _contractPaid = value;
                });
              },
              activeColor: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // หมายเหตุ
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม',
              prefixIcon: const Icon(Icons.note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // อัปโหลดเอกสารสัญญา
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.upload_file_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'เอกสารสัญญา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // แสดง document ปัจจุบัน หรือปุ่มอัปโหลด
          if (_currentDocumentUrl != null && !_documentChanged) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'มีเอกสารแนบแล้ว',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _currentDocumentUrl!.split('/').last,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.swap_horiz, color: Colors.blue),
                    onPressed: _pickDocument,
                    tooltip: 'เปลี่ยนเอกสาร',
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickDocument,
              label: Text(
                _documentName ?? 'อัปโหลดเอกสารสัญญา',
                style: TextStyle(
                  color: _documentChanged ? Colors.green : Colors.black,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(
                  color: _documentChanged ? Colors.green : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_documentName != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _documentName!,
                        style: TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _documentPath = null;
                          _documentName = null;
                          _documentBytes = null;
                          _documentChanged = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool canSave = !_isSaving && !_isLoading;
    return SafeArea(
      top: false,
      child: Container(
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSave ? _updateContract : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isSaving ? 'กำลังบันทึกการแก้ไข...' : 'บันทึกการแก้ไข',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? AppTheme.primary : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: canSave ? 2 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
