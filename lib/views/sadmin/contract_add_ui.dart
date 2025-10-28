import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/room_service.dart';
import '../../services/branch_service.dart';
import '../../services/contract_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../widgets/colors.dart';

class ContractAddUI extends StatefulWidget {
  final String tenantId;
  final String? branchId;
  final String? tenantName;

  const ContractAddUI({
    Key? key,
    required this.tenantId,
    this.branchId,
    this.tenantName,
  }) : super(key: key);

  @override
  State<ContractAddUI> createState() => _ContractAddUIState();
}

class _ContractAddUIState extends State<ContractAddUI> {
  UserModel? _currentUser;
  bool _loading = true;
  bool _saving = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _selectedBranchId;
  String? _branchName;
  String? _selectedRoomId;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _availableRooms = [];

  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  int _paymentDay = 1;

  // เอกสารสัญญา
  String? _documentName;
  Uint8List? _documentBytes;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 365));
    _init();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _depositController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _currentUser = await AuthMiddleware.getCurrentUser();

      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
        final b = await BranchService.getBranchById(_selectedBranchId!);
        _branchName = b?['branch_name'];
        await _loadRooms(_selectedBranchId!);
      } else {
        _branches = await BranchService.getBranchesByUser();
      }
    } catch (e) {
      _showError('ไม่สามารถโหลดข้อมูลได้: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRooms(String branchId) async {
    final rooms = await RoomService.getAllRooms(
      branchId: branchId,
      roomStatus: 'available',
      isActive: true,
      orderBy: 'room_number',
      ascending: true,
    );
    setState(() {
      _availableRooms = rooms;
      _selectedRoomId = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now().add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startDate = picked;
          if (_endDate == null || _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      _showError('กรุณาเลือกสาขา');
      return;
    }
    if (_selectedRoomId == null) {
      _showError('กรุณาเลือกห้องพัก');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError('กรุณาเลือกวันเริ่มและสิ้นสุดสัญญา');
      return;
    }
    if ((_priceController.text.trim()).isEmpty ||
        double.tryParse(_priceController.text.trim()) == null) {
      _showError('กรุณากรอกค่าเช่าที่ถูกต้อง');
      return;
    }
    if ((_depositController.text.trim()).isEmpty ||
        double.tryParse(_depositController.text.trim()) == null) {
      _showError('กรุณากรอกค่าประกันที่ถูกต้อง');
      return;
    }

    setState(() => _saving = true);
    try {
      String? documentUrl;

      // อัปโหลดเอกสารถ้ามี
      if (_documentBytes != null && _documentName != null) {
        // แสดงสถานะกำลังอัปโหลด
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('กำลังอัปโหลดเอกสาร...'),
              ],
            ),
          ),
        );

        try {
          final now = DateTime.now();
          final dateStr =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          final baseName = (widget.tenantName ?? 'tenant')
              .trim()
              .replaceAll(RegExp(r'\s+'), '_');

          // หาเลขลำดับถัดไป
          final existing = await _supabase.storage
              .from('contracts')
              .list(path: '');
          final regex = RegExp('^contracts_${dateStr}_${RegExp.escape(baseName)}_([0-9]{3})\\.pdf\$');
          int maxSeq = 0;
          for (final f in existing) {
            final name = f.name;
            final m = regex.firstMatch(name);
            if (m != null) {
              final n = int.tryParse(m.group(1)! ) ?? 0;
              if (n > maxSeq) maxSeq = n;
            }
          }
          final nextSeq = (maxSeq + 1).toString().padLeft(3, '0');
          final fileName = 'contracts_${dateStr}_${baseName}_$nextSeq.pdf';

          // content type ตามนามสกุลไฟล์ต้นฉบับ
          final ext = p.extension(_documentName!).replaceFirst('.', '').toLowerCase();
          final contentType = _getContentType(ext);

          await _supabase.storage
              .from('contracts')
              .uploadBinary(
                fileName,
                _documentBytes!,
                fileOptions: FileOptions(contentType: contentType, upsert: false),
              );

          final pub = _supabase.storage.from('contracts').getPublicUrl(fileName);
          documentUrl = pub;
        } catch (e) {
          // ปิด dialog
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          rethrow;
        }

        // ปิด dialog อัปโหลด
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }

      final result = await ContractService.createContract({
        'tenant_id': widget.tenantId,
        'room_id': _selectedRoomId,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'contract_price': double.parse(_priceController.text.trim()),
        'contract_deposit': double.parse(_depositController.text.trim()),
        'payment_day': _paymentDay,
        'contract_note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'contract_document': documentUrl,
      });

      if (result['success'] == true) {
        if (mounted) {
          _showSuccess('สร้างสัญญาสำเร็จ');
          Navigator.pop(context, true);
        }
      } else {
        _showError(result['message'] ?? 'ไม่สามารถสร้างสัญญาได้');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDocument() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final f = res.files.first;
      if (f.bytes != null) {
        setState(() {
          _documentName = f.name;
          _documentBytes = f.bytes;
        });
      } else if (f.path != null) {
        // ในกรณีบางแพลตฟอร์มอาจไม่ได้ bytes มา
        _showError('ไม่สามารถอ่านไฟล์ได้ กรุณาลองใหม่');
      }
    }
  }

  String _getContentType(String ext) {
    switch (ext) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สร้างสัญญาเช่า',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.tenantName != null)
              Text(
                widget.tenantName!,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBranchSection(),
                    const SizedBox(height: 16),
                    _buildRoomSection(),
                    const SizedBox(height: 16),
                    _buildContractSection(),
                    const SizedBox(height: 16),
                    _buildDocumentSection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกสัญญา'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBranchSection() {
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
              Icon(Icons.business, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'สาขา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty)
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'สาขา *',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _branchName ?? 'Locked Branch',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: InputDecoration(
                labelText: 'สาขา *',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _branches
                  .map((b) => DropdownMenuItem<String>(
                        value: b['branch_id'],
                        child: Text(b['branch_name'] ?? ''),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _selectedBranchId = v;
                  _selectedRoomId = null;
                  _availableRooms = [];
                });
                if (v != null) {
                  final b = await BranchService.getBranchById(v);
                  setState(() => _branchName = b?['branch_name']);
                  await _loadRooms(v);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoomSection() {
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
              Icon(Icons.home, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'เลือกห้องพัก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedBranchId == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('กรุณาเลือกสาขาก่อน', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedRoomId,
              decoration: InputDecoration(
                labelText: 'ห้องพัก *',
                prefixIcon: const Icon(Icons.hotel),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _availableRooms
                  .map((room) => DropdownMenuItem<String>(
                        value: room['room_id'],
                        child: Row(
                          children: [
                            Text('${room['room_category_name'] ?? 'ห้อง'} เลขที่ ${room['room_number']}'),
                            const SizedBox(width: 8),
                            Text(
                              '฿${room['room_price']?.toStringAsFixed(0) ?? '0'}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedRoomId = v;
                  if (v != null) {
                    final r = _availableRooms.firstWhere(
                      (e) => e['room_id'] == v,
                      orElse: () => {},
                    );
                    if (r.isNotEmpty) {
                      _priceController.text = (r['room_price'] ?? '').toString();
                      _depositController.text = (r['room_deposit'] ?? '').toString();
                    }
                  }
                });
              },
            ),
          if (_selectedBranchId != null && _availableRooms.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('ไม่มีห้องว่างในสาขานี้', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractSection() {
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
              Icon(Icons.description, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'รายละเอียดสัญญา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Start date
          InkWell(
            onTap: () => _pickDate(true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่เริ่มสัญญา *',
                prefixIcon: const Icon(Icons.date_range),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _startDate == null
                    ? 'เลือกวันที่'
                    : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year + 543}',
                style: TextStyle(
                  color: _startDate == null ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // End date
          InkWell(
            onTap: () => _pickDate(false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่สิ้นสุดสัญญา *',
                prefixIcon: const Icon(Icons.event_busy),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _endDate == null
                    ? 'เลือกวันที่'
                    : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year + 543}',
                style: TextStyle(
                  color: _endDate == null ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Price
          TextFormField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'ค่าเช่า (บาท/เดือน) *',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Deposit
          TextFormField(
            controller: _depositController,
            decoration: InputDecoration(
              labelText: 'ค่าประกัน (บาท) *',
              prefixIcon: const Icon(Icons.security),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Payment day
          DropdownButtonFormField<int>(
            value: _paymentDay,
            decoration: InputDecoration(
              labelText: 'วันครบกำหนดชำระ *',
              prefixIcon: const Icon(Icons.event_note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: List.generate(31, (i) => i + 1)
                .map((d) => DropdownMenuItem<int>(value: d, child: Text('$d')))
                .toList(),
            onChanged: (v) => setState(() => _paymentDay = v ?? 1),
          ),
          const SizedBox(height: 12),

          // Note
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'หมายเหตุ',
              prefixIcon: const Icon(Icons.notes),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
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
              Icon(Icons.upload_file, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'เอกสารสัญญา (ไม่บังคับ)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_documentBytes == null)
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDocument,
              icon: const Icon(Icons.attach_file),
              label: const Text('แนบไฟล์สัญญา (PDF, DOC, ภาพ)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _documentName ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'ลบไฟล์',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _documentBytes = null;
                              _documentName = null;
                            }),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
