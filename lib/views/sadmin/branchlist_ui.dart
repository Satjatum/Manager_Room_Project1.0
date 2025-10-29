import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/widgets/mainnavbar.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/branch_service.dart';
import 'branch_add_ui.dart';
import 'branchlist_detail_ui.dart';
import 'branch_edit_ui.dart';
import '../widgets/colors.dart';

class BranchlistUi extends StatefulWidget {
  const BranchlistUi({Key? key}) : super(key: key);

  @override
  State<BranchlistUi> createState() => _BranchlistUiState();
}

class _BranchlistUiState extends State<BranchlistUi> {
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _filteredBranches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  UserModel? _currentUser;
  bool _isAnonymous = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> branches;

      if (_isAnonymous) {
        branches = await BranchService.getActiveBranches();
      } else if (_currentUser!.userRole == UserRole.superAdmin) {
        branches = await BranchService.getAllBranches();
      } else if (_currentUser!.userRole == UserRole.admin) {
        branches = await BranchService.getBranchesByUser();
      } else {
        branches = await BranchService.getBranchesByUser();
      }

      if (mounted) {
        setState(() {
          _branches = branches;
          _filteredBranches = _branches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _branches = [];
          _filteredBranches = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadBranches,
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
    _filterBranches();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _filterBranches();
  }

  void _filterBranches() {
    if (!mounted) return;
    setState(() {
      _filteredBranches = _branches.where((branch) {
        final searchTerm = _searchQuery.toLowerCase();

        final matchesSearch = (branch['branch_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['branch_address'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['branch_code'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['branch_phone'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (branch['primary_manager_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm);

        final branchStatus =
            branch['is_active'] == true ? 'active' : 'inactive';
        final matchesStatus =
            _selectedStatus == 'all' || branchStatus == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _showPhoneOptions(String phoneNumber, String branchName) {
    showModalBottomSheet(
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
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.phone_rounded,
                          color: Colors.green.shade700, size: 32),
                    ),
                    SizedBox(height: 16),
                    Text(
                      branchName,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: phoneNumber));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('คัดลอกเบอร์แล้ว'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: Icon(Icons.copy_rounded),
                            label: Text('คัดลอก'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.login_rounded, color: AppTheme.primary, size: 32),
            ),
            SizedBox(height: 16),
            Text('ต้องเข้าสู่ระบบ', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(
          'คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBranchStatus(
      String branchId, String branchName, bool currentStatus) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะสาขา');
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
                  color: currentStatus
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  currentStatus
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: currentStatus
                      ? Colors.orange.shade600
                      : Colors.green.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),

              // Title
              Text(
                currentStatus ? 'ปิดใช้งานสาขา?' : 'เปิดใช้งานสาขา?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),

              // Branch Name
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
                    Icon(Icons.business, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        branchName,
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

              // Warning/Info Box
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: currentStatus
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: currentStatus
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      currentStatus
                          ? Icons.warning_rounded
                          : Icons.info_rounded,
                      color: currentStatus
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentStatus
                            ? 'สาขานี้จะไม่แสดงในรายการสำหรับผู้ใช้ทั่วไป'
                            : 'สาขานี้จะแสดงในรายการสำหรับผู้ใช้ทั่วไป',
                        style: TextStyle(
                          color: currentStatus
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
                        backgroundColor: currentStatus
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
                            currentStatus
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
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
                  // Animated Icon Container
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: currentStatus
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
                            color: currentStatus
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          currentStatus
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: currentStatus
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Loading Text
                  Text(
                    currentStatus
                        ? 'กำลังปิดใช้งานสาขา'
                        : 'กำลังเปิดใช้งานสาขา',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await BranchService.toggleBranchStatus(branchId);
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text(result['message'])),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
            await _loadBranches();
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
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteBranch(String branchId, String branchName) async {
    if (_isAnonymous) {
      _showLoginPrompt('ลบสาขา');
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
                'Delete Branch?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),

              // Branch Name
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
                    Icon(Icons.business, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        branchName,
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
                  // Animated Icon Container
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

                  // Loading Text
                  Text(
                    'Deleting Branch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait a moment...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await BranchService.permanentDeleteBranch(branchId);
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text(result['message'] ?? 'ลบสาขาสำเร็จ')),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
            await _loadBranches();
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
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // Navigate to branch workspace (Room list with Subnavbar)
  void _navigateToBranchDetail(String branchId, String? branchName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchListDetail(
          branchId: branchId,
        ),
      ),
    );
  }

  void _navigateToRoomList(String branchId, String? branchName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomListUI(
          branchId: branchId,
          branchName: branchName,
        ),
      ),
    );
  }

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin);

  bool get _canAdd =>
      !_isAnonymous && _currentUser?.userRole == UserRole.superAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your branch locations and details',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Section
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Filter Dropdown
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down, size: 20),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              onChanged: _onStatusChanged,
                              items: [
                                DropdownMenuItem(
                                    value: 'all', child: Text('All Branches')),
                                DropdownMenuItem(
                                    value: 'active', child: Text('Active')),
                                DropdownMenuItem(
                                    value: 'inactive', child: Text('Inactive')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Results Count
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Showing ${_filteredBranches.length} of ${_branches.length} branches',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // Branch List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                        strokeWidth: 3,
                      ),
                    )
                  : _filteredBranches.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadBranches,
                          color: Color(0xFF10B981),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final platform = Theme.of(context).platform;
                              final bool isMobileApp = !kIsWeb &&
                                  (platform == TargetPlatform.android ||
                                      platform == TargetPlatform.iOS);

                              // ทำตามแพทเทิร์นของ settingbranch_ui: ถ้าเป็นแอปมือถือ ให้ใช้ List เสมอ
                              if (isMobileApp) {
                                return _buildListView();
                              }

                              if (constraints.maxWidth > 600) {
                                return _buildGridView(constraints.maxWidth);
                              }
                              return _buildListView();
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BranchAddPage()),
                ).then((result) {
                  if (result == true) _loadBranches();
                });
              },
              backgroundColor: AppTheme.primary,
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
              elevation: 4,
            )
          : null,
      bottomNavigationBar: const Mainnavbar(currentIndex: 1),
    );
  }

  // Build ListView for small screens
  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 8,
      ),
      itemCount: _filteredBranches.length,
      itemBuilder: (context, index) {
        final branch = _filteredBranches[index];
        return Column(
          children: [
            _buildCompactBranchCard(branch),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // Build GridView for large screens
  Widget _buildGridView(double screenWidth) {
    // คำนวณจำนวนคอลัมน์ตามขนาดหน้าจอ
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
    }

    // คำนวณ childAspectRatio แบบไดนามิกเพื่อลดปัญหา overflow
    const double horizontalPadding = 24; // ซ้าย/ขวา ของ GridView
    const double crossSpacing = 16; // ระยะห่างคอลัมน์
    final double availableWidth = screenWidth -
        (horizontalPadding * 2) -
        (crossSpacing * (crossAxisCount - 1));
    final double tileWidth = availableWidth / crossAxisCount;

    // imageHeight คิดแบบอนุรักษ์นิยมขึ้นเล็กน้อย เพื่อกัน overflow
    final double imageHeight = (tileWidth * 0.45).clamp(120.0, 200.0);
    // ประมาณความสูงส่วน header และ info ให้เผื่อเคสข้อความยาว
    final double estHeader = tileWidth < 300 ? 120 : 100;
    final double estInfo = tileWidth < 300 ? 180 : 150;
    final double estimatedTileHeight = estHeader + imageHeight + estInfo;
    double dynamicAspect = tileWidth / estimatedTileHeight; // width / height
    // กันกรณีแคบ/กว้างเกินไป
    dynamicAspect = dynamicAspect.clamp(0.55, 1.00);

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 8,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: dynamicAspect,
      ),
      itemCount: _filteredBranches.length,
      itemBuilder: (context, index) {
        final branch = _filteredBranches[index];
        return _buildCompactBranchCard(branch);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 80, color: Colors.grey[300]),
            SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty ? 'ไม่พบสาขาที่ค้นหา' : 'ยังไม่มีสาขา',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'ลองเปลี่ยนคำค้นหาหรือกรองสถานะ'
                  : 'เริ่มต้นโดยการเพิ่มสาขาแรก',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBranchCard(Map<String, dynamic> branch) {
    final isActive = branch['is_active'] ?? false;
    final hasPhone = branch['branch_phone'] != null &&
        branch['branch_phone'].toString().trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isTiny = width < 240;
        final bool isSmall = width < 320;
        final bool isMedium = width < 480;

        final double titleSize = isTiny
            ? 14
            : isSmall
                ? 15
                : 16;
        final double subTitleSize = isTiny ? 12 : 13;
        final double bodySize = isTiny ? 12 : 13;
        final double iconSize = isTiny ? 16 : 18;
        final double badgeFontSize = isTiny ? 10 : 12;
        final EdgeInsets headerPadding = EdgeInsets.fromLTRB(
            isTiny ? 12 : 16, isTiny ? 8 : 12, 8, isTiny ? 8 : 12);
        final EdgeInsets infoPadding = EdgeInsets.all(isTiny ? 12 : 16);
        final double imageHeight = (width * 0.5).clamp(120.0, 200.0).toDouble();

        Widget buildMenu() => PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              offset: Offset(0, 40),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 20, color: Color(0xFF14B8A6)),
                      SizedBox(width: 12),
                      Text('View Details'),
                    ],
                  ),
                ),
                if (_canManage)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 20, color: Color(0xFF14B8A6)),
                        SizedBox(width: 12),
                        Text('Edit Branch'),
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
                      SizedBox(width: 12),
                      Text(
                        isActive ? 'Deactivate' : 'Activate',
                        style: TextStyle(
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentUser?.userRole == UserRole.superAdmin) ...[
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete Branch',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _navigateToBranchDetail(
                      branch['branch_id'],
                      branch['branch_name'],
                    );
                    break;
                  case 'edit':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BranchEditPage(
                          branchId: branch['branch_id'],
                        ),
                      ),
                    ).then((result) {
                      if (result == true) _loadBranches();
                    });
                    break;
                  case 'toggle_status':
                    _toggleBranchStatus(
                      branch['branch_id'],
                      branch['branch_name'] ?? '',
                      isActive,
                    );
                    break;
                  case 'delete':
                    _deleteBranch(
                      branch['branch_id'],
                      branch['branch_name'] ?? '',
                    );
                    break;
                }
              },
            );

        final Widget statusBadge = Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Color(0xFF10B981) : Colors.grey[400],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: Colors.white,
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToRoomList(
              branch['branch_id'],
              branch['branch_name'],
            ),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (responsive)
                  Padding(
                    padding: headerPadding,
                    child: isSmall
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          branch['branch_name'] ?? 'ไม่มีชื่อ',
                                          style: TextStyle(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (branch['branch_code'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Code: ${branch['branch_code']}',
                                              style: TextStyle(
                                                fontSize: subTitleSize,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  buildMenu(),
                                ],
                              ),
                              SizedBox(height: 8),
                              statusBadge,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      branch['branch_name'] ?? 'ไม่มีชื่อ',
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (branch['branch_code'] != null)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Code: ${branch['branch_code']}',
                                          style: TextStyle(
                                            fontSize: subTitleSize,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              statusBadge,
                              SizedBox(width: 4),
                              buildMenu(),
                            ],
                          ),
                  ),

                  // Image Section (responsive height)
                  Container(
                    height: imageHeight,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: branch['branch_image'] != null &&
                            branch['branch_image'].toString().isNotEmpty
                        ? Image.network(
                            branch['branch_image'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),

                  // Info Section
                  Padding(
                    padding: infoPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Address
                        if (branch['branch_address'] != null &&
                            branch['branch_address'].toString().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: iconSize, color: Color(0xFF14B8A6)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    branch['branch_address'],
                                    style: TextStyle(
                                        fontSize: bodySize,
                                        color: Colors.grey[700],
                                        height: 1.4),
                                    maxLines: isMedium ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Phone
                        if (hasPhone)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                _showPhoneOptions(
                                  branch['branch_phone'],
                                  branch['branch_name'] ?? 'สาขา',
                                );
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.phone_outlined,
                                      size: iconSize, color: Color(0xFF14B8A6)),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      branch['branch_phone'],
                                      style: TextStyle(
                                          fontSize: bodySize,
                                          color: Colors.grey[700]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Manager Info
                        if (branch['primary_manager_name'] != null &&
                            branch['primary_manager_name']
                                .toString()
                                .isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: iconSize, color: Color(0xFF14B8A6)),
                              SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: bodySize,
                                        color: Colors.grey[700]),
                                    children: [
                                      TextSpan(
                                          text:
                                              '${branch['manager_count'] ?? 1} manager'),
                                      if (branch['manager_count'] != null &&
                                          branch['manager_count'] > 1)
                                        TextSpan(text: 's'),
                                      TextSpan(text: ' • Primary: '),
                                      TextSpan(
                                        text: branch['primary_manager_name'],
                                        style: TextStyle(
                                          color: Color(0xFF14B8A6),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
