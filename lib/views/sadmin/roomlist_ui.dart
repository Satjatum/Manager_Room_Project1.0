import 'package:flutter/material.dart';
// Models //
import '../../models/user_models.dart';
// Middleware //
import '../../middleware/auth_middleware.dart';
// Services //
import '../../services/room_service.dart';
// Page //
import 'room_add_ui.dart';
import 'room_edit_ui.dart';
import 'roomlist_detail_ui.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

class RoomListUi extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  final bool hideBottomNav;

  const RoomListUi({
    Key? key,
    this.branchId,
    this.branchName,
    this.hideBottomNav = false,
  }) : super(key: key);

  @override
  State<RoomListUi> createState() => _RoomListUiState();
}

class _RoomListUiState extends State<RoomListUi> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _roomCategories = [];
  Map<String, List<Map<String, dynamic>>> _roomAmenities = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedRoomStatusFilter = 'all';
  String? _selectedRoomTypeId;
  String? _selectedRoomCategoryId;
  String? _selectedBranchId;
  UserModel? _currentUser;
  bool _isAnonymous = false;
  bool _canAddRoom = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isAnonymous = user == null;
      });
      await _refreshAddPermission();
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await RoomService.getBranchesForRoomFilter();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการโหลดสาขา: $e');
    }
    await _loadTypeAndCategoryFilters();
    _loadRooms();
  }

  Future<void> _loadTypeAndCategoryFilters() async {
    try {
      final types = await RoomService.getRoomTypes(branchId: _selectedBranchId);
      final cates =
          await RoomService.getRoomCategories(branchId: _selectedBranchId);
      if (mounted) {
        setState(() {
          _roomTypes = types;
          _roomCategories = cates;
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการโหลดฟิลเตอร์: $e');
    }
  }

  Future<void> _loadRooms() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> rooms;

      if (_isAnonymous) {
        rooms = await RoomService.getActiveRooms(branchId: _selectedBranchId);
      } else if (_currentUser!.userRole == UserRole.superAdmin) {
        rooms = await RoomService.getAllRooms(
          branchId: _selectedBranchId,
          isActive:
              _selectedStatus == 'all' ? null : _selectedStatus == 'active',
        );
      } else {
        rooms = await RoomService.getRoomsByUser(branchId: _selectedBranchId);
      }

      Map<String, List<Map<String, dynamic>>> amenitiesMap = {};
      for (var room in rooms) {
        try {
          final amenities = await RoomService.getRoomAmenities(room['room_id']);
          amenitiesMap[room['room_id']] = amenities;
        } catch (e) {
          debugPrint(
              'ไม่สามารถโหลดสิ่งอำนวยความสะดวกของห้องได้ ${room['room_id']}: $e');
          amenitiesMap[room['room_id']] = [];
        }
      }

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _roomAmenities = amenitiesMap;
          _isLoading = false;
        });
        // Apply current filters to rooms
        _filterRooms();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _rooms = [];
          _filteredRooms = [];
          _roomAmenities = {};
        });

        debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterRooms();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _loadRooms();
  }

  void _onRoomStatusFilterChanged(String? status) {
    setState(() {
      _selectedRoomStatusFilter = status ?? 'all';
    });
    _filterRooms();
  }

  void _filterRooms() {
    if (!mounted) return;
    setState(() {
      _filteredRooms = _rooms.where((room) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (room['room_number'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['branch_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['room_type_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (room['room_category_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            ('เลขที่').toString().toLowerCase().contains(searchTerm);

        final matchesStatus = _selectedRoomStatusFilter == 'all' ||
            (room['room_status'] ?? 'unknown') == _selectedRoomStatusFilter;

        final matchesType = _selectedRoomTypeId == null ||
            (room['room_type_id']?.toString() ?? '') == _selectedRoomTypeId;

        final matchesCategory = _selectedRoomCategoryId == null ||
            (room['room_category_id']?.toString() ?? '') ==
                _selectedRoomCategoryId;

        final matchesActive = _selectedStatus == 'all'
            ? true
            : ((_selectedStatus == 'active')
                ? (room['is_active'] == true)
                : (room['is_active'] == false));

        return matchesSearch &&
            matchesStatus &&
            matchesType &&
            matchesCategory &&
            matchesActive;
      }).toList();
    });
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.login, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('ต้องเข้าสู่ระบบ'),
          ],
        ),
        content: Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRoomStatus(
      String roomId, String roomNumber, bool currentActive) async {
    final room = _rooms.firstWhere(
      (r) => (r['room_id']?.toString() ?? '') == roomId.toString(),
      orElse: () => const {},
    );
    final categoryName = (room['room_category_name'] ?? '').toString();

    if (_isAnonymous) {
      _showLoginPrompt(
          "เปลี่ยนสถานะ ${categoryName.isNotEmpty ? categoryName : 'ห้อง $roomNumber'}");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: currentActive
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  currentActive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: currentActive
                      ? Colors.orange.shade600
                      : Colors.green.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),

              // Title
              Text(
                currentActive ? 'ปิดใช้งานหรือไม่?' : 'เปิดใช้งานหรือไม่?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),

              // Room label
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.meeting_room, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$categoryNameเลขที่ $roomNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Info Box
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: currentActive
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: currentActive
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentActive
                          ? Icons.warning_rounded
                          : Icons.info_rounded,
                      color: currentActive
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentActive
                            ? '$categoryNameนี้จะไม่แสดงในรายการผู้ใช้ทั่วไป'
                            : '$categoryNameนี้จะแสดงในรายการผู้ใช้ทั่วไป',
                        style: TextStyle(
                          color: currentActive
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentActive
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: currentActive
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: currentActive
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          currentActive
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: currentActive
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    currentActive
                        ? 'กำลังปิดใช้งาน$categoryName'
                        : 'กำลังเปิดใช้งาน$categoryName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await RoomService.toggleRoomStatus(roomId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            debugPrint(result['message']);
            SnackMessage.showSuccess(context, result['message']);

            await _loadRooms();
          } else {
            debugPrint("เกิดข้อผิดพลาด {$result['message']}");
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          debugPrint('เกิดข้อผิดพลาด: $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
        }
      }
    }
  }

  Future<void> _deleteRoom(String roomId, String roomNumber) async {
    final room = _rooms.firstWhere(
      (r) => (r['room_id']?.toString() ?? '') == roomId.toString(),
      orElse: () => const {},
    );
    final categoryName = (room['room_category_name'] ?? '').toString();

    if (_isAnonymous) {
      _showLoginPrompt(
          "ยืนยันการลบ ${categoryName.isNotEmpty ? categoryName : 'ห้อง $roomNumber'}");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              // Title
              Text(
                'ลบ$categoryNameหรือไม่?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              // Room Name
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.meeting_room, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$categoryNameเลขที่ $roomNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Warning Box
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ข้อมูลทั้งหมดจะถูกลบถาวร',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ลบ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: Colors.red.shade600,
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.red.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'ลบ$categoryNameเลขที่ $roomNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await RoomService.deleteRoom(roomId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            debugPrint(result['message']);
            SnackMessage.showSuccess(context, result['message']);
            await _loadRooms();
          } else {
            debugPrint("$result['message']");
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        // if (mounted && Navigator.of(context).canPop()) {
        //   Navigator.of(context).pop();
        // }

        if (mounted) {
          debugPrint('เกิดข้อผิดพลาด: $e');
          SnackMessage.showError(context,
              ' ไม่สามารถลบห้องพักได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง');
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'reserved':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'ว่าง';
      case 'occupied':
        return 'มีผู้เช่า';
      case 'maintenance':
        return 'ซ่อมบำรุง';
      case 'reserved':
        return 'จอง';
      default:
        return 'ไม่ทราบ';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'occupied':
        return Icons.person;
      case 'maintenance':
        return Icons.build;
      case 'reserved':
        return Icons.event;
      default:
        return Icons.help;
    }
  }

  IconData _getAmenityIcon(String? iconName) {
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
      case 'water_drop':
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

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin);

  Future<void> _refreshAddPermission() async {
    if (!mounted) return;
    bool allowed = false;
    if (!_isAnonymous) {
      if (_currentUser?.userRole == UserRole.superAdmin) {
        allowed = true;
      } else if (_currentUser?.userRole == UserRole.admin &&
          _selectedBranchId != null &&
          _selectedBranchId!.isNotEmpty) {
        allowed = await RoomService.isUserManagerOfBranch(
            _currentUser!.userId, _selectedBranchId!);
      }
    }
    if (mounted) {
      setState(() {
        _canAddRoom = allowed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section (match branchlist_ui) + Back Arrow
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    tooltip: 'ย้อนกลับ',
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'จัดการห้องพัก',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับจัดการห้องพัก',
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

            // Search and Filters in a single horizontal row (scrollable)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'ค้นหา',
                        hintStyle:
                            TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[600], size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey[600], size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Filltter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------- Row 1: สถานะการใช้งาน + สถานะห้อง ----------------
                  Row(
                    children: [
                      // สถานะการใช้งาน
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.power_settings_new,
                                  size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: Colors.white,
                                    value: _selectedStatus,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    onChanged: (val) {
                                      _onStatusChanged(val);
                                      _filterRooms();
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'all', child: Text('ทั้งหมด')),
                                      DropdownMenuItem(
                                          value: 'active',
                                          child: Text('เปิดใช้งาน')),
                                      DropdownMenuItem(
                                          value: 'inactive',
                                          child: Text('ปิดใช้งาน')),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // สถานะห้อง
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: Colors.white,
                                    value: _selectedRoomStatusFilter,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    onChanged: _onRoomStatusFilterChanged,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'all', child: Text('ทั้งหมด')),
                                      DropdownMenuItem(
                                          value: 'available',
                                          child: Text('ห้องว่าง')),
                                      DropdownMenuItem(
                                          value: 'occupied',
                                          child: Text('มีผู้เช่า')),
                                      DropdownMenuItem(
                                          value: 'maintenance',
                                          child: Text('ซ่อมบำรุง')),
                                      DropdownMenuItem(
                                          value: 'reserved',
                                          child: Text('จอง')),
                                      DropdownMenuItem(
                                          value: 'unknown',
                                          child: Text('ไม่ทราบ')),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ---------------- Row 2: หมวดหมู่ห้อง + ประเภทห้อง ----------------
                  Row(
                    children: [
                      // หมวดหมู่ห้อง
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.grid_view_rounded,
                                  size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: Colors.white,
                                    value: _selectedRoomCategoryId ?? 'all',
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedRoomCategoryId =
                                            val == 'all' ? null : val;
                                      });
                                      _filterRooms();
                                    },
                                    items: [
                                      const DropdownMenuItem(
                                          value: 'all', child: Text('ทั้งหมด')),
                                      ..._roomCategories.map((c) =>
                                          DropdownMenuItem<String>(
                                            value: c['roomcate_id']?.toString(),
                                            child:
                                                Text(c['roomcate_name'] ?? ''),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ประเภทห้อง
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category_outlined,
                                  size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: Colors.white,
                                    value: _selectedRoomTypeId ?? 'all',
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedRoomTypeId =
                                            val == 'all' ? null : val;
                                      });
                                      _filterRooms();
                                    },
                                    items: [
                                      const DropdownMenuItem(
                                          value: 'all', child: Text('ทั้งหมด')),
                                      ..._roomTypes.map((t) =>
                                          DropdownMenuItem<String>(
                                            value: t['roomtype_id']?.toString(),
                                            child:
                                                Text(t['roomtype_name'] ?? ''),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Active status

            SizedBox(height: 16),

            // Results Count
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Showing ${_filteredRooms.length} of ${_rooms.length} rooms',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          SizedBox(height: 16),
                          Text('กำลังโหลดข้อมูล...'),
                        ],
                      ),
                    )
                  : _filteredRooms.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadRooms,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: _filteredRooms.length,
                            itemBuilder: (context, index) {
                              final room = _filteredRooms[index];
                              return _buildRoomCard(room, _canManage);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canAddRoom
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomAddUI(
                      branchId: _selectedBranchId,
                      branchName: _selectedBranchId != null
                          ? _branches.firstWhere(
                              (b) => b['branch_id'] == _selectedBranchId,
                              orElse: () => {},
                            )['branch_name']
                          : null,
                    ),
                  ),
                );

                if (result == true) {
                  await _loadRooms();
                }
              },
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'ไม่พบห้องที่ค้นหา' : 'ยังไม่มีห้องพัก',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                : _canAddRoom
                    ? 'เริ่มต้นโดยการเพิ่มห้องพักแรก'
                    : 'ไม่มีห้องพักในสาขานี้',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (_searchQuery.isEmpty && _canAddRoom)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomAddUI(
                        branchId: _selectedBranchId,
                        branchName: _selectedBranchId != null
                            ? _branches.firstWhere(
                                (b) => b['branch_id'] == _selectedBranchId,
                                orElse: () => {},
                              )['branch_name']
                            : null,
                      ),
                    ),
                  );

                  if (result == true) {
                    await _loadRooms();
                  }
                },
                icon: Icon(Icons.add),
                label: Text('เพิ่มห้องใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, bool canManage) {
    final isActive = room['is_active'] ?? false;
    final status = room['room_status'] ?? 'available';
    final statusColor = _getStatusColor(status);
    final roomId = room['room_id'];
    final amenities = _roomAmenities[roomId] ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Define responsive breakpoints
        final double width = MediaQuery.of(context).size.width;
        final bool isTablet = width >= 768 && width < 1024;
        final bool isLaptop = width >= 1024 && width < 1440;
        final bool isLaptopL = width >= 1440 && width < 2560;
        final bool is4K = width >= 2560;

        // Responsive sizing values
        double cardMargin = 16.0;
        double cardPadding = 16.0;
        double iconSize = 16.0;
        double titleFontSize = 16.0;
        double subtitleFontSize = 13.0;
        double chipFontSize = 12.0;
        double bodyFontSize = 13.0;
        double amenityIconSize = 12.0;
        double amenityFontSize = 11.0;
        double spacing = 10.0;
        int maxAmenitiesShow = 3;

        // Determine if the screen is tablet-sized or larger
        final bool isLargeScreen = isTablet || isLaptop || isLaptopL || is4K;

        if (isLargeScreen) {
          // On tablet and larger devices, reduce padding and spacing slightly
          // to prevent cards from looking oversized relative to their content.
          cardMargin = 16.0;
          cardPadding = 14.0; // was 18.0
          iconSize = 18.0;
          titleFontSize = 17.0;
          subtitleFontSize = 14.0;
          chipFontSize = 13.0;
          bodyFontSize = 14.0;
          amenityIconSize = 13.0;
          amenityFontSize = 12.0;
          spacing = 10.0; // was 12.0
          maxAmenitiesShow = 3;
        }

        return Card(
          margin: EdgeInsets.only(bottom: cardMargin),
          elevation: 0,
          color: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomListDetailUi(
                    roomId: room['room_id'],
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: title + 3-dots menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${room['room_category_name']}เลขที่ ${room['room_number'] ?? 'ไม่ระบุ'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (room['branch_name'] != null)
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  room['branch_name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 4),
                      _buildRoomMenu(room, canManage, isActive),
                    ],
                  ),

                  SizedBox(height: spacing),

                  // Chips: status + active/inactive
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: spacing, vertical: spacing * 0.6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(status),
                                size: iconSize * 0.88, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              _getStatusText(status),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: chipFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: spacing, vertical: spacing * 0.6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF10B981)
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: chipFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (room['room_type_name'] != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: spacing, vertical: spacing * 0.6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room['room_type_name'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: chipFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: spacing * 1.2),

                  // Room Info (Size & Price)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: spacing * 1.6,
                        runSpacing: spacing * 0.8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (room['room_size'] != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.aspect_ratio,
                                    size: iconSize, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                  '${room['room_size']} ตร.ม.',
                                  style: TextStyle(
                                      fontSize: bodyFontSize,
                                      color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payments,
                                  size: iconSize, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                '${room['room_price'] ?? 0} บาท/เดือน',
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.security,
                                  size: iconSize, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                'ค่ามัดจำ: ${room['room_deposit'] ?? 0} บาท',
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Room Description
                  if (room['room_desc'] != null &&
                      room['room_desc'].toString().trim().isNotEmpty) ...[
                    SizedBox(height: spacing * 1.2),
                    Container(
                      padding: EdgeInsets.all(spacing * 1.2),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.description,
                              size: iconSize, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              room['room_desc'],
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                              // On tablet and larger, restrict the description to a few lines
                              // to reduce card height; otherwise show full description.
                              maxLines: isLargeScreen ? 4 : null,
                              overflow:
                                  isLargeScreen ? TextOverflow.ellipsis : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Amenities Section
                  if (amenities.isNotEmpty) ...[
                    SizedBox(height: spacing * 1.2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars,
                                size: iconSize * 0.88,
                                color: Colors.amber[700]),
                            SizedBox(width: 4),
                            Text(
                              'สิ่งอำนวยความสะดวก',
                              style: TextStyle(
                                fontSize: chipFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing * 0.8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              amenities.take(maxAmenitiesShow).map((amenity) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing * 0.8,
                                vertical: spacing * 0.4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF14B8A6).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFF14B8A6).withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getAmenityIcon(amenity['amenities_icon']),
                                    size: amenityIconSize,
                                    color: Color(0xFF14B8A6),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    amenity['amenities_name'] ?? '',
                                    style: TextStyle(
                                      fontSize: amenityFontSize,
                                      color: Color(0xFF14B8A6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        if (amenities.length > maxAmenitiesShow)
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '+${amenities.length - maxAmenitiesShow} เพิ่มเติม',
                              style: TextStyle(
                                fontSize: amenityFontSize,
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomMenu(
      Map<String, dynamic> room, bool canManage, bool isActive) {
    return PopupMenuButton<String>(
      color: Colors.white,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: const [
              Icon(Icons.visibility_outlined,
                  size: 20, color: Color(0xFF14B8A6)),
              SizedBox(width: 12),
              Text('ดูรายละเอียด'),
            ],
          ),
        ),
        if (canManage)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit_outlined, size: 20, color: Color(0xFF14B8A6)),
                SizedBox(width: 12),
                Text('แก้ไข'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'toggle_status',
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: isActive ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 12),
              Text(
                isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                style: TextStyle(
                  color: isActive ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ),
        if (_currentUser?.userRole == UserRole.superAdmin)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text('ลบ', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'view':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoomListDetailUi(
                  roomId: room['room_id'],
                ),
              ),
            );
            break;
          case 'edit':
            if (canManage) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomEditUI(
                    roomId: room['room_id'],
                  ),
                ),
              );
              if (result == true) _loadRooms();
            }
            break;
          case 'toggle_status':
            _toggleRoomStatus(
              room['room_id'],
              room['room_number'] ?? '',
              isActive,
            );
            break;
          case 'delete':
            if (_currentUser?.userRole == UserRole.superAdmin) {
              _deleteRoom(
                room['room_id'],
                room['room_number'] ?? '',
              );
            }
            break;
        }
      },
    );
  }
}
