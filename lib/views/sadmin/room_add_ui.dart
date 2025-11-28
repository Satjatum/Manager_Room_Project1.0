import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
// Models //
import '../../models/user_models.dart';
// Middleware //
import '../../middleware/auth_middleware.dart';
// Services //
import '../../services/room_service.dart';
import '../../services/image_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

class _DraftImage {
  final File? file;
  final Uint8List? bytes;
  final String name;
  bool isPrimary;

  _DraftImage(
      {this.file, this.bytes, required this.name, this.isPrimary = false});
}

class RoomAddUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const RoomAddUI({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<RoomAddUI> createState() => _RoomAddUIState();
}

class _RoomAddUIState extends State<RoomAddUI> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _roomNumberController = TextEditingController();
  final _roomSizeController = TextEditingController();
  final _roomPriceController = TextEditingController();
  final _roomDepositController = TextEditingController();
  final _roomDescController = TextEditingController();

  String? _selectedBranchId;
  String? _selectedRoomTypeId;
  String? _selectedRoomCategoryId;
  String _selectedRoomStatus = 'available';
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isCheckingAuth = true;

  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _roomCategories = [];
  List<Map<String, dynamic>> _amenities = [];
  List<String> _selectedAmenities = [];
  List<_DraftImage> _images = [];

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _initializePageData();
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomSizeController.dispose();
    _roomPriceController.dispose();
    _roomDepositController.dispose();
    _roomDescController.dispose();
    super.dispose();
  }

  Future<void> _initializePageData() async {
    await _loadCurrentUser();
    if (_currentUser != null) {
      await _loadDropdownData();
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
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      SnackMessage.showError(
        context,
        'เกิดข้อผิดพลาดในการโหลดข้อมูล',
      );
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _loadDropdownData() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingData = true);

    try {
      final String? effectiveBranchId =
          _selectedBranchId ?? _currentUser?.branchId;
      final roomTypes =
          await RoomService.getRoomTypes(branchId: effectiveBranchId);
      final roomCategories =
          await RoomService.getRoomCategories(branchId: effectiveBranchId);
      final amenities =
          await RoomService.getAmenities(branchId: effectiveBranchId);

      if (mounted) {
        setState(() {
          _roomTypes = roomTypes;
          _roomCategories = roomCategories;
          _amenities = amenities;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
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
        print('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการเลือกรูปภาพ');
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
      if (_images.length >= 5) return;
      final bytes = await image.readAsBytes();
      final name = image.name;
      if (await _validateImageBytesForWeb(bytes, name)) {
        setState(() {
          _images.add(_DraftImage(
              bytes: bytes, name: name, isPrimary: _images.isEmpty));
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
                  'เลือกรูปภาพห้องพัก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'ถ่ายรูป',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            Navigator.pop(context, ImageSource.gallery),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                size: 40,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'แกลเลอรี่',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
    if (source == ImageSource.gallery) {
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        for (final img in images) {
          if (_images.length >= 5) break;
          final f = File(img.path);
          if (await _validateImageFile(f)) {
            _images.add(_DraftImage(
                file: f, name: img.name, isPrimary: _images.isEmpty));
          }
        }
        if (mounted) setState(() {});
      }
    } else {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        if (_images.length >= 5) return;
        final file = File(image.path);
        if (await _validateImageFile(file)) {
          setState(() {
            _images.add(_DraftImage(
                file: file, name: image.name, isPrimary: _images.isEmpty));
          });
        }
      }
    }
  }

  Future<bool> _validateImageBytesForWeb(
      Uint8List bytes, String fileName) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          print('ขนาดไฟล์เกิน 5MB');
          SnackMessage.showError(context, 'ขนาดไฟล์เกิน 5MB ');
        }
        return false;
      }

      if (bytes.isEmpty) {
        if (mounted) {
          print('ไฟว่างเปล่าหรือเสียหาย');
          SnackMessage.showError(context, 'ไฟว่างเปล่าหรือเสียหาย');
        }
        return false;
      }

      final extension = fileName.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          print('ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น');
          SnackMessage.showError(
            context,
            'ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        print('เกิดข้อผิดพลาดในการตรวจสอบไฟล์: $e');
        SnackMessage.showError(
          context,
          'เกิดข้อผิดพลาดในการตรวจสอบไฟล์',
        );
      }
      return false;
    }
  }

  Future<bool> _validateImageFile(File file) async {
    try {
      if (!await file.exists()) {
        if (mounted) {
          print('ไม่พบไฟล์หรือไฟล์ถูกลบ');
          SnackMessage.showError(
            context,
            'ไม่พบไฟล์หรือไฟล์ถูกลบ',
          );
        }
        return false;
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          print('ขนาดไฟล์เกิน 5MB');
          SnackMessage.showError(
            context,
            'ขนาดไฟล์เกิน 5MB',
          );
        }
        return false;
      }

      if (fileSize == 0) {
        if (mounted) {
          print('ไฟล์ว่างเปล่าหรือเสียหาย');
          SnackMessage.showError(
            context,
            'ไฟล์ว่างเปล่าหรือเสียหาย',
          );
        }
        return false;
      }

      final extension = file.path.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          print('ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น');
          SnackMessage.showError(
            context,
            'ไฟล์ที่อนุญาต: JPG, JPEG, PNG, WebP เท่านั้น',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        print('เกิดข้อผิดพลาดในการตรวจสอบไฟล์: $e');
        SnackMessage.showError(
          context,
          'เกิดข้อผิดพลาดในการตรวจสอบไฟล์',
        );
      }
      return false;
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _images.length) return;
    final removedPrimary = _images[index].isPrimary;
    setState(() {
      _images.removeAt(index);
      if (removedPrimary && _images.isNotEmpty) {
        for (final img in _images) img.isPrimary = false;
        _images.first.isPrimary = true;
      }
    });
  }

  Future<void> _saveRoom() async {
    if (_currentUser == null) {
      print('กรุณาเข้าสู่ระบบเพื่อเพิ่มห้อง');
      SnackMessage.showError(
        context,
        'กรุณาเข้าสู่ระบบเพื่อเพิ่มห้อง',
      );

      Navigator.of(context).pop();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roomData = {
        'branch_id': _selectedBranchId,
        'room_number': _roomNumberController.text.trim(),
        'room_type_id': _selectedRoomTypeId,
        'room_category_id': _selectedRoomCategoryId,
        'room_size': _roomSizeController.text.trim().isEmpty
            ? null
            : double.tryParse(_roomSizeController.text.trim()),
        'room_price': double.tryParse(_roomPriceController.text.trim()) ?? 0,
        'room_deposit':
            double.tryParse(_roomDepositController.text.trim()) ?? 0,
        'room_status': _selectedRoomStatus,
        'room_desc': _roomDescController.text.trim().isEmpty
            ? null
            : _roomDescController.text.trim(),
        'is_active': _isActive,
      };

      final result = await RoomService.createRoom(roomData);

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          // บันทึก amenities ถ้ามีการเลือก (ต้องระบุ branch_id ด้วย)
          if (_selectedAmenities.isNotEmpty && result['data'] != null) {
            final roomId = result['data']['room_id'];
            final String? effectiveBranchId = _selectedBranchId ??
                result['data']['branch_id'] ??
                _currentUser?.branchId;
            try {
              for (String amenityId in _selectedAmenities) {
                await _supabase.from('room_amenities').insert({
                  'room_id': roomId,
                  'amenity_id': amenityId,
                  'branch_id': effectiveBranchId,
                });
              }
            } catch (e) {
              print('เกิดข้อผิดพลาดในการบันทึกสิ่งอำนวยความสะดวก: $e');
              SnackMessage.showError(
                  context, 'เกิดข้อผิดพลาดในการบันทึกสิ่งอำนวยความสะดวก');
            }
          }

          if (_images.isNotEmpty && result['data'] != null) {
            final roomId = result['data']['room_id'];
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text('กำลังอัปโหลดรูปภาพ...'),
                  ],
                ),
              ),
            );

            String _safe(String? s) {
              final v = (s ?? '').trim();
              return v
                  .replaceAll(RegExp(r"[\\/:*?\<>|]"), '')
                  .replaceAll(RegExp(r"\s+"), '');
            }

            String roomCateLabel = '';
            try {
              final matched = _roomCategories.firstWhere(
                (c) => c['roomcate_id'] == _selectedRoomCategoryId,
                orElse: () => {},
              );
              if (matched.isNotEmpty) {
                roomCateLabel = matched['roomcate_name'] ?? '';
              }
            } catch (_) {}
            if (roomCateLabel.isEmpty) {
              roomCateLabel = _selectedRoomCategoryId ?? 'room';
            }
            final roomNum = _roomNumberController.text;
            final prefix = _safe(roomCateLabel) + _safe(roomNum);

            try {
              for (int i = 0; i < _images.length; i++) {
                final item = _images[i];
                final ext = item.name.split('.').last.toLowerCase();
                String customName;
                try {
                  customName = await ImageService.generateSequentialFileName(
                    bucket: 'room-images',
                    folder: 'rooms',
                    prefix: prefix,
                    extension: ext,
                  );
                } catch (_) {
                  final d = DateTime.now();
                  final y = d.year.toString();
                  final m = d.month.toString().padLeft(2, '0');
                  final day = d.day.toString().padLeft(2, '0');
                  customName =
                      '${prefix}_${y}${m}${day}_${(i + 1).toString().padLeft(3, '0')}.$ext';
                }

                Map<String, dynamic>? uploadResult;
                if (item.bytes != null) {
                  uploadResult = await ImageService.uploadImageFromBytes(
                    item.bytes!,
                    item.name,
                    'room-images',
                    folder: 'rooms',
                    customFileName: customName,
                  );
                } else if (item.file != null) {
                  uploadResult = await ImageService.uploadImage(
                    item.file!,
                    'room-images',
                    folder: 'rooms',
                    customFileName: customName,
                  );
                }

                if (uploadResult != null && uploadResult['success'] == true) {
                  await _supabase.from('room_images').insert({
                    'room_id': roomId,
                    'image_url': uploadResult['url'],
                    'is_primary': item.isPrimary,
                    'display_order': i,
                  });
                }
              }
            } finally {
              if (mounted) Navigator.of(context).pop();
            }
          }

          print(
            result['message'] +
                (_selectedAmenities.isNotEmpty
                    ? ' พร้อมสิ่งอำนวยความสะดวก ${_selectedAmenities.length} รายการ'
                    : ''),
          );
          SnackMessage.showSuccess(
            context,
            result['message'] +
                (_selectedAmenities.isNotEmpty
                    ? ' พร้อมสิ่งอำนวยความสะดวก ${_selectedAmenities.length} รายการ'
                    : ''),
          );
          Navigator.of(context).pop(true);
        } else {
          print(result['message']);
          SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('เกิดข้อผิดพลาด: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading/auth states use the same clean header style as branch_add_ui
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text('กำลังตรวจสอบสิทธิ์...'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildCustomHeader(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'กรุณาเข้าสู่ระบบ',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถเพิ่มห้องพักได้',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('กลับ'),
                      ),
                    ],
                  ),
                ),
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
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          SizedBox(height: 16),
                          Text('กำลังบันทึกข้อมูล...'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageSection(),
                            const SizedBox(height: 20),
                            _buildBasicInfoSection(),
                            const SizedBox(height: 20),
                            _buildPriceSection(),
                            const SizedBox(height: 20),
                            _buildRoomDetailsSection(),
                            const SizedBox(height: 20),
                            _buildAmenitiesSection(),
                            const SizedBox(height: 20),
                            _buildDescriptionSection(),
                            const SizedBox(height: 20),
                            _buildStatusSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
            _buildBottomBar(),
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
                  'เพิ่มห้องพัก',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'สำหรับเพิ่มห้องพัก',
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

  Widget _buildBottomBar() {
    final bool canSave = !_isLoading && !_isLoadingData;
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canSave ? _saveRoom : null,
          icon: _isLoading
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
            _isLoading ? 'กำลังบันทึก...' : 'บันทึก',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSave ? AppTheme.primary : Colors.grey,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: canSave ? 2 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final hasImage = _images.isNotEmpty;

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
                child: Icon(Icons.image_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'รูปภาพห้องพัก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              if (kIsWeb)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'WEB',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (hasImage)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'รูปพร้อมแล้ว',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasImage) ...[
            SizedBox(
              height: 240,
              child: ReorderableListView.builder(
                itemCount: _images.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _images.removeAt(oldIndex);
                    _images.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final img = _images[index];
                  return ListTile(
                    key: ValueKey('img_$index'),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: img.bytes != null
                            ? Image.memory(img.bytes!, fit: BoxFit.cover)
                            : Image.file(img.file!, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(
                      img.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            img.isPrimary ? Icons.star : Icons.star_border,
                            color: img.isPrimary ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              for (final i in _images) i.isPrimary = false;
                              img.isPrimary = true;
                            });
                          },
                          tooltip: 'ตั้งเป็นรูปหลัก',
                        ),
                        const SizedBox(width: 8),
                        Text('ลำดับ ${index + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeImageAt(index),
                      tooltip: 'ลบ',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _images.length < 5 ? _pickImages : null,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(
                        _images.length < 5 ? 'เพิ่มรูปภาพ' : 'ครบ 5 รูปแล้ว'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      kIsWeb ? Icons.upload_file : Icons.add_photo_alternate,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      kIsWeb
                          ? 'เลือกไฟล์รูปภาพ'
                          : 'เลือกรูปภาพห้องพัก (สูงสุด 5 รูป)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kIsWeb
                          ? 'คลิกเพื่อเลือกไฟล์จากคอมพิวเตอร์'
                          : 'คลิกเพื่อเลือกหลายรูปจากแกลเลอรี่หรือถ่ายรูปใหม่',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'JPG, PNG, WebP (Max 5MB)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade600,
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

  Widget _buildBasicInfoSection() {
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
                child: Icon(Icons.business_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'ข้อมูลพื้นฐานห้องพัก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _roomNumberController,
            decoration: InputDecoration(
              labelText: 'หมายเลขห้องพัก',
              prefixIcon: const Icon(Icons.room),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกหมายเลขห้อง';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: _selectedRoomCategoryId,
            decoration: InputDecoration(
              labelText: 'หมวดหมู่ห้องพัก',
              prefixIcon: const Icon(Icons.keyboard_arrow_down),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
            items: _roomCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category['roomcate_id'],
                child: Text(category['roomcate_name'] ?? ''),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoomCategoryId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: _selectedRoomTypeId,
            decoration: InputDecoration(
              labelText: 'ประเภทห้องพัก',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
            items: _roomTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['roomtype_id'],
                child: Text(type['roomtype_name'] ?? ''),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoomTypeId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _roomSizeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ขนาดห้องพัก',
              prefixIcon: const Icon(Icons.aspect_ratio),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
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
                child: Icon(Icons.payment_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'ข้อมูลราคา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _roomPriceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ค่าเช่า',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
          TextFormField(
            controller: _roomDepositController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ค่าประกัน',
              prefixIcon: const Icon(Icons.security),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );
  }

  Widget _buildAmenitiesSection() {
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
                child: Icon(Icons.star_outline,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'สิ่งอำนวยความสะดวก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_amenities.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  const Text(
                    'ไม่มีรายการสิ่งอำนวยความสะดวก',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _amenities.map((amenity) {
                final amenityId = amenity['amenities_id'] as String;
                final isSelected = _selectedAmenities.contains(amenityId);

                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (amenity['amenities_icon'] != null) ...[
                        Icon(
                          _getIconData(amenity['amenities_icon']),
                          size: 16,
                          color: isSelected ? Colors.white : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        amenity['amenities_name'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAmenities.add(amenityId);
                      } else {
                        _selectedAmenities.remove(amenityId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          if (_selectedAmenities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'เลือกแล้ว ${_selectedAmenities.length} รายการ',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedAmenities.length > 3) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAmenities.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ล้างทั้งหมด',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

// Helper method สำหรับแปลง string เป็น IconData
  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.star;

    switch (iconName) {
      case 'ac_unit':
        return Icons.ac_unit;
      case 'air':
        return Icons.air;
      case 'bed':
        return Icons.bed;
      case 'door_sliding':
        return Icons.door_sliding;
      case 'desk':
        return Icons.desk;
      case 'water_heater':
        return Icons.water_drop;
      case 'wifi':
        return Icons.wifi;
      case 'local_parking':
        return Icons.local_parking;
      case 'videocam':
        return Icons.videocam;
      case 'credit_card':
        return Icons.credit_card;
      default:
        return Icons.star;
    }
  }

  Widget _buildRoomDetailsSection() {
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
                child: Icon(Icons.settings_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'สถานะห้องพัก',
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
            value: _selectedRoomStatus,
            decoration: InputDecoration(
              labelText: 'สถานะห้องพัก',
              prefixIcon: const Icon(Icons.info),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
              DropdownMenuItem(value: 'available', child: Text('ว่าง')),
              DropdownMenuItem(value: 'occupied', child: Text('มีผู้เช่า')),
              DropdownMenuItem(value: 'maintenance', child: Text('ซ่อมบำรุง')),
              DropdownMenuItem(value: 'reserved', child: Text('จอง')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRoomStatus = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
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
                'รายละเอียดเพิ่มเติม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _roomDescController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'รายละเอียดห้องพัก',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
          ),
        ],
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
                'สถานะห้องพัก',
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
                            ? 'ห้องพักนี้จะไม่แสดงในรายการผู้ใช้ทั่วไป'
                            : 'ห้องพักนี้จะแสดงในรายการผู้ใช้ทั่วไป',
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
}
