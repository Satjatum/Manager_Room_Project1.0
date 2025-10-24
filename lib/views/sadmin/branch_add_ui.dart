import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/branch_service.dart';
import '../../services/user_service.dart';
import '../../services/image_service.dart';
import '../../services/branch_manager_service.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../widgets/colors.dart';

class BranchAddPage extends StatefulWidget {
  const BranchAddPage({Key? key}) : super(key: key);

  @override
  State<BranchAddPage> createState() => _BranchAddPageState();
}

class _BranchAddPageState extends State<BranchAddPage>
    with SingleTickerProviderStateMixin {
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

  String? _branchImageUrl;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingOwners = false;
  bool _isCheckingAuth = true;

  List<Map<String, dynamic>> _adminUsers = [];
  UserModel? _currentUser;

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
      await _loadAdminUsers();
    }
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
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
      print('Error loading current user: $e');
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadAdminUsers() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingOwners = true);

    try {
      final users = await UserService.getAdminUsers();
      if (mounted) {
        setState(() {
          _adminUsers = users;
          _isLoadingOwners = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOwners = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to load admin users: $e')),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _toggleManagerSelection(String userId) {
    setState(() {
      if (_selectedManagerIds.contains(userId)) {
        _selectedManagerIds.remove(userId);
        if (_primaryManagerId == userId) {
          _primaryManagerId = null;
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
                Expanded(child: Text('Error selecting image: $e')),
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
                    Text(
                      'Select Branch Image',
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
                                  Text('Camera',
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
                                  Text('Gallery',
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
                        child: Text('Cancel',
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
        });
      }
    }
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size exceeds 5MB'),
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
              content: Text('File is empty or corrupted'),
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
              content: Text('Only JPG, JPEG, PNG, WebP files are allowed'),
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
            content: Text('Failed to validate file: $e'),
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
              content: Text('File not found or deleted'),
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
              content: Text('File size exceeds 5MB'),
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
              content: Text('File is empty or corrupted'),
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
              content: Text('Only JPG, JPEG, PNG, WebP files are allowed'),
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
            content: Text('Failed to validate file: $e'),
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
      _branchImageUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Image removed'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveBranch() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to add a branch'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (_currentUser!.userRole != UserRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You do not have permission to add branches'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedManagerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one manager'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _tabController.animateTo(1);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
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
                  Text('Uploading image...'),
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
          imageUrl = uploadResult['url'];
        } else {
          throw Exception(uploadResult?['message'] ?? 'Failed to upload image');
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

      final branchResult = await BranchService.createBranch(branchData);

      if (!branchResult['success']) {
        throw Exception(branchResult['message']);
      }

      final branchId = branchResult['data']['branch_id'];

      for (String managerId in _selectedManagerIds) {
        final managerResult = await BranchManagerService.addBranchManager(
          branchId: branchId,
          userId: managerId,
          isPrimary: managerId == _primaryManagerId,
        );

        if (!managerResult['success']) {
          print(
              'Warning: Failed to add manager $managerId: ${managerResult['message']}');
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Branch created successfully')),
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

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Add New Branch'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 3),
              SizedBox(height: 16),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null || _currentUser!.userRole != UserRole.superAdmin) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Add New Branch'),
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
                _currentUser == null ? 'Please log in' : 'Access Denied',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _currentUser == null
                      ? 'You need to log in to add branches'
                      : 'Only SuperAdmin can add new branches',
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
                child: Text('Go Back'),
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
            // Custom Header
            _buildCustomHeader(),

            // Tabs
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
                      text: 'Branch Info'),
                  Tab(
                      icon: Icon(Icons.people_outline, size: 20),
                      text: 'Managers'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF10B981), strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('Saving branch...'),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBranchInfoTab(),
                          _buildManagersTab(),
                        ],
                      ),
                    ),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Branch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Create a new branch location',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                        'Branch Managers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Select at least 1 manager (can select multiple)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
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
                          '${_selectedManagerIds.length} manager${_selectedManagerIds.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
          if (_isLoadingOwners)
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
                        Text(
                          'No managers found',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You need at least one Admin or SuperAdmin in the system',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 13,
                          ),
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
                                user['user_name'] ?? 'No Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
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
                                      'Primary',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.amber.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${user['role'] == 'superadmin' ? 'SuperAdmin' : 'Admin'} • ${user['user_email'] ?? 'No Email'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected && !isPrimary)
                    IconButton(
                      icon: Icon(Icons.star_border, color: Colors.grey[400]),
                      onPressed: () => _setPrimaryManager(userId),
                      tooltip: 'Set as primary manager',
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
                  'Branch Image',
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
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ready',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
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
                    label: Text('Change'),
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
                    label: Text('Remove'),
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
                      kIsWeb ? 'Upload Image' : 'Select Branch Image',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      kIsWeb
                          ? 'Click to select file from computer'
                          : 'Click to select from gallery or camera',
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
                          fontWeight: FontWeight.w500,
                        ),
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
    return _selectedImage != null || _selectedImageBytes != null;
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 48, color: Colors.grey[400]),
      ),
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
                'Basic Information',
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
              labelText: 'Branch Code *',
              hintText: 'e.g., BKK-01, CNX-01',
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
                return 'Please enter branch code';
              }
              if (value.trim().length < 3) {
                return 'Branch code must be at least 3 characters';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchNameController,
            decoration: InputDecoration(
              labelText: 'Branch Name *',
              hintText: 'e.g., Bangkok Central, Chiang Mai Branch',
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
                return 'Please enter branch name';
              }
              if (value.trim().length < 2) {
                return 'Branch name must be at least 2 characters';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _branchPhoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g., 02-123-4567 or 081-234-5678',
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
              helperText: 'Branch contact number (optional)',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[0-9\-\(\)\s]+').hasMatch(value)) {
                  return 'Invalid phone number format';
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
              labelText: 'Address',
              hintText: 'Enter branch address...',
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
                'Additional Details',
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
              labelText: 'Description',
              hintText:
                  'Enter branch description, highlights, or additional information...',
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
              Text(
                'Status Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isActive ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _isActive ? Colors.green.shade200 : Colors.orange.shade200,
              ),
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
                        _isActive ? 'Active' : 'Inactive',
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
                            ? 'Branch will be visible and operational'
                            : 'Branch will be hidden from the system',
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
    final canSave = !_isLoading && _adminUsers.isNotEmpty && !_isLoadingOwners;

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
      child: Row(
        children: [
          if (_currentTabIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _tabController.animateTo(_currentTabIndex - 1),
                icon: Icon(Icons.arrow_back, size: 18),
                label: Text('Previous'),
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
                    label: Text(
                      'Next',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: canSave ? _saveBranch : null,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                      _isLoading ? 'Saving...' : 'Create Branch',
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
