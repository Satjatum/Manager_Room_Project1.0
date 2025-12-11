import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// Model //
import '../../models/user_models.dart';
// Middleware //
import '../../middleware/auth_middleware.dart';
// Services //
import '../../services/branch_service.dart';
// Page //
import 'branch_add_ui.dart';
import 'branch_edit_ui.dart';
import 'branchdash_ui.dart';
import 'branchlist_detail_ui.dart';
// Widget //
import '../widgets/mainnavbar.dart';
import '../widgets/colors.dart';
import '../widgets//snack_message.dart';

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

        debugPrint('เกิดข้อผิดพลาดโหลดข้อมูลสาขา: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดโหลดข้อมูลสาขา');
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
                              debugPrint('คัดลอกเบอร์แล้ว');
                              SnackMessage.showInfo(context, 'คัดลอกเบอร์แล้ว');
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
                currentStatus
                    ? 'ปิดใช้งานสาขานี้หรือไม่?'
                    : 'เปิดใช้งานสาขานี้หรือไม่?',
                style: TextStyle(
                  fontSize: 16,
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
                        'สาขา$branchName',
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
            debugPrint(result['message']);
            SnackMessage.showSuccess(context, result['message']);
            await _loadBranches();
          } else {
            debugPrint("เกิดข้อผิดพลาด: ${result['message']}");
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          debugPrint('เกิดข้อผิดพลาด $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
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
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),

              // Title
              Text(
                'ลบสาขานี้หรือไม่?',
                style: TextStyle(
                  fontSize: 16,
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
                        'สาขา$branchName',
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
                      Icons.warning,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'การลบสาขาไม่สามารถย้อนกลับได้',
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
                            'ลบสาขา',
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
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Loading Text
                  Text(
                    'กำลังลบสาขา',
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

        final result = await BranchService.deleteBranch(branchId);
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            debugPrint(result['message'] ?? 'ลบสาขาสำเร็จ');
            SnackMessage.showSuccess(
                context, result['message'] ?? 'ลบสาขาสำเร็จ');

            await _loadBranches();
          } else {
            debugPrint('เกิดข้อผิดพลาด: ${result['message']}');
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

  // Navigate to branch workspace (Room list with Subnavbar)
  void _navigateToBranchDetail(String branchId, String? branchName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchlistDetailUi(
          branchId: branchId,
        ),
      ),
    );
  }

  void _navigateToRoomList(String branchId, String? branchName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BranchDashboardPage(
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
                    'จัดการสาขา',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'สำหรับจัดการสาขา',
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
                        Icon(Icons.filter_list,
                            size: 20, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.white,
                              value: _selectedStatus,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down, size: 20),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              onChanged: _onStatusChanged,
                              items: [
                                DropdownMenuItem(
                                    value: 'all', child: Text('ทั้งหมด')),
                                DropdownMenuItem(
                                    value: 'active', child: Text('เปิดใช้งาน')),
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
                          child: _buildListView(),
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
                  MaterialPageRoute(builder: (context) => BranchAddUi()),
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
      bottomNavigationBar: const Mainnavbar(currentIndex: 0),
    );
  }

  // Build ListView
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
              color: Colors.white,
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey[600],
                size: 22,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              offset: Offset(0, 40),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 20, color: Color(0xFF14B8A6)),
                      SizedBox(width: 12),
                      Text('ดูรายละเอียด'),
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
                      SizedBox(width: 12),
                      Text(
                        isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
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
                        Text('ลบสาขา', style: TextStyle(color: Colors.red)),
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
                        builder: (context) => BranchEditUi(
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
            isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
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
                                              'รหัสสาขา: ${branch['branch_code']}',
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
                                          'รหัสสาขา: ${branch['branch_code']}',
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
                                              '${branch['manager_count'] ?? 1} ผู้จัดการ '),
                                      if (branch['manager_count'] != null &&
                                          branch['manager_count'] > 1)
                                        TextSpan(text: 'หลัก: '),
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
