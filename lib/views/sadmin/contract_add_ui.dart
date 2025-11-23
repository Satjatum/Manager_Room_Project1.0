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
  final String? branchName;
  final String? tenantName;

  const ContractAddUI({
    Key? key,
    required this.tenantId,
    this.branchId,
    this.branchName,
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
  bool _advancePayment = false;

  // เอกสารสัญญา
  String? _documentName;
  Uint8List? _documentBytes;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    // _startDate = DateTime.now();
    // _endDate = DateTime.now().add(const Duration(days: 365));
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
          _documentName = file.name;
          _documentBytes = file.bytes;
        });
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการเลือกไฟล์: $e');
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
          final baseName = (widget.tenantName ?? 'tenant').trim().replaceAll(
                RegExp(r'\s+'),
                '_',
              );

          // หาเลขลำดับถัดไป
          final existing =
              await _supabase.storage.from('contracts').list(path: '');
          final regex = RegExp(
            '^contracts_${dateStr}_${RegExp.escape(baseName)}_([0-9]{3})\\.pdf\$',
          );
          int maxSeq = 0;
          for (final f in existing) {
            final name = f.name;
            final m = regex.firstMatch(name);
            if (m != null) {
              final n = int.tryParse(m.group(1)!) ?? 0;
              if (n > maxSeq) maxSeq = n;
            }
          }
          final nextSeq = (maxSeq + 1).toString().padLeft(3, '0');
          final fileName = 'contracts_${dateStr}_${baseName}_$nextSeq.pdf';

          // content type ตามนามสกุลไฟล์ต้นฉบับ
          final ext =
              p.extension(_documentName!).replaceFirst('.', '').toLowerCase();
          final contentType = _getContentType(ext);

          await _supabase.storage.from('contracts').uploadBinary(
                fileName,
                _documentBytes!,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: false,
                ),
              );

          final pub =
              _supabase.storage.from('contracts').getPublicUrl(fileName);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลห้องพัก
                    _buildRoomSection(),
                    const SizedBox(height: 16),

                    // รายละเอียดสัญญา
                    _buildContractDetailsSection(),
                    const SizedBox(height: 16),

                    // เอกสารสัญญา
                    _buildDocumentSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(children: [
        // Top bar with back button
        Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
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
                      'เพิ่มสัญญาผู้เช่า',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'สำหรับเพิ่มสัญญาผู้เช่า',
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
      ]),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: Icon(Icons.business_outlined,
                      color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'เลือกห้องพัก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: _selectedRoomId,
              decoration: InputDecoration(
                labelText: 'ห้องพัก',
                prefixIcon: const Icon(Icons.meeting_room),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _availableRooms.map((room) {
                return DropdownMenuItem<String>(
                  value: room['room_id'],
                  child: Row(
                    children: [
                      Text(
                          '${room['room_category_name'] ?? 'ห้อง'}เลขที่${room['room_number']}'),
                      const SizedBox(width: 8),
                      Text(
                        '฿${room['room_price']?.toStringAsFixed(0) ?? '0'}',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(
                  () {
                    _selectedRoomId = v;
                    if (v != null) {
                      final selectedRoom = _availableRooms.firstWhere(
                        (room) => room['room_id'] == v,
                        orElse: () => {},
                      );
                      if (selectedRoom.isNotEmpty) {
                        _priceController.text =
                            selectedRoom['room_price']?.toString() ?? '';
                        _depositController.text =
                            selectedRoom['room_deposit']?.toString() ?? '';
                      }
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
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
                    color:
                        _startDate == null ? Colors.grey[600] : Colors.black87,
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
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
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
            const SizedBox(height: 16),

            // ค่าเช่า
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'ค่าเช่า',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
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
            const SizedBox(height: 16),

            // ค่าประกัน
            TextFormField(
              controller: _depositController,
              decoration: InputDecoration(
                labelText: 'ค่าประกัน',
                prefixIcon: const Icon(Icons.security),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
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
            const SizedBox(height: 16),

            // วันที่ชำระค่าเช่า
            DropdownButtonFormField<int>(
              dropdownColor: Colors.white,
              value: _paymentDay,
              decoration: InputDecoration(
                labelText: 'วันที่ชำระค่าเช่า',
                prefixIcon: const Icon(Icons.event_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: List.generate(31, (i) => i + 1)
                  .map(
                    (d) => DropdownMenuItem<int>(
                      value: d,
                      child: Text('วันที่ $d'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _paymentDay = v ?? 1),
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
                  _advancePayment
                      ? 'ผู้เช่าชำระค่าประกันเรียบร้อยแล้ว'
                      : 'ผู้เช่ายังไม่ได้ชำระค่าประกัน',
                  style: TextStyle(
                    fontSize: 12,
                    color: _advancePayment
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                value: _advancePayment,
                onChanged: (value) {
                  setState(() {
                    _advancePayment = value;
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
                hintText: 'เพิ่มหมายเหตุเกี่ยวกับสัญญาเช่า (ถ้ามี)',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 2,
                  ),
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
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: Icon(Icons.upload_file_outlined,
                      color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'อัปโหลดเอกสารสัญญา',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // อัปโหลดเอกสาร
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDocument,
              label: Text(
                _documentName ?? 'อัปโหลดเอกสารสัญญา',
                style: TextStyle(color: Colors.black),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
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
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _documentName = null;
                                _documentBytes = null;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool canSave = !_saving && !_loading;
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
            onPressed: canSave ? _save : null,
            icon: _saving
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
              _saving ? 'กำลังบันทึก...' : 'บันทึก',
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
