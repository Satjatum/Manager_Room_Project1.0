import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/amenities_ui.dart';
import 'package:manager_room_project/views/sadmin/room_add_ui.dart';
import 'package:manager_room_project/views/sadmin/room_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/roomcate_ui.dart';
import 'package:manager_room_project/views/sadmin/roomlist_detail_ui.dart';
import 'package:manager_room_project/views/sadmin/roomtype_ui.dart';
// เพิ่ม import หน้าจัดการข้อมูลพื้นฐาน

import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/room_service.dart';
import '../widgets/colors.dart';

class RoomListUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  final bool hideBottomNav;

  const RoomListUI({
    Key? key,
    this.branchId,
    this.branchName,
    this.hideBottomNav = false,
  }) : super(key: key);

  @override
  State<RoomListUI> createState() => _RoomListUIState();
}

class _RoomListUIState extends State<RoomListUI> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  List<Map<String, dynamic>> _branches = [];
  Map<String, List<Map<String, dynamic>>> _roomAmenities = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedRoomStatusFilter = 'all';
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
      print('Error loading branches: $e');
    }
    _loadRooms();
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
          print('Error loading amenities for room ${room['room_id']}: $e');
          amenitiesMap[room['room_id']] = [];
        }
      }

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _filteredRooms = _rooms;
          _roomAmenities = amenitiesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _rooms = [];
          _filteredRooms = [];
          _roomAmenities = {};
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadRooms,
            ),
          ),
        );
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

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
    });
    _refreshAddPermission();
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

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  String _getActiveFiltersText() {
    List<String> filters = [];

    if (_selectedBranchId != null) {
      final branch = _branches.firstWhere(
        (b) => b['branch_id'] == _selectedBranchId,
        orElse: () => {},
      );
      if (branch.isNotEmpty) {
        filters.add('สาขา: ${branch['branch_name']}');
      }
    }

    if (_selectedStatus != 'all') {
      filters.add(_selectedStatus == 'active' ? 'เปิดใช้งาน' : 'ปิดใช้งาน');
    }

    if (_selectedRoomStatusFilter != 'all') {
      filters.add('สถานะ: ${_getStatusText(_selectedRoomStatusFilter)}');
    }

    if (_searchQuery.isNotEmpty) {
      filters.add('ค้นหา: "$_searchQuery"');
    }

    return filters.isEmpty ? 'แสดงทั้งหมด' : filters.join(' • ');
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

  // ฟังก์ชันแสดงเมนูจัดการข้อมูลพื้นฐาน
  void _showMasterDataMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
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
            SizedBox(height: 20),
            Text(
              'จัดการข้อมูลพื้นฐาน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.category_outlined,
              title: 'จัดการประเภทห้อง',
              subtitle: 'ห้องพัดลม, ห้องแอร์, Studio',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomTypesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.grid_view_outlined,
              title: 'จัดการหมวดหมู่ห้อง',
              subtitle: 'ห้องเดี่ยว, ห้องคู่, ห้องครอบครัว',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomCategoriesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            Divider(height: 1),
            _buildMasterDataMenuItem(
              icon: Icons.stars_outlined,
              title: 'จัดการสิ่งอำนวยความสะดวก',
              subtitle: 'แอร์, WiFi, ตู้เสื้อผ้า, ที่จอดรถ',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AmenitiesUI(),
                  ),
                ).then((_) => _loadRooms());
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterDataMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Future<void> _toggleRoomStatus(
      String roomId, String roomNumber, bool currentActive) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะห้อง');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
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
                currentActive ? 'ปิดใช้งานห้อง?' : 'เปิดใช้งานห้อง?',
                style: TextStyle(
                  fontSize: 22,
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
                        'Room $roomNumber',
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
                            ? 'ห้องนี้จะไม่แสดงในรายการสำหรับผู้ใช้ทั่วไปและไม่สามารถถูกจองได้'
                            : 'ห้องนี้จะแสดงในรายการสำหรับผู้ใช้ทั่วไปและสามารถถูกจองได้',
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
                          Icon(
                            currentActive
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          SizedBox(width: 8),
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
                        ? 'กำลังปิดใช้งานห้อง'
                        : 'กำลังเปิดใช้งานห้อง',
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await _loadRooms();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRoom(String roomId, String roomNumber) async {
    if (_isAnonymous) {
      _showLoginPrompt('ลบห้อง');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
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
                'Delete Room?',
                style: TextStyle(
                  fontSize: 22,
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
                        'Room $roomNumber',
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
                        'การดำเนินการนี้ไม่สามารถย้อนกลับได้\nข้อมูลทั้งหมดจะถูกลบอย่างถาวร',
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
                        'Cancel',
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
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
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
                    'Deleting Room',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait a moment...',
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await _loadRooms();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
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
    final String? lockedBranchId =
        (widget.branchId != null && widget.branchId!.trim().isNotEmpty)
            ? widget.branchId
            : null;

    Future<bool> _confirmExitBranch() async {
      if (lockedBranchId == null) return true;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการออกจากสาขา'),
          content: const Text('คุณต้องการกลับไปหน้าเลือกสาขาหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      }
      return false;
    }

    return WillPopScope(
      onWillPop: _confirmExitBranch,
      child: Scaffold(
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
                      icon:
                          Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                      onPressed: () async {
                        if (lockedBranchId != null) {
                          await _confirmExitBranch();
                        } else if (Navigator.of(context).canPop()) {
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
                            'Room Management',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your rooms and details',
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
                          hintText: 'Search',
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Active status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list,
                                size: 20, color: Colors.grey[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  icon:
                                      Icon(Icons.keyboard_arrow_down, size: 20),
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                  onChanged: _onStatusChanged,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'all', child: Text('All')),
                                    DropdownMenuItem(
                                        value: 'active', child: Text('Active')),
                                    DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text('Inactive')),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_branches.isNotEmpty && widget.branchId == null) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 20, color: Colors.grey[700]),
                              SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedBranchId ?? 'all',
                                    isExpanded: true,
                                    icon: Icon(Icons.keyboard_arrow_down,
                                        size: 20),
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text('ทุกสาขา'),
                                      ),
                                      ..._branches.map((branch) {
                                        return DropdownMenuItem<String>(
                                          value: branch['branch_id'] as String,
                                          child:
                                              Text(branch['branch_name'] ?? ''),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) {
                                      _onBranchChanged(
                                          value == 'all' ? null : value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    // Room status
                    SizedBox(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hotel_class_rounded,
                                size: 20, color: Colors.grey[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRoomStatusFilter,
                                  isExpanded: true,
                                  icon:
                                      Icon(Icons.keyboard_arrow_down, size: 20),
                                  style: TextStyle(
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
                                        value: 'reserved', child: Text('จอง')),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;

                                // Responsive Grid Columns based on screen width
                                int cols = 1;
                                double horizontalPadding = 24;
                                double crossSpacing = 12;
                                double mainSpacing = 12;

                                // Breakpoints for responsive columns
                                if (width >= 2560) {
                                  // 4K screens - 5 columns
                                  cols = 5;
                                  horizontalPadding = 32;
                                  crossSpacing = 16;
                                  mainSpacing = 16;
                                } else if (width >= 1440) {
                                  // Laptop L - 4 columns
                                  cols = 4;
                                  horizontalPadding = 28;
                                  crossSpacing = 14;
                                  mainSpacing = 14;
                                } else if (width >= 1024) {
                                  // Laptop - 3 columns
                                  cols = 3;
                                  horizontalPadding = 24;
                                  crossSpacing = 12;
                                  mainSpacing = 12;
                                } else if (width >= 768) {
                                  // Tablet - 2 columns
                                  cols = 2;
                                  horizontalPadding = 20;
                                  crossSpacing = 10;
                                  mainSpacing = 10;
                                }

                                // Mobile - use ListView
                                if (cols == 1) {
                                  return ListView.builder(
                                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                                    itemCount: _filteredRooms.length,
                                    itemBuilder: (context, index) {
                                      final room = _filteredRooms[index];
                                      return _buildRoomCard(room, _canManage);
                                    },
                                  );
                                }

                                // Calculate dynamic aspect ratio for grid
                                final double availableWidth = width -
                                    (horizontalPadding * 2) -
                                    (crossSpacing * (cols - 1));
                                final double tileWidth = availableWidth / cols;

                                // Responsive height estimation based on screen size
                                // เพิ่มความสูงการ์ดมากขึ้นเพื่อแก้ไข overflow
                                double estimatedTileHeight;

                                if (width >= 2560) {
                                  // 4K - larger cards
                                  estimatedTileHeight = tileWidth * 1.55;
                                } else if (width >= 1440) {
                                  // Laptop L - เพิ่มความสูงเพื่อแก้ 82px overflow
                                  estimatedTileHeight = tileWidth * 1.60;
                                } else if (width >= 1024) {
                                  // Laptop - เพิ่มความสูงเพื่อแก้ 67px overflow
                                  estimatedTileHeight = tileWidth * 1.58;
                                } else if (width >= 768) {
                                  // Tablet
                                  estimatedTileHeight = tileWidth * 1.50;
                                } else {
                                  // Fallback
                                  estimatedTileHeight = tileWidth * 1.50;
                                }

                                double dynamicAspect =
                                    tileWidth / estimatedTileHeight;
                                // ปรับ clamp range ให้รองรับการ์ดที่สูงขึ้นมาก
                                dynamicAspect = dynamicAspect.clamp(0.55, 0.85);

                                return GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      8,
                                      horizontalPadding,
                                      24),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: crossSpacing,
                                    mainAxisSpacing: mainSpacing,
                                    childAspectRatio: dynamicAspect,
                                  ),
                                  itemCount: _filteredRooms.length,
                                  itemBuilder: (context, index) {
                                    final room = _filteredRooms[index];
                                    return _buildRoomCard(room, _canManage);
                                  },
                                );
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
      ),
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
        final bool isNarrow = constraints.maxWidth < 420;

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
        int maxAmenitiesShow = 5;

        if (isTablet) {
          cardMargin = 18.0;
          cardPadding = 18.0;
          iconSize = 18.0;
          titleFontSize = 17.0;
          subtitleFontSize = 14.0;
          chipFontSize = 13.0;
          bodyFontSize = 14.0;
          amenityIconSize = 13.0;
          amenityFontSize = 12.0;
          spacing = 12.0;
          maxAmenitiesShow = 6;
        } else if (isLaptop) {
          cardMargin = 20.0;
          cardPadding = 20.0;
          iconSize = 20.0;
          titleFontSize = 18.0;
          subtitleFontSize = 15.0;
          chipFontSize = 14.0;
          bodyFontSize = 15.0;
          amenityIconSize = 14.0;
          amenityFontSize = 13.0;
          spacing = 14.0;
          maxAmenitiesShow = 5;
        } else if (isLaptopL) {
          cardMargin = 22.0;
          cardPadding = 22.0;
          iconSize = 22.0;
          titleFontSize = 20.0;
          subtitleFontSize = 16.0;
          chipFontSize = 15.0;
          bodyFontSize = 16.0;
          amenityIconSize = 15.0;
          amenityFontSize = 14.0;
          spacing = 16.0;
          maxAmenitiesShow = 3;
        } else if (is4K) {
          cardMargin = 24.0;
          cardPadding = 24.0;
          iconSize = 24.0;
          titleFontSize = 22.0;
          subtitleFontSize = 18.0;
          chipFontSize = 16.0;
          bodyFontSize = 18.0;
          amenityIconSize = 16.0;
          amenityFontSize = 15.0;
          spacing = 18.0;
          maxAmenitiesShow = 10;
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
                  builder: (context) => RoomDetailUI(
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
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: chipFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: spacing * 1.2),

                  Row(
                    children: [
                      // Room Type
                      if (room['room_type_name'] != null) ...[
                        SizedBox(width: 8),
                        _buildInfoChipResponsive(
                          Icons.category,
                          room['room_type_name'],
                          Color(0xFF14B8A6),
                          iconSize,
                          chipFontSize,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

  // Helper method for responsive info chip
  Widget _buildInfoChipResponsive(
    IconData icon,
    String label,
    Color color,
    double iconSize,
    double fontSize,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize * 0.88, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomMenu(
      Map<String, dynamic> room, bool canManage, bool isActive) {
    return PopupMenuButton<String>(
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
                builder: (context) => RoomDetailUI(
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

  void _showRoomActionsBottomSheet(
      Map<String, dynamic> room, bool canManage, bool isActive, String status) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.visibility, color: AppTheme.primary),
                  title: Text('ดูรายละเอียด'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailUI(
                          roomId: room['room_id'],
                        ),
                      ),
                    );
                  },
                ),
                if (canManage)
                  ListTile(
                    leading: Icon(Icons.edit, color: AppTheme.primary),
                    title: Text('แก้ไข'),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomEditUI(
                            roomId: room['room_id'],
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadRooms();
                      }
                    },
                  ),
                if (canManage)
                  ListTile(
                    leading: Icon(
                      isActive ? Icons.visibility_off : Icons.visibility,
                      color: isActive ? Colors.orange : Colors.green,
                    ),
                    title: Text(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleRoomStatus(
                        room['room_id'],
                        room['room_number'] ?? '',
                        isActive,
                      );
                    },
                  ),
                if (_currentUser?.userRole == UserRole.superAdmin)
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(
                      'ลบถาวร',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteRoom(
                        room['room_id'],
                        room['room_number'] ?? '',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
