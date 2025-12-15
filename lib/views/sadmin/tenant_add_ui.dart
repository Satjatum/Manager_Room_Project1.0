import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Models //
import '../../models/user_models.dart';
// Services //
import '../../services/auth_service.dart';
import '../../services/tenant_service.dart';
import '../../services/room_service.dart';
import '../../services/image_service.dart';
import '../../services/user_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

class TenantAddUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const TenantAddUI({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<TenantAddUI> createState() => _TenantAddUIState();
}

class _TenantAddUIState extends State<TenantAddUI>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Tab Controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Tenant form controllers
  final _tenantIdCardController = TextEditingController();
  final _tenantFullNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();

  // User account controllers
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController();

  // Contract controllers
  final _contractNumController = TextEditingController();
  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _contractNotesController = TextEditingController();

  String? _selectedGender;
  String? _selectedBranchId;
  String? _selectedRoomId;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  int _paymentDay = 1;
  bool _contractPaid = true;
  bool _isActive = true;
  bool _createUserAccount = true;
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  bool _showPassword = false;

  List<Map<String, dynamic>> _availableRooms = [];

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  String? _documentName;
  Uint8List? _documentBytes;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _generateContractNumber();

    if (widget.branchId != null) {
      _selectedBranchId = widget.branchId;
    }

    _initializePageData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tenantIdCardController.dispose();
    _tenantFullNameController.dispose();
    _tenantPhoneController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _contractNumController.dispose();
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _contractNotesController.dispose();
    super.dispose();
  }

  void _generateContractNumber() {
    final now = DateTime.now();
    final random = Random();
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    _contractNumController.text =
        'CT${now.year}${now.month.toString().padLeft(2, '0')}$randomNum';
  }

  Future<void> _initializePageData() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await _loadDropdownData();

      if (widget.branchId != null) {
        await _loadAvailableRooms(widget.branchId!);
      }
    }
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('ไม่สามารถโหลดข้อมูลผู้ใช้ได้: $e');
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadDropdownData() async {
    if (_currentUser == null) return;
    try {
      if (mounted) {
        setState(() {});

        if (_selectedBranchId != null) {
          await _loadAvailableRooms(_selectedBranchId!);
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    }
  }

  Future<void> _loadAvailableRooms(String branchId) async {
    try {
      final rooms = await RoomService.getAllRooms(
        branchId: branchId,
        roomStatus: 'available',
        isActive: true,
      );

      if (mounted) {
        setState(() {
          _availableRooms = rooms;
          _selectedRoomId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูลห้องได้: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูลห้องได้');
      }
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
          _documentName = file.name;
          _documentBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        debugPrint('เกิดข้อผิดพลาดในการเลือกไฟล์: $e');
        SnackMessage.showError(
          context,
          'เกิดข้อผิดพลาดในการเลือกไฟล์',
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      if (kIsWeb) {
        await _pickImagesForWeb();
      } else {
        await _pickImagesForMobile();
      }
    } catch (e) {
      if (mounted) {
        debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
        SnackMessage.showError(
          context,
          'เกิดข้อผิดพลาดในการเลือกรูปภาพ',
        );
      }
    }
  }

  Future<void> _pickImagesForWeb() async {
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
        });
      }
    }
  }

  Future<void> _pickImagesForMobile() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'เลือกรูปภาพโปรไฟล์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        label: 'ถ่ายรูป',
                        source: ImageSource.camera,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageSourceOption(
                        icon: Icons.photo_library,
                        label: 'แกลเลอรี่',
                        source: ImageSource.gallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        });
      }
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          debugPrint('ขนาดไฟล์เกิน 5MB');
          SnackMessage.showError(context, 'ขนาดไฟล์เกิน 5MB ');
        }
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          debugPrint('ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น');
          SnackMessage.showError(
            context,
            'ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          debugPrint('ขนาดไฟล์เกิน 5MB');
          SnackMessage.showError(context, 'ขนาดไฟล์เกิน 5MB ');
        }
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          debugPrint('ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น');
          SnackMessage.showError(
            context,
            'ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return words[0][0].toUpperCase();
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_contractStartDate ?? DateTime.now())
          : (_contractEndDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime.now(),
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
          _contractStartDate = picked;
          if (_contractEndDate == null) {
            _contractEndDate = picked.add(const Duration(days: 365));
          }
        } else {
          _contractEndDate = picked;
        }
      });
    }
  }

  // Validation ก่อนบันทึก
  bool _validateCurrentTab() {
    if (_currentTabIndex == 0) {
      // Tab ข้อมูลผู้เช่า
      if (_tenantIdCardController.text.trim().isEmpty) {
        debugPrint('กรุณากรอกเลขบัตรประชาชน');
        SnackMessage.showError(context, 'กรุณากรอกเลขบัตรประชาชน');

        return false;
      }
      if (_tenantFullNameController.text.trim().isEmpty) {
        debugPrint('กรุณากรอกชื่อ-นามสกุล');
        SnackMessage.showError(context, 'กรุณากรอกชื่อ-นามสกุล');

        return false;
      }
      if (_tenantPhoneController.text.trim().isEmpty) {
        debugPrint('กรุณากรอกเบอร์โทรศัพท์');
        SnackMessage.showError(context, 'กรุณากรอกเบอร์โทรศัพท์');

        return false;
      }
      if (_selectedBranchId == null) {
        debugPrint('กรุณาเลือกสาขา');
        SnackMessage.showError(context, 'กรุณาเลือกสาขา');

        return false;
      }
    } else if (_currentTabIndex == 1) {
      // Tab บัญชีผู้ใช้
      if (_createUserAccount) {
        if (_userNameController.text.trim().isEmpty) {
          debugPrint('กรุณากรอกชื่อผู้ใช้');
          SnackMessage.showError(context, 'กรุณากรอกชื่อผู้ใช้');

          return false;
        }
        if (_userEmailController.text.trim().isEmpty) {
          debugPrint('กรุณากรอกอีเมล');
          SnackMessage.showError(context, 'กรุณากรอกอีเมล');

          return false;
        }
        final password = _userPasswordController.text.trim();
        if (password.isEmpty) {
          debugPrint('กรุณากรอกรหัสผ่าน');
          SnackMessage.showError(context, 'กรุณากรอกรหัสผ่าน');

          return false;
        }
        if (password.length < 6) {
          debugPrint('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
          SnackMessage.showError(context, 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');

          return false;
        }
        if (!password.contains(RegExp(r'[a-z]'))) {
          debugPrint('รหัสผ่านควรมีตัวอักษรพิมพ์เล็ก');
          SnackMessage.showError(context, 'รหัสผ่านควรมีตัวอักษรพิมพ์เล็ก');

          return false;
        }
        if (!password.contains(RegExp(r'[A-Z]'))) {
          debugPrint('รหัสผ่านควรมีตัวอักษรพิมพ์ใหญ่');
          SnackMessage.showError(context, 'รหัสผ่านควรมีตัวอักษรพิมพ์ใหญ่');

          return false;
        }
        if (!password.contains(RegExp(r'[0-9]'))) {
          debugPrint('รหัสผ่านควรมีตัวเลข');
          SnackMessage.showError(context, 'รหัสผ่านควรมีตัวเลข');

          return false;
        }
      }
    } else if (_currentTabIndex == 2) {
      // Tab สัญญาเช่า
      if (_selectedRoomId == null) {
        debugPrint('กรุณาเลือกห้องเช่า');
        SnackMessage.showError(context, 'กรุณาเลือกห้องเช่า');
        return false;
      }
      if (_contractStartDate == null || _contractEndDate == null) {
        debugPrint('กรุณาระบุวันที่เริ่มต้นและสิ้นสุดสัญญา');
        SnackMessage.showError(
            context, 'กรุณาระบุวันที่เริ่มต้นและสิ้นสุดสัญญา');
        return false;
      }
      if (_contractEndDate!.isBefore(_contractStartDate!)) {
        debugPrint('วันที่สิ้นสุดสัญญาต้องมาหลังวันที่เริ่มต้น');
        SnackMessage.showError(
            context, 'วันที่สิ้นสุดสัญญาต้องมาหลังวันที่เริ่มต้น');
        return false;
      }
      if (_contractPriceController.text.trim().isEmpty) {
        debugPrint('กรุณากรอกค่าเช่า');
        SnackMessage.showError(context, 'กรุณากรอกค่าเช่า');
        return false;
      }
      if (_contractDepositController.text.trim().isEmpty) {
        debugPrint('กรุณากรอกค่าประกัน');
        SnackMessage.showError(context, 'กรุณากรอกค่าประกัน');
        return false;
      }
    }

    return true;
  }

  void _nextTab() {
    if (_validateCurrentTab()) {
      if (_currentTabIndex < 2) {
        _tabController.animateTo(_currentTabIndex + 1);
      }
    }
  }

  void _previousTab() {
    if (_currentTabIndex > 0) {
      _tabController.animateTo(_currentTabIndex - 1);
    }
  }

  Future<void> _saveTenant() async {
    if (_currentUser == null) {
      debugPrint('กรุณาเข้าสู่ระบบก่อนเพิ่มผู้เช่า');
      SnackMessage.showError(context, 'กรุณาเข้าสู่ระบบก่อนเพิ่มผู้เช่า');
      Navigator.of(context).pop();
      return;
    }

    // Validate all tabs first to ensure required fields (including branch) are selected
    for (int i = 0; i <= 2; i++) {
      setState(() => _currentTabIndex = i);
      _tabController.animateTo(i);
      if (!_validateCurrentTab()) {
        return;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Permission pre-check: SuperAdmin/manageTenants OR Admin who manages selected branch
    bool allowed = _currentUser!.hasAnyPermission([
      DetailedPermission.all,
      DetailedPermission.manageTenants,
    ]);

    if (!allowed && _currentUser!.userRole == UserRole.admin) {
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
        allowed = await RoomService.isUserManagerOfBranch(
            _currentUser!.userId, _selectedBranchId!);
      }
    }

    if (!allowed) {
      debugPrint('คุณไม่มีสิทธิ์เพิ่มผู้เช่าในสาขานี้');
      SnackMessage.showError(context, 'คุณไม่มีสิทธิ์เพิ่มผู้เช่าในสาขานี้');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      String? userId;
      String? documentUrl; // เพิ่มตัวแปรสำหรับ URL เอกสาร

      // Upload profile image if selected
      // รูปแบบชื่อไฟล์: tenant_profile_YYYYMMDD_XXX
      if (_selectedImage != null || _selectedImageBytes != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('กำลังอัปโหลดรูปภาพ...'),
              ],
            ),
          ),
        );

        // ดึง extension ของไฟล์
        String extension = 'jpg';
        if (kIsWeb && _selectedImageName != null) {
          extension = path
              .extension(_selectedImageName!)
              .toLowerCase()
              .replaceAll('.', '');
        } else if (!kIsWeb && _selectedImage != null) {
          extension = path
              .extension(_selectedImage!.path)
              .toLowerCase()
              .replaceAll('.', '');
        }

        // สร้างชื่อไฟล์แบบ sequential: tenant_profile_YYYYMMDD_XXX
        final fileName = await ImageService.generateSequentialFileName(
          bucket: 'tenant-images',
          folder: 'profiles',
          prefix: 'tenant_profile',
          extension: extension,
        );

        dynamic uploadResult;
        if (kIsWeb && _selectedImageBytes != null) {
          // สร้าง path เต็ม
          final fullPath = 'profiles/$fileName';

          uploadResult =
              await _supabase.storage.from('tenant-images').uploadBinary(
                    fullPath,
                    _selectedImageBytes!,
                    fileOptions: FileOptions(
                      upsert: false,
                      contentType: 'image/$extension',
                    ),
                  );

          if (uploadResult != null) {
            imageUrl =
                _supabase.storage.from('tenant-images').getPublicUrl(fullPath);
          }
        } else if (!kIsWeb && _selectedImage != null) {
          // สร้าง path เต็ม
          final fullPath = 'profiles/$fileName';

          final fileBytes = await _selectedImage!.readAsBytes();
          uploadResult =
              await _supabase.storage.from('tenant-images').uploadBinary(
                    fullPath,
                    fileBytes,
                    fileOptions: FileOptions(
                      upsert: false,
                      contentType: 'image/$extension',
                    ),
                  );

          if (uploadResult != null) {
            imageUrl =
                _supabase.storage.from('tenant-images').getPublicUrl(fullPath);
          }
        }

        if (mounted) Navigator.of(context).pop();

        if (imageUrl == null) {
          throw Exception('ไม่สามารถอัปโหลดรูปภาพได้');
        }
      }

      // Upload contract document if selected
      // รูปแบบชื่อไฟล์: contracts_YYYYMMDD_ชื่อผู้เช่า_XXX
      // Bucket: contracts
      if (_documentBytes != null && _documentName != null) {
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

          // ดึงชื่อผู้เช่า (ใช้เฉพาะชื่อแรก เพื่อไม่ให้ชื่อไฟล์ยาวเกินไป)
          final tenantName =
              _tenantFullNameController.text.trim().split(' ').first;

          // สร้างชื่อไฟล์แบบ sequential: contracts_YYYYMMDD_ชื่อผู้เช่า_XXX
          final now = DateTime.now();
          final dateStr =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

          // หาเลขลำดับถัดไป
          final files = await _supabase.storage.from('contracts').list();
          int maxSeq = 0;
          final pattern = RegExp(
              '^contracts_\${dateStr}_\${RegExp.escape(tenantName)}_\\d{3}\\.\${RegExp.escape(extension)}\$');

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
          final fileName = 'contracts_${dateStr}_${tenantName}_${nextSeq}.pdf';

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
          debugPrint('ไม่สามารถอัปโหลดเอกสารได้: $e');
          throw Exception('ไม่สามารถอัปโหลดเอกสารได้: $e');
        }
      }

      // Create user account if requested
      if (_createUserAccount) {
        final userResult =
            await UserService.createTenantUserWithoutSessionHijack({
          'user_name': _userNameController.text.trim(),
          'user_email': _userEmailController.text.trim(),
          'user_pass': _userPasswordController.text,
          'role': 'tenant',
          'permissions': [
            'view_own_data',
            'create_issues',
            'view_invoices',
            'make_payments',
          ],
          'is_active': true,
        });

        if (!userResult['success']) {
          if (mounted) {
            setState(() => _isLoading = false);
            debugPrint(
                'ไม่สามารถสร้างบัญชีผู้ใช้ได้: ${userResult['message']}');
            SnackMessage.showError(context,
                'ไม่สามารถสร้างบัญชีผู้ใช้ได้: ${userResult['message']}');
            // ตรวจสอบว่าต้องให้ผู้ใช้ล็อกอินใหม่หรือไม่
            if (userResult['requireRelogin'] == true) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          }
          return;
        }

        // สร้าง user สำเร็จ และ admin session ยังคงอยู่
        debugPrint('สร้างบัญชีผู้ใช้สำเร็จ: ${userResult['message']}');
        userId = userResult['data']['user_id'];
      }

      // Create tenant
      final tenantData = {
        'branch_id': _selectedBranchId,
        'tenant_idcard': _tenantIdCardController.text.trim(),
        'tenant_fullname': _tenantFullNameController.text.trim(),
        'tenant_phone': _tenantPhoneController.text.trim(),
        'gender': _selectedGender,
        'tenant_profile': imageUrl,
        'is_active': _isActive,
        'user_id': userId,
      };

      debugPrint('📝 กำลังสร้างผู้เช่าด้วยข้อมูล: $tenantData');
      final tenantResult = await TenantService.createTenant(tenantData);

      if (!tenantResult['success']) {
        if (mounted) {
          setState(() => _isLoading = false);
          debugPrint('❌ สร้างผู้เช่าไม่สำเร็จ: ${tenantResult['message']}');
          SnackMessage.showError(
              context, 'เกิดข้อผิดพลาด: ${tenantResult['message']}');
        }
        return;
      }

      debugPrint('✅ สร้างผู้เช่าสำเร็จ: ${tenantResult['data']}');
      final tenantId = tenantResult['data']['tenant_id'];

      // Create rental contract
      final contractData = {
        'contract_num': _contractNumController.text.trim(),
        'room_id': _selectedRoomId,
        'tenant_id': tenantId,
        'start_date': _contractStartDate!.toIso8601String().split('T')[0],
        'end_date': _contractEndDate!.toIso8601String().split('T')[0],
        'contract_price':
            double.tryParse(_contractPriceController.text.trim()) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text.trim()) ?? 0,
        'contract_paid': _contractPaid,
        'payment_day': _paymentDay,
        'contract_status': 'active',
        'contract_note': _contractNotesController.text.trim().isEmpty
            ? null
            : _contractNotesController.text.trim(),
        'contract_document': documentUrl, // เพิ่ม URL เอกสาร
      };

      // Insert contract directly to database
      await _supabase
          .from('rental_contracts')
          .insert(contractData)
          .select()
          .single();

      // Update room status to occupied
      await _supabase
          .from('rooms')
          .update({'room_status': 'occupied'}).eq('room_id', _selectedRoomId!);

      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('สร้างผู้เช่าและสัญญาเช่าสำเร็จ'
            '${_createUserAccount ? ' พร้อมบัญชีผู้ใช้' : ''}');
        SnackMessage.showSuccess(
            context,
            'สร้างผู้เช่าและสัญญาเช่าสำเร็จ'
            '${_createUserAccount ? ' พร้อมบัญชีผู้ใช้' : ''}');

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('เกิดข้อผิดพลาด: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('กำลังตรวจสอบสิทธิ์...'),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'กรุณาเข้าสู่ระบบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถเพิ่มผู้เช่าได้',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('กลับ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text('กำลังบันทึกข้อมูล...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // ✅ ใช้หัวใหม่แทน AppBar
                  Padding(
                    padding: const EdgeInsets.all(24),
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
                                'เพิ่มข้อมูลผู้เช่า',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'สำหรับเพิ่มข้อมูลผู้เช่า',
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

                  // ✅ TabBar เหมือนเดิม
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF10B981),
                    tabs: const [
                      Tab(icon: Icon(Icons.person), text: 'ข้อมูลผู้เช่า'),
                      Tab(
                          icon: Icon(Icons.account_circle),
                          text: 'บัญชีผู้ใช้'),
                      Tab(icon: Icon(Icons.description), text: 'ข้อมูลสัญญา'),
                    ],
                  ),

                  // ✅ เนื้อหา TabBar + ปุ่มด้านล่างเหมือนเดิม
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildTenantInfoTab(),
                                _buildUserAccountTab(),
                                _buildContractTab(),
                              ],
                            ),
                          ),
                          _buildNavigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTenantInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileImageSection(),
          const SizedBox(height: 24),
          _buildTenantInfoSection(),
          const SizedBox(height: 24),
          _buildStatusSection(),
        ],
      ),
    );
  }

  Widget _buildUserAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserAccountSection(),
        ],
      ),
    );
  }

  Widget _buildContractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRoomSelectionSection(),
          const SizedBox(height: 24),
          _buildContractSection(),
          const SizedBox(height: 24),
          _buildContractDocumentSection(),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final hasImage = _selectedImage != null || _selectedImageBytes != null;
    final tenantName = _tenantFullNameController.text.trim();

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
                  child: Icon(Icons.image_outlined,
                      color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'รูปภาพผู้เช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: hasImage
                        ? ClipOval(child: _buildImagePreview())
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                tenantName.isNotEmpty
                                    ? _getInitials(tenantName)
                                    : 'T',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: Icon(
                            hasImage ? Icons.swap_horiz : Icons.add_a_photo),
                        label: Text(hasImage ? 'เปลี่ยนรูป' : 'เพิ่มรูปภาพ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.delete),
                          label: const Text('ลบรูป'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildTenantInfoSection() {
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
                  'ข้อมูลพื้นฐานผู้เช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // เลขบัตรประชาชน
            TextFormField(
              controller: _tenantIdCardController,
              decoration: InputDecoration(
                labelText: 'เลขบัตรประชาชน',
                prefixIcon: const Icon(Icons.credit_card),
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
              maxLength: 13,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกเลขบัตรประชาชน';
                }
                if (value.length != 13) {
                  return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ชื่อ-นามสกุล
            TextFormField(
              controller: _tenantFullNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อ-นามสกุล',
                prefixIcon: const Icon(Icons.person),
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
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อ-นามสกุล';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // เบอร์โทรศัพท์
            TextFormField(
              controller: _tenantPhoneController,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                prefixIcon: const Icon(Icons.phone),
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
              maxLength: 10,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกเบอร์โทรศัพท์';
                }
                if (value.length != 10) {
                  return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // เพศ
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'เพศ',
                prefixIcon: const Icon(Icons.wc),
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
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ชาย')),
                DropdownMenuItem(value: 'female', child: Text('หญิง')),
                DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAccountSection() {
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
                  child: Icon(Icons.account_circle_outlined,
                      color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'บัญชีผู้ใช้',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _createUserAccount,
                  onChanged: (value) {
                    setState(() {
                      _createUserAccount = value;
                      if (!value) {
                        _userNameController.clear();
                        _userEmailController.clear();
                        _userPasswordController.clear();
                      }
                    });
                  },
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _createUserAccount
                  ? 'สร้างบัญชีเพื่อให้ผู้เช่าสามารถเข้าสู่ระบบได้'
                  : 'ไม่สร้างบัญชีผู้ใช้ (เฉพาะข้อมูลผู้เช่า)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            if (_createUserAccount) ...[
              const SizedBox(height: 16),

              // ชื่อผู้ใช้
              TextFormField(
                controller: _userNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  prefixIcon: const Icon(Icons.person_outline),
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
                validator: _createUserAccount
                    ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }
                        if (value.length < 4) {
                          return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 4 ตัวอักษร';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 16),

              // อีเมล
              TextFormField(
                controller: _userEmailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: const Icon(Icons.email),
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
                keyboardType: TextInputType.emailAddress,
                validator: _createUserAccount
                    ? (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 16),

              // รหัสผ่าน
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _userPasswordController,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xff10B981), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    obscureText: !_showPassword,
                    validator: _createUserAccount
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            }
                            if (value.length < 6) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                            }
                            // ตรวจสอบว่ามีตัวพิมพ์เล็ก
                            if (!value.contains(RegExp(r'[a-z]'))) {
                              return 'รหัสผ่านควรมีตัวอักษรพิมพ์เล็ก';
                            }
                            // ตรวจสอบว่ามีตัวพิมพ์ใหญ่
                            if (!value.contains(RegExp(r'[A-Z]'))) {
                              return 'รหัสผ่านควรมีตัวอักษรพิมพ์ใหญ่';
                            }
                            // ตรวจสอบว่ามีตัวเลข
                            if (!value.contains(RegExp(r'[0-9]'))) {
                              return 'รหัสผ่านควรมีตัวเลข';
                            }
                            return null;
                          }
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue[200]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร และควรมีตัวอักษรพิมพ์ใหญ่ พิมพ์เล็ก และตัวเลขผสมกัน',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSelectionSection() {
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
            if (_selectedBranchId == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'กรุณาเลือกสาขาก่อนเพื่อดูห้องว่าง',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedBranchId != null) ...[
              DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                value: _selectedRoomId,
                decoration: InputDecoration(
                  labelText: 'ห้องพัก',
                  prefixIcon: const Icon(Icons.hotel),
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
                onChanged: (value) {
                  setState(() {
                    _selectedRoomId = value;
                    if (value != null) {
                      final selectedRoom = _availableRooms.firstWhere(
                        (room) => room['room_id'] == value,
                        orElse: () => {},
                      );
                      if (selectedRoom.isNotEmpty) {
                        _contractPriceController.text =
                            selectedRoom['room_price']?.toString() ?? '';
                        _contractDepositController.text =
                            selectedRoom['room_deposit']?.toString() ?? '';
                      }
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณาเลือกห้องพัก';
                  }
                  return null;
                },
              ),
              if (_availableRooms.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ไม่มีห้องว่างในสาขานี้',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
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
                  _contractStartDate != null
                      ? '${_contractStartDate!.day}/${_contractStartDate!.month}/${_contractStartDate!.year + 543}'
                      : 'เลือกวันที่',
                  style: TextStyle(
                    color: _contractStartDate != null
                        ? Colors.black87
                        : Colors.grey[600],
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
                  _contractEndDate != null
                      ? '${_contractEndDate!.day}/${_contractEndDate!.month}/${_contractEndDate!.year + 543}'
                      : 'เลือกวันที่',
                  style: TextStyle(
                    color: _contractEndDate != null
                        ? Colors.black87
                        : Colors.grey[600],
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
                labelText: 'วันครบกำหนดชำระ',
                prefixIcon: const Icon(
                  Icons.calendar_today,
                ),
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
              controller: _contractNotesController,
              decoration: InputDecoration(
                labelText: 'หมายเหตุเพิ่มเติม',
                hintText: 'เพิ่มหมายเหตุเกี่ยวกับสัญญาเช่า (ถ้ามี)',
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
          ],
        ),
      ),
    );
  }

  Widget _buildContractDocumentSection() {
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
              onPressed: _pickDocument,
              label: Text(
                _documentName ?? 'อัปโหลดเอกสารสัญญา',
                style: TextStyle(
                  color: Colors.black,
                ),
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
                      onPressed: () {
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

  Widget _buildStatusSection() {
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
                  child: Icon(Icons.settings_outlined,
                      color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  'สถานะผู้เช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isActive ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isActive
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
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
                              ? 'ผู้เช่านี้จะแสดงในรายการผู้ใช้ทั่วไป'
                              : 'ผู้เช่านี้จะไม่แสดงในรายการผู้ใช้ทั่วไป',
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
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentTabIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousTab,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                ),
                label: const Text('ย้อนกลับ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (_currentTabIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentTabIndex == 0 ? 1 : 2,
            child: ElevatedButton.icon(
              onPressed: _currentTabIndex < 2 ? _nextTab : _saveTenant,
              label: Text(
                _currentTabIndex < 2 ? 'ถัดไป' : 'บันทึก',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
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
}
