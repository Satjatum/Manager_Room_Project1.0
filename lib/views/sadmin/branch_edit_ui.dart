import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
//--------
import '../../models/user_models.dart';
//--------
import '../../middleware/auth_middleware.dart';
//--------
import '../../services/branch_service.dart';
import '../../services/user_service.dart';
import '../../services/image_service.dart';
import '../../services/branch_manager_service.dart';

class BranchEditUi extends StatefulWidget {
  final String branchId;

  const BranchEditUi({
    Key? key,
    required this.branchId,
  }) : super(key: key);

  @override
  State<BranchEditUi> createState() => _BranchEditUiState();
}

class _BranchEditUiState extends State<BranchEditUi>
    with SingleTickerProviderStateMixin {
  // Controllers and state variables (same as branch_add but with additional fields)
  final _formKey = GlobalKey<FormState>();
  final _branchCodeController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchDescController = TextEditingController();
  final _branchPhoneController = TextEditingController();

  late TabController _tabController;
  int _currentTabIndex = 0;

  List<String> _selectedManagerIds = [];
  String? _primaryManagerId;
  List<Map<String, dynamic>> _currentManagers = [];
  List<Map<String, dynamic>> _originalManagers = [];

  String? _currentImageUrl; // Existing image URL
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isLoadingManagers = false;
  bool _imageChanged = false; // Track if image was changed
  bool _isCheckingAuth = true;

  List<Map<String, dynamic>> _adminUsers = [];
  UserModel? _currentUser;
  Map<String, dynamic>? _originalBranchData;

  bool get _isAdminBranchManager {
    if (_currentUser?.userRole != UserRole.admin) return false;
    if (_currentManagers.isEmpty) return false;
    final uid = _currentUser!.userId;
    return _currentManagers.any((m) {
      final directId = m['user_id'];
      final nested = m['users'] as Map<String, dynamic>?;
      final nestedId = nested?['user_id'];
      return directId == uid || nestedId == uid;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _initializePageData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _branchCodeController.dispose();
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchDescController.dispose();
    _branchPhoneController.dispose();
    super.dispose();
  }

  Future<void> _initializePageData() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await Future.wait([
        _loadBranchData(),
        _loadAdminUsers(),
        _loadBranchManagers(),
      ]);
    }
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadBranchData() async {
    try {
      final branch = await BranchService.getBranchById(widget.branchId);

      if (branch != null && mounted) {
        setState(() {
          _originalBranchData = Map.from(branch);
          _branchCodeController.text = branch['branch_code'] ?? '';
          _branchNameController.text = branch['branch_name'] ?? '';
          _branchAddressController.text = branch['branch_address'] ?? '';
          _branchDescController.text = branch['branch_desc'] ?? '';
          _branchPhoneController.text = branch['branch_phone'] ?? '';
          _isActive = branch['is_active'] ?? true;
          _currentImageUrl = branch['branch_image'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาดในการโหลดสาขา: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadAdminUsers() async {
    if (_currentUser == null) return;
    if (_currentUser!.userRole != UserRole.superAdmin) return;

    setState(() => _isLoadingManagers = true);

    try {
      final users = await UserService.getAdminUsers();
      if (mounted) {
        setState(() {
          _adminUsers = users;
          _isLoadingManagers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManagers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาดในการโหลดผู้ดูแล: $e')),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadBranchManagers() async {
    try {
      final managers =
          await BranchManagerService.getBranchManagers(widget.branchId);
      if (mounted) {
        setState(() {
          _currentManagers = managers;
          _originalManagers = List.from(managers);
          _selectedManagerIds =
              managers.map((m) => m['users']['user_id'] as String).toList();
          final primary = managers.firstWhere((m) => m['is_primary'] == true,
              orElse: () => {});
          if (primary.isNotEmpty) {
            _primaryManagerId = primary['users']['user_id'];
          }
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดผู้จัดการ: $e');
    }
  }

  void _toggleManagerSelection(String userId) {
    setState(() {
      if (_selectedManagerIds.contains(userId)) {
        _selectedManagerIds.remove(userId);
        if (_primaryManagerId == userId) {
          if (_selectedManagerIds.isNotEmpty) {
            _primaryManagerId = _selectedManagerIds.first;
          } else {
            _primaryManagerId = null;
          }
        }
      } else {
        _selectedManagerIds.add(userId);
        if (_selectedManagerIds.length == 1) {
          _primaryManagerId = userId;
        }
      }
    });
  }

  void _setPrimaryManager(String userId) {
    setState(() {
      _primaryManagerId = userId;
    });
  }

  // Image picking methods (same as branch_add but sets _imageChanged = true)
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageForWeb();
      } else {
        await _pickImageForMobile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาดในการเลือกภาพ: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickImageForWeb() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final name = image.name;

      if (await _validateImageBytesForWeb(bytes, name)) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = name;
          _selectedImage = null;
          _imageChanged = true;
        });
      }
    }
  }

  Future<void> _pickImageForMobile() async {
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
                    Text('เลือกภาพสาขา',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final file = File(image.path);

      if (await _validateImageFile(file)) {
        setState(() {
          _selectedImage = file;
          _selectedImageBytes = null;
          _selectedImageName = null;
          _imageChanged = true;
        });
      }
    }
  }

  // Validation methods (same as branch_add)
  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ขนาดไฟล์เกิน 5MB'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไฟล์ว่างเปล่าหรือเสียหาย'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการตรวจสอบไฟล์: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไม่พบไฟล์หรือไฟล์ถูกลบ'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ขนาดไฟล์เกิน 5MB'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      if (fileSize == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไฟล์ว่างเปล่าหรือเสียหาย'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เฉพาะไฟล์ JPG, JPEG, PNG, WebP เท่านั้น'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการตรวจสอบไฟล์: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
      _currentImageUrl = null;
      _imageChanged = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('ลบรูปภาพแล้ว'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateBranch() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณาเข้าสู่ระบบเพื่ออัปเดตสาขา'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final allowedUI = _currentUser!.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageBranches,
        ]) ||
        _isAdminBranchManager;

    if (!allowedUI) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('คุณไม่มีสิทธิ์แก้ไขสาขานี้'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (_currentUser!.userRole == UserRole.superAdmin) {
      if (_selectedManagerIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาเลือกผู้จัดการอย่างน้อยหนึ่งคน'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _tabController.animateTo(1);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;

      if (_imageChanged) {
        if (_selectedImage != null || _selectedImageBytes != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 16),
                    Text('กำลังอัปโหลดรูปภาพ...'),
                  ],
                ),
              ),
            ),
          );

          dynamic uploadResult;

          // Prepare sequential filename
          String? customName;
          try {
            final ext = (kIsWeb && _selectedImageBytes != null)
                ? (_selectedImageName ?? 'jpg').split('.').last.toLowerCase()
                : (_selectedImage != null)
                    ? _selectedImage!.path.split('.').last.toLowerCase()
                    : 'jpg';
            customName = await ImageService.generateSequentialFileName(
              bucket: 'branch-images',
              folder: 'branches',
              prefix: 'branch',
              extension: ext,
            );
          } catch (_) {}

          if (kIsWeb && _selectedImageBytes != null) {
            uploadResult = await ImageService.uploadImageFromBytes(
              _selectedImageBytes!,
              _selectedImageName ?? 'branch_image.jpg',
              'branch-images',
              folder: 'branches',
              customFileName: customName,
            );
          } else if (!kIsWeb && _selectedImage != null) {
            uploadResult = await ImageService.uploadImage(
              _selectedImage!,
              'branch-images',
              folder: 'branches',
              customFileName: customName,
            );
          }

          if (mounted) Navigator.of(context).pop();

          if (uploadResult != null && uploadResult['success']) {
            if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
              await ImageService.deleteImage(_currentImageUrl!);
            }
            imageUrl = uploadResult['url'];
          } else {
            throw Exception(
                uploadResult?['message'] ?? 'เกิดข้อผิดพลาดในการอัปโหลดภาพ');
          }
        } else {
          if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
            await ImageService.deleteImage(_currentImageUrl!);
          }
          imageUrl = null;
        }
      }

      final branchData = {
        'branch_code': _branchCodeController.text.trim(),
        'branch_name': _branchNameController.text.trim(),
        'branch_phone': _branchPhoneController.text.trim(),
        'branch_address': _branchAddressController.text.trim().isEmpty
            ? null
            : _branchAddressController.text.trim(),
        'branch_desc': _branchDescController.text.trim().isEmpty
            ? null
            : _branchDescController.text.trim(),
        'branch_image': imageUrl,
        'is_active': _isActive,
      };

      final result =
          await BranchService.updateBranch(widget.branchId, branchData);

      if (!result['success']) {
        throw Exception(result['message']);
      }

      if (_currentUser!.userRole == UserRole.superAdmin) {
        await _updateManagers();
      }

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('อัปเดตสาขาเรียบร้อยแล้ว')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateManagers() async {
    final originalIds =
        _originalManagers.map((m) => m['users']['user_id'] as String).toSet();
    final newIds = _selectedManagerIds.toSet();

    final toRemove = originalIds.difference(newIds);
    for (String managerId in toRemove) {
      await BranchManagerService.removeBranchManager(
        branchId: widget.branchId,
        userId: managerId,
      );
    }

    final toAdd = newIds.difference(originalIds);
    for (String managerId in toAdd) {
      await BranchManagerService.addBranchManager(
        branchId: widget.branchId,
        userId: managerId,
        isPrimary: managerId == _primaryManagerId,
      );
    }

    final originalPrimary = _originalManagers
        .firstWhere((m) => m['is_primary'] == true, orElse: () => {});
    final originalPrimaryId =
        originalPrimary.isNotEmpty ? originalPrimary['users']['user_id'] : null;

    if (_primaryManagerId != null && _primaryManagerId != originalPrimaryId) {
      await BranchManagerService.setPrimaryManager(
        branchId: widget.branchId,
        userId: _primaryManagerId!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth || _isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 3),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    final hasEditAccess = _currentUser != null &&
        (_currentUser!.hasAnyPermission([
              DetailedPermission.all,
              DetailedPermission.manageBranches,
            ]) ||
            _isAdminBranchManager);

    if (!hasEditAccess) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('แก้ไขสาขา'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                _currentUser == null
                    ? 'กรุณาเข้าสู่ระบบ'
                    : 'การเข้าถึงถูกปฏิเสธ',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _currentUser == null
                      ? 'คุณต้องเข้าสู่ระบบเพื่อแก้ไขสาขา'
                      : 'เฉพาะ SuperAdmin หรือผู้จัดการสาขาสามารถแก้ไขสาขานี้ได้',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('ย้อนกลับ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            if (_currentUser!.userRole == UserRole.superAdmin) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFF10B981),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Color(0xFF10B981),
                  indicatorWeight: 3,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: [
                    Tab(
                        icon: Icon(Icons.info_outline, size: 20),
                        text: 'รายละเอียดสาขา'),
                    Tab(
                        icon: Icon(Icons.people_outline, size: 20),
                        text: 'ผู้จัดการ'),
                  ],
                ),
              ),
            ],
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF10B981), strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('กำลังอัปเดตสาขา...'),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: _currentUser!.userRole == UserRole.superAdmin
                          ? TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBranchInfoTab(),
                                _buildManagersTab(),
                              ],
                            )
                          : _buildBranchInfoTab(),
                    ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'แก้ไขสาขา',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'สำหรับแก้ไขสาขาในระบบ',
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
    );
  }

  Widget _buildBranchInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          SizedBox(height: 20),
          _buildBasicInfoSection(),
          SizedBox(height: 20),
          _buildDescriptionSection(),
          SizedBox(height: 20),
          _buildStatusSection(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildManagersTab() {
    // Similar to branch_add but shows existing managers
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
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
                      child: Icon(Icons.people_outline,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ผู้จัดการสาขา',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'แก้ไข',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('กรุณาเลือกผู้จัดการอย่างน้อยหนึ่งคน',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                if (_selectedManagerIds.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade600, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'เลือกผู้จัดการแล้ว ${_selectedManagerIds.length} ${_selectedManagerIds.length > 1 ? 'คน' : 'คน'} ',
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
          if (_isLoadingManagers)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              ),
            )
          else if (_adminUsers.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ไม่พบผู้จัดการ',
                            style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                          'คุณต้องมีผู้ดูแลระบบหรือผู้ดูแลระบบระดับสูงอย่างน้อย 1 คนในระบบ',
                          style: TextStyle(
                              color: Colors.red.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            _buildManagersList(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildManagersList() {
    return Column(
      children: _adminUsers.map((user) {
        final userId = user['user_id'];
        final isSelected = _selectedManagerIds.contains(userId);
        final isPrimary = _primaryManagerId == userId;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Color(0xFF10B981) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _toggleManagerSelection(userId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFF10B981) : Colors.white,
                      border: Border.all(
                        color:
                            isSelected ? Color(0xFF10B981) : Colors.grey[400]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  SizedBox(width: 14),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF10B981).withOpacity(0.1)
                          : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: isSelected ? Color(0xFF10B981) : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user['user_name'] ?? 'ไม่มีชื่อ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87),
                              ),
                            ),
                            if (isPrimary)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        size: 12, color: Colors.amber.shade700),
                                    SizedBox(width: 4),
                                    Text(
                                      'หลัก',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.amber.shade700,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${user['role'] == 'superadmin' ? 'SuperAdmin' : 'Admin'} • ${user['user_email'] ?? 'No Email'}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected && !isPrimary)
                    IconButton(
                      icon: Icon(Icons.star_border, color: Colors.grey[400]),
                      onPressed: () => _setPrimaryManager(userId),
                      tooltip: 'ตั้งเป็นผู้จัดการหลัก',
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
                child: Icon(Icons.image_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'รูปภาพสาขา',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_hasSelectedImage())
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _imageChanged
                        ? Colors.blue.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _imageChanged ? 'อัปเดต' : 'ปัจจุบัน',
                    style: TextStyle(
                      fontSize: 11,
                      color: _imageChanged
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (_hasSelectedImage()) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImagePreview(),
              ),
            ),
            if (_selectedImageName != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file,
                        size: 18, color: Colors.grey[600]),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedImageName!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _getImageSizeText(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.swap_horiz, size: 18),
                    label: Text('เปลี่ยน'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF10B981),
                      side: BorderSide(color: Color(0xFF10B981)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeImage,
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('ลบ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      kIsWeb ? Icons.upload_file : Icons.add_photo_alternate,
                      size: 48,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(height: 12),
                    Text(
                      kIsWeb ? 'อัปโหลดรูปภาพ' : 'เลือกภาพสาขา',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      kIsWeb
                          ? 'คลิกเพื่อเลือกไฟล์จากคอมพิวเตอร์'
                          : 'คลิกเพื่อเลือกภาพจากแกลอรี่หรือกล้อง',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'JPG, PNG, WebP (Max 5MB)',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasSelectedImage() {
    return _selectedImage != null ||
        _selectedImageBytes != null ||
        _currentImageUrl != null;
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _selectedImageBytes != null) {
      return Image.memory(_selectedImageBytes!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(_selectedImage!,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (_currentImageUrl != null) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: Center(
              child: Icon(Icons.image_not_supported_outlined,
                  size: 48, color: Colors.grey[400])),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF10B981),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }
    return Container(
      color: Colors.grey[200],
      child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 48, color: Colors.grey[400])),
    );
  }

  String _getImageSizeText() {
    if (_selectedImageBytes != null) {
      final sizeInMB = _selectedImageBytes!.length / (1024 * 1024);
      return '${sizeInMB.toStringAsFixed(1)} MB';
    }
    return '';
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
                child: Icon(Icons.business_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'ข้อมูลพื้นฐานสาขา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchCodeController,
            decoration: InputDecoration(
              labelText: 'รหัสสาขา *',
              prefixIcon: Icon(Icons.qr_code, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกรหัสสาขา';
              }
              if (value.trim().length < 3) {
                return 'รหัสสาขาต้องมีอย่างน้อย 3 ตัวอักษร';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchNameController,
            decoration: InputDecoration(
              labelText: 'ชื่อสาขา *',
              prefixIcon: Icon(Icons.store, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกชื่อสาขา';
              }
              if (value.trim().length < 2) {
                return 'ชื่อสาขาต้องมีอย่างน้อย 2 ตัวอักษร';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchPhoneController,
            decoration: InputDecoration(
              labelText: 'หมายเลขโทรศัพท์',
              prefixIcon: Icon(Icons.phone, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[0-9\-\(\)\s]+').hasMatch(value)) {
                  return 'รูปแบบหมายเลขโทรศัพท์ไม่ถูกต้อง';
                }
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchAddressController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'ที่อยู่',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.location_on, size: 20),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
                'รายละเอียดเพิ่มเติม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchDescController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'รายละเอียด',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
                child: Icon(Icons.settings_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text('การตั้งค่าสถานะ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isActive ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _isActive
                      ? Colors.green.shade200
                      : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _isActive ? Icons.check_circle : Icons.cancel,
                  color: _isActive
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: _isActive
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _isActive
                            ? 'สาขาแสดงอยู่และใช้งานได้'
                            : 'สาขาถูกซ่อนจากระบบ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isActive
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeColor: Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final bool canSave = !_isLoading && !_isLoadingManagers;
    final bool isSuperAdmin = _currentUser?.userRole == UserRole.superAdmin;

    if (!isSuperAdmin) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -2)),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: canSave ? _updateBranch : null,
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Icon(Icons.save, color: Colors.white, size: 18),
            label: Text(
              _isLoading ? 'กำลังอัปเดต...' : 'อัปเดตสาขา',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? Color(0xFF10B981) : Colors.grey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: canSave ? 2 : 0,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          if (_currentTabIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _tabController.animateTo(_currentTabIndex - 1),
                icon: Icon(Icons.arrow_back, size: 18),
                label: Text('ก่อนหน้า'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF10B981),
                  side: BorderSide(color: Color(0xFF10B981)),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (_currentTabIndex > 0) SizedBox(width: 12),
          Expanded(
            flex: _currentTabIndex == 0 ? 1 : 2,
            child: _currentTabIndex < 1
                ? ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _tabController.animateTo(_currentTabIndex + 1),
                    icon: Icon(Icons.arrow_forward,
                        color: Colors.white, size: 18),
                    label: Text('ถัดไป',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: canSave ? _updateBranch : null,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white)),
                          )
                        : Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                      _isLoading ? 'กำลังอัปเดต...' : 'อัปเดตสาขา',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canSave ? Color(0xFF10B981) : Colors.grey,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: canSave ? 2 : 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
