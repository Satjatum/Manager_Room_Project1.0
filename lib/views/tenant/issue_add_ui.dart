import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/issue_service.dart';
import '../../services/image_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';
import 'package:image_picker/image_picker.dart';

class CreateIssueScreen extends StatefulWidget {
  final String? roomId;
  final String? tenantId;

  const CreateIssueScreen({
    Key? key,
    this.roomId,
    this.tenantId,
  }) : super(key: key);

  @override
  State<CreateIssueScreen> createState() => _CreateIssueScreenState();
}

class _CreateIssueScreenState extends State<CreateIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  String? _roomId;
  String? _tenantId;
  String? _roomNumber;
  String? _branchName;

  String _selectedIssueType = 'repair';

  List<XFile> _selectedImages = [];
  static const int maxImages = 10;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    _tenantId = widget.tenantId;
    _loadUserData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoadingData = true);

      _currentUser = await AuthService.getCurrentUser();

      if (_currentUser == null) {
        if (mounted) {
          _showErrorSnackBar('กรุณาเข้าสู่ระบบใหม่');
          Navigator.of(context).pop();
        }
        return;
      }

      if (_currentUser!.userRole == UserRole.tenant) {
        if (_currentUser!.tenantId != null) {
          _tenantId = _currentUser!.tenantId;

          final contractInfo =
              await _getTenantContractInfo(_currentUser!.tenantId!);

          if (contractInfo != null) {
            _roomId = contractInfo['room_id'];
            _roomNumber = contractInfo['room_number'];
            _branchName = contractInfo['branch_name'];
          } else {
            if (mounted) {
              _showErrorSnackBar('ไม่พบข้อมูลห้องพัก กรุณาติดต่อผู้ดูแลระบบ');
              Navigator.of(context).pop();
              return;
            }
          }
        } else {
          if (mounted) {
            _showErrorSnackBar('ไม่พบข้อมูลผู้เช่า กรุณาติดต่อผู้ดูแลระบบ');
            Navigator.of(context).pop();
            return;
          }
        }
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _getTenantContractInfo(String tenantId) async {
    try {
      final result = await Supabase.instance.client
          .from('rental_contracts')
          .select('''
            room_id,
            rooms!inner(
              room_number,
              branches!inner(branch_name)
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('contract_status', 'active')
          .maybeSingle();

      if (result != null) {
        return {
          'room_id': result['room_id'],
          'room_number': result['rooms']?['room_number'],
          'branch_name': result['rooms']?['branches']?['branch_name'],
        };
      }
      return null;
    } catch (e) {
      print('Error getting tenant contract info: $e');
      return null;
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= maxImages) {
      _showErrorSnackBar('สามารถเลือกรูปภาพได้สูงสุด $maxImages รูป');
      return;
    }

    try {
      if (kIsWeb) {
        await _pickImagesForWeb();
      } else {
        await _pickImagesForMobile();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกภาพ: $e');
      }
    }
  }

  Future<void> _pickImagesForWeb() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      int remainingSlots = maxImages - _selectedImages.length;
      List<XFile> imagesToAdd = images.take(remainingSlots).toList();

      setState(() {
        _selectedImages.addAll(imagesToAdd);
      });

      if (images.length > remainingSlots) {
        _showErrorSnackBar(
            'เลือกได้เพียง $remainingSlots รูป (สูงสุด $maxImages รูป)');
      } else {
        _showSuccessSnackBar('เลือกรูปภาพ ${imagesToAdd.length} รูป');
      }
    }
  }

  Future<void> _pickImagesForMobile() async {
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
                      'เลือกภาพ',
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
                                      size: 40, color: Color(0xFF10B981)),
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
                                      size: 40, color: Color(0xFF10B981)),
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

    final ImagePicker picker = ImagePicker();

    if (source == ImageSource.camera) {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
        _showSuccessSnackBar('ถ่ายรูปสำเร็จ');
      }
    } else {
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        int remainingSlots = maxImages - _selectedImages.length;
        List<XFile> imagesToAdd = images.take(remainingSlots).toList();

        setState(() {
          _selectedImages.addAll(imagesToAdd);
        });

        if (images.length > remainingSlots) {
          _showErrorSnackBar(
              'เลือกได้เพียง $remainingSlots รูป (สูงสุด $maxImages รูป)');
        } else {
          _showSuccessSnackBar('เลือกรูปภาพ ${imagesToAdd.length} รูป');
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _showSuccessSnackBar('ลบรูปภาพแล้ว');
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_roomId == null) {
      _showErrorSnackBar('ไม่พบข้อมูลห้องพัก');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.8),
                    AppTheme.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('ยืนยันการรายงาน')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณต้องการรายงานปัญหานี้ใช่หรือไม่?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'สรุปรายการ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  _buildSummaryRow('หัวข้อ', _titleController.text),
                  _buildSummaryRow(
                      'ประเภท', _getIssueTypeText(_selectedIssueType)),
                  if (_selectedImages.isNotEmpty)
                    _buildSummaryRow('รูปภาพ', '${_selectedImages.length} รูป'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final issueData = {
        'room_id': _roomId,
        'tenant_id': _tenantId,
        'issue_type': _selectedIssueType,
        'issue_title': _titleController.text.trim(),
        'issue_desc': _descController.text.trim(),
      };

      final result = await IssueService.createIssue(issueData);

      if (result['success']) {
        final issueId = result['data']['issue_id'];

        if (_selectedImages.isNotEmpty) {
          for (int i = 0; i < _selectedImages.length; i++) {
            final imageFile = _selectedImages[i];

            // Prepare naming parts
            final now = DateTime.now();
            final dateStr =
                '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
            final tenantName = _sanitizeForFile(_currentUser?.tenantFullName ??
                _currentUser?.displayName ??
                _currentUser?.userName ??
                'tenant');
            final branchName = _sanitizeForFile(_branchName ?? '');
            final roomNum = _sanitizeForFile(_roomNumber ?? '');

            // Determine extension
            String ext;
            if (kIsWeb) {
              final name = imageFile.name;
              ext = name.contains('.')
                  ? name.split('.').last.toLowerCase()
                  : 'jpg';
            } else {
              final p = imageFile.path;
              ext = p.contains('.') ? p.split('.').last.toLowerCase() : 'jpg';
            }

            // Generate sequential number using ImageService helper
            final seqFile = await ImageService.generateSequentialFileName(
              bucket: 'issue-images',
              folder: tenantName,
              prefix: 'Issue',
              extension: ext,
              date: now,
            );
            final seq = seqFile.split('_').last.split('.').first; // e.g., 001

            final customName =
                'Issue_${dateStr}_${tenantName}_${branchName}_${roomNum}_${seq}.$ext';

            Map<String, dynamic> uploadResult;

            if (kIsWeb) {
              final bytes = await imageFile.readAsBytes();
              uploadResult = await ImageService.uploadImageFromBytes(
                bytes,
                imageFile.name,
                'issue-images',
                folder: 'issue',
                customFileName: customName,
              );
            } else {
              uploadResult = await ImageService.uploadImage(
                File(imageFile.path),
                'issue-images',
                folder: 'issue',
                customFileName: customName,
              );
            }

            if (uploadResult['success']) {
              await IssueService.addIssueImage(
                issueId,
                uploadResult['url'],
              );
            } else {
              _showErrorSnackBar(
                  uploadResult['message'] ?? 'อัปโหลดรูปภาพไม่สำเร็จ');
            }
          }
        }

        if (mounted) {
          _showSuccessSnackBar(result['message']);
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getIssueTypeText(String type) {
    switch (type) {
      case 'repair':
        return 'ซ่อมแซม';
      case 'maintenance':
        return 'บำรุงรักษา';
      case 'complaint':
        return 'ร้องเรียน';
      case 'suggestion':
        return 'ข้อเสนอแนะ';
      case 'other':
        return 'อื่นๆ';
      default:
        return type;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
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
                          'แจ้งปัญหา',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับแจ้งปัญหา',
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

            // Content
            Expanded(
              child: _isLoadingData
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'กำลังโหลดข้อมูล...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTypeAndPriorityCard(),
                            const SizedBox(height: 16),
                            _buildImagesCard(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildRoomInfoCard() {
    return _buildModernCard(
      'ข้อมูลห้องพัก',
      Icons.meeting_room_outlined,
      Colors.blue,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.home, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หมายเลขห้อง',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roomNumber ?? 'ไม่ระบุ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.business,
                      color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สาขา',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _branchName ?? 'ไม่ระบุ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeAndPriorityCard() {
    return _buildModernCard(
      'หัวเรื่องการแจ้งปัญหา',
      Icons.category_outlined,
      AppTheme.primary,
      Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'หัวข้อปัญหา',
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
              prefixIcon: const Icon(Icons.title),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกหัวข้อปัญหา';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: _selectedIssueType,
            decoration: InputDecoration(
              labelText: 'ประเภทปัญหา',
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
              prefixIcon: const Icon(Icons.build_circle_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'repair', child: Text(' ซ่อมแซม')),
              DropdownMenuItem(value: 'maintenance', child: Text('บำรุงรักษา')),
              DropdownMenuItem(value: 'complaint', child: Text('ร้องเรียน')),
              DropdownMenuItem(value: 'suggestion', child: Text('ข้อเสนอแนะ')),
              DropdownMenuItem(value: 'other', child: Text(' อื่นๆ')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedIssueType = value);
              }
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'รายละเอียด',
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
            maxLines: 5,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกรายละเอียดปัญหา';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCard() {
    return _buildModernCard(
      'รูปภาพประกอบ (${_selectedImages.length}/$maxImages)',
      Icons.photo_library_outlined,
      AppTheme.primary,
      Column(
        children: [
          if (_selectedImages.isEmpty)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'แตะเพื่อเพิ่มรูปภาพ',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kIsWeb
                          ? 'คลิกเพื่อเลือกรูปภาพจากเครื่อง'
                          : 'ถ่ายรูปหรือเลือกจากคลัง',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'สูงสุด $maxImages รูป',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    final imageFile = _selectedImages[index];

                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? FutureBuilder(
                                  future: imageFile.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primary,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(imageFile.path),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedImages.length < maxImages)
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: Icon(
                        kIsWeb ? Icons.add_photo_alternate : Icons.camera_alt),
                    label: const Text('เพิ่มรูปเพิ่มเติม'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitIssue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'กำลังส่งข้อมูล...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'รายงานปัญหา',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildModernCard(
    String title,
    IconData icon,
    Color color,
    Widget child,
  ) {
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // Sanitize strings for safe filename usage
  String _sanitizeForFile(String input) {
    var s = input.trim();
    // Replace spaces and invalid characters with underscores
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    // Collapse repeated underscores
    s = s.replaceAll(RegExp(r'_+'), '_');
    // Trim leading/trailing underscores
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s;
  }
}
