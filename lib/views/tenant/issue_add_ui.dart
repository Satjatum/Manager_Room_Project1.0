import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
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
  String _selectedPriority = 'medium';

  List<XFile> _selectedImageFiles = [];
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
    try {
      final ImagePicker picker = ImagePicker();

      if (kIsWeb) {
        final List<XFile> images = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (images.isNotEmpty) {
          setState(() {
            _selectedImageFiles.addAll(images);
          });
          _showSuccessSnackBar('เลือกรูปภาพ ${images.length} รูป');
        }
      } else {
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: const Icon(Icons.photo_camera,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text('เลือกรูปภาพจาก'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Icon(Icons.camera_alt, color: Colors.blue.shade700),
                    ),
                    title: const Text('ถ่ายรูป'),
                    subtitle: Text('ใช้กล้องถ่ายภาพ',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.photo_library,
                          color: Colors.green.shade700),
                    ),
                    title: const Text('คลังรูปภาพ'),
                    subtitle: Text('เลือกจากคลังภาพ',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        );

        if (source != null) {
          if (source == ImageSource.camera) {
            final XFile? photo = await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 1920,
              maxHeight: 1080,
              imageQuality: 85,
            );

            if (photo != null) {
              setState(() {
                _selectedImageFiles.add(photo);
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
              setState(() {
                _selectedImageFiles.addAll(images);
              });
              _showSuccessSnackBar('เลือกรูปภาพ ${images.length} รูป');
            }
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
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
                  _buildSummaryRow(
                      'ความสำคัญ', _getPriorityText(_selectedPriority)),
                  if (_selectedImageFiles.isNotEmpty)
                    _buildSummaryRow(
                        'รูปภาพ', '${_selectedImageFiles.length} รูป'),
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
        'issue_priority': _selectedPriority,
        'issue_title': _titleController.text.trim(),
        'issue_desc': _descController.text.trim(),
      };

      final result = await IssueService.createIssue(issueData);

      if (result['success']) {
        final issueId = result['data']['issue_id'];

        if (_selectedImageFiles.isNotEmpty) {
          for (int i = 0; i < _selectedImageFiles.length; i++) {
            final imageFile = _selectedImageFiles[i];

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
              // Surface upload error to user for quick diagnosis
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

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'urgent':
        return 'ด่วนมาก';
      case 'high':
        return 'สูง';
      case 'medium':
        return 'ปานกลาง';
      case 'low':
        return 'ต่ำ';
      default:
        return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
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
      appBar: AppBar(
        title: const Text(
          'รายงานปัญหา',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoadingData
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
                    // ไม่ต้องแสดงข้อมูลห้องพักตามคำขอ
                    _buildTypeAndPriorityCard(),
                    const SizedBox(height: 16),
                    _buildImagesCard(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
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
      'ประเภทและความสำคัญ',
      Icons.category_outlined,
      Colors.green,
      Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'หัวข้อปัญหา',
              hintText: 'เช่น ก๊อกน้ำรั่ว, แอร์เสีย',
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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedPriority,
            decoration: InputDecoration(
              labelText: 'ความสำคัญ',
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
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'low', child: Text(' ต่ำ')),
              DropdownMenuItem(value: 'medium', child: Text('ปานกลาง')),
              DropdownMenuItem(value: 'high', child: Text(' สูง')),
              DropdownMenuItem(value: 'urgent', child: Text('ด่วนมาก')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedPriority = value);
              }
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: 'รายละเอียด',
              hintText: 'อธิบายปัญหาโดยละเอียด',
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
      'รูปภาพประกอบ (${_selectedImageFiles.length})',
      Icons.photo_library_outlined,
      Colors.purple,
      Column(
        children: [
          if (_selectedImageFiles.isEmpty)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
                        color: Colors.purple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.purple.shade400,
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
                  itemCount: _selectedImageFiles.length,
                  itemBuilder: (context, index) {
                    final imageFile = _selectedImageFiles[index];

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
                            onTap: () {
                              setState(() {
                                _selectedImageFiles.removeAt(index);
                              });
                            },
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

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitIssue,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
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
                const Icon(Icons.send, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'รายงานปัญหา',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
