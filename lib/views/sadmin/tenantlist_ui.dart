import 'package:flutter/material.dart';
// -----
import '../../models/user_models.dart';
// -----
import '../../middleware/auth_middleware.dart';
// -----
import '../../services/tenant_service.dart';
// -----
import 'package:manager_room_project/views/sadmin/tenant_add_ui.dart';
import 'package:manager_room_project/views/sadmin/tenant_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_detail_ui.dart';
// -----
import '../widgets/colors.dart';

class TenantListUI extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  final bool hideBottomNav;

  const TenantListUI({
    Key? key,
    this.branchId,
    this.branchName,
    this.hideBottomNav = false,
  }) : super(key: key);

  @override
  State<TenantListUI> createState() => _TenantListUIState();
}

class _TenantListUIState extends State<TenantListUI> {
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _filteredTenants = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String? _selectedBranchId;
  UserModel? _currentUser;
  bool _isAnonymous = false;
  final TextEditingController _searchController = TextEditingController();
  // tenant_id -> { 'room_number': '...', 'roomcate_name': '...' }
  Map<String, Map<String, String>> _tenantRoomInfo = {};

  // Screen breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

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
    } catch (e) {
      setState(() {
        _currentUser = null;
        _isAnonymous = true;
      });
    }
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (_isAnonymous) {
      _loadTenants();
      return;
    }

    try {
      final branches = await TenantService.getBranchesForTenantFilter();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> tenants;

      if (_isAnonymous) {
        tenants = [];
      } else if (_currentUser!.userRole == UserRole.superAdmin ||
          _currentUser!.userRole == UserRole.admin) {
        tenants = await TenantService.getAllTenants(
          branchId: _selectedBranchId,
          isActive:
              _selectedStatus == 'all' ? null : _selectedStatus == 'active',
        );
      } else {
        tenants =
            await TenantService.getTenantsByUser(branchId: _selectedBranchId);
      }

      if (mounted) {
        setState(() {
          _tenants = tenants;
          _filteredTenants = _tenants;
        });
        // Load room info in batch (active contracts only)
        await _loadTenantRooms();
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _tenants = [];
          _filteredTenants = [];
        });
        print('เกิดข้อผิดพลาดในการโหลดข้อมูล ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ลองใหม่',
              textColor: Colors.white,
              onPressed: _loadTenants,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadTenantRooms() async {
    try {
      final ids = _tenants
          .map((t) => t['tenant_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _tenantRoomInfo = {});
        return;
      }
      final map = await TenantService.getActiveRoomsForTenants(ids);
      if (mounted) {
        setState(() {
          _tenantRoomInfo = map;
        });
      }
    } catch (e) {
      // Non-blocking; simply keep room info empty on error
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterTenants();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status ?? 'all';
    });
    _loadTenants();
  }

  void _onBranchChanged(String? branchId) {
    setState(() {
      _selectedBranchId = branchId;
    });
    _loadTenants();
  }

  void _filterTenants() {
    if (!mounted) return;
    setState(() {
      _filteredTenants = _tenants.where((tenant) {
        final searchTerm = _searchQuery.toLowerCase();
        final matchesSearch = (tenant['tenant_fullname'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (tenant['tenant_idcard'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm) ||
            (tenant['tenant_phone'] ?? '')
                .toString()
                .toLowerCase()
                .contains(searchTerm);

        return matchesSearch;
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
            const SizedBox(width: 8),
            const Text('ต้องเข้าสู่ระบบ'),
          ],
        ),
        content: Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถ$actionได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTenantStatus(
      String tenantId, String tenantName, bool currentStatus) async {
    if (_isAnonymous) {
      _showLoginPrompt('เปลี่ยนสถานะผู้เช่า');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 20),

              // Title
              Text(
                currentStatus
                    ? 'คุณต้องการปิดใช้งานหรือไม่'
                    : 'คุณต้องการเปิดใช้งานหรือไม่',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Tenant label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tenantName.isEmpty ? '-' : tenantName,
                        style: const TextStyle(
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
              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(14),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentStatus
                            ? 'ผู้เช่านี้จะไม่แสดงในรายการผู้ใช้ทั่วไป'
                            : 'ผู้เช่านี้จะแสดงในรายการผู้ใช้ทั่วไป',
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
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentStatus
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          const SizedBox(width: 8),
                          Text(
                            currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                            style: const TextStyle(
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
        // Styled loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 20),
                  Text(
                    currentStatus
                        ? 'กำลังปิดใช้งานผู้เช่า'
                        : 'กำลังเปิดใช้งานผู้เช่า',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await TenantService.toggleTenantStatus(tenantId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            await _loadTenants();
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
              content: Text(e.toString().replaceAll('ข้อยกเว้น: ', '')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTenant(String tenantId, String tenantName) async {
    if (_isAnonymous) {
      _showLoginPrompt('ลบผู้เช่า');
      return;
    }

    // Check if user is superadmin
    if (_currentUser?.userRole != UserRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เฉพาะ Super Admin เท่านั้นที่สามารถลบผู้เช่าได้'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 20),

              // Title
              const Text(
                'คุณต้องการลบผู้เช่าหรือไม่?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Tenant label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tenantName.isEmpty ? '-' : tenantName,
                        style: const TextStyle(
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
              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.shade100,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ข้อมูลทั้งหมดจะถูกลบถาวร',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ยืนยันการลบ',
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: Colors.red,
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
                  const SizedBox(height: 20),
                  const Text(
                    'กำลังลบข้อมูลผู้เช่า',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result =
            await TenantService.deleteTenantWithRelatedData(tenantId);

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            await _loadTenants();
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
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddTenant() async {
    if (_isAnonymous) {
      _showLoginPrompt('เพิ่มผู้เช่า');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantAddUI(
          branchId: widget.branchId,
          branchName: widget.branchName,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadTenants();
    }
  }

  bool get _canManage =>
      !_isAnonymous &&
      (_currentUser?.userRole == UserRole.superAdmin ||
          _currentUser?.userRole == UserRole.admin ||
          _currentUser?.hasAnyPermission([
                DetailedPermission.all,
                DetailedPermission.manageTenants,
              ]) ==
              true);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= desktopBreakpoint;
    final isTablet =
        screenWidth >= tabletBreakpoint && screenWidth < desktopBreakpoint;
    final isMobile = screenWidth < mobileBreakpoint;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จัดการผู้เช่า',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับจัดการผู้เช่า',
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

            // Search and Filter Section (branchlist style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status Filter
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 20),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87),
                              onChanged: _onStatusChanged,
                              items: const [
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

                  // Branch Filter (if available and no initial branch)
                  if (_branches.isNotEmpty && widget.branchId == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 20, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedBranchId ?? 'all',
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    size: 20),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
                                items: [
                                  const DropdownMenuItem(
                                      value: 'all', child: Text('ทุกสาขา')),
                                  ..._branches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch['branch_id'] as String,
                                      child: Text(branch['branch_name'] ?? ''),
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
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Results Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Showing ${_filteredTenants.length} of ${_tenants.length} tenants',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),

            // List/Grid
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredTenants.isEmpty
                      ? _buildEmptyState(isMobile)
                      : RefreshIndicator(
                          onRefresh: _loadTenants,
                          color: AppTheme.primary,
                          child: _buildTenantList(
                              screenWidth, isDesktop, isTablet),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _navigateToAddTenant,
              backgroundColor: AppTheme.primary,
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
            )
          : null,
      bottomNavigationBar: null,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          const Text('กำลังโหลดข้อมูล...'),
        ],
      ),
    );
  }

  Widget _buildTenantList(double screenWidth, bool isDesktop, bool isTablet) {
    // ปรับจำนวนคอลัมน์แบบ adaptive รองรับ 4K / Laptop L / Laptop / Tablet
    // โดยคงความกว้างของการ์ดให้อยู่ในช่วงเหมาะสม (>= 300px)
    int crossAxisCount = 1;
    if (screenWidth > 600) {
      const double horizontalPadding = 24;
      const double gridSpacing = 16;

      // กำหนด max columns ตามช่วงหน้าจอหลัก ๆ
      int maxCols;
      if (screenWidth >= 3840) {
        // 4K
        maxCols = 8;
      } else if (screenWidth >= 2560) {
        // Ultra-wide / 2.5K
        maxCols = 7;
      } else if (screenWidth >= 1920) {
        // Desktop ใหญ่
        maxCols = 6;
      } else if (screenWidth >= 1440) {
        // Laptop L
        maxCols = 5;
      } else if (screenWidth >= 1200) {
        // Desktop ปกติ / Laptop
        maxCols = 4;
      } else if (screenWidth >= 900) {
        // Tablet ใหญ่ / เล็กน้อยก่อน Laptop
        maxCols = 3;
      } else {
        // Tablet
        maxCols = 2;
      }

      // ทดลองจาก maxCols ลดลงจนได้ความกว้างต่อการ์ด >= 300px
      const double minCardWidth = 300;
      final double totalHorizontal = horizontalPadding * 2;
      int cols = maxCols;
      while (cols > 2) {
        final double availableWidth =
            screenWidth - totalHorizontal - (gridSpacing * (cols - 1));
        final double itemWidth = availableWidth / cols;
        if (itemWidth >= minCardWidth) break;
        cols--;
      }
      crossAxisCount = cols;
    }

    if (crossAxisCount > 1) {
      const double horizontalPadding = 24;
      const double gridSpacing = 16;
      final double availableWidth = screenWidth -
          (horizontalPadding * 2) -
          (gridSpacing * (crossAxisCount - 1));
      final double itemWidth = availableWidth / crossAxisCount;

      double mainExtent = itemWidth * 0.5;

      return GridView.builder(
        padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
          mainAxisExtent: mainExtent,
        ),
        itemCount: _filteredTenants.length,
        itemBuilder: (context, index) {
          final tenant = _filteredTenants[index];
          return _buildCompactTenantCard(tenant);
        },
      );
    } else {
      // ใช้ ListView สำหรับหน้าจอเล็ก
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredTenants.length,
        itemBuilder: (context, index) {
          final tenant = _filteredTenants[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCompactTenantCard(tenant),
          );
        },
      );
    }
  }

  Widget _buildCompactTenantCard(Map<String, dynamic> tenant) {
    // 📌 ดึงข้อมูลหลักของผู้เช่า
    final bool isActive = tenant['is_active'] ?? false;
    final String tenantName =
        (tenant['tenant_fullname'] ?? 'ไม่ระบุชื่อ') as String;
    final String phoneRaw = tenant['tenant_phone']?.toString() ?? 'ไม่ระบุ';
    final String phone = _formatPhoneNumber(phoneRaw);
    final String? profileImageUrl =
        (tenant['tenant_profile'] ?? tenant['tenant_profile_image'])
            ?.toString();
    final String? tenantId = tenant['tenant_id']?.toString();

    // 🔐 ตรวจสอบสิทธิ์การจัดการ (ใช้ pattern เดียวกับของเดิม)
    final bool canManage = !_isAnonymous &&
        (_currentUser?.userRole == UserRole.superAdmin ||
            _currentUser?.userRole == UserRole.admin ||
            _currentUser?.hasAnyPermission([
                  DetailedPermission.all,
                  DetailedPermission.manageTenants,
                ]) ==
                true);

    // 📱 Responsive ขนาดการ์ด
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < mobileBreakpoint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: 6,
      ),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.primary.withOpacity(0.08),
          highlightColor: AppTheme.primary.withOpacity(0.04),
          onTap: () async {
            // 👀 แตะการ์ด = ดูรายละเอียดผู้เช่า
            final String? idStr = tenantId;
            if (idStr == null || idStr.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ไม่พบรหัสผู้เช่า'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantDetailUI(tenantId: idStr),
              ),
            );
            if (result == true && mounted) await _loadTenants();
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 👤 รูปโปรไฟล์แบบวงกลม (แนว Employee Card)
                Hero(
                  tag: 'tenant_avatar_$tenantId',
                  child: Container(
                    width: isMobile ? 52 : 56,
                    height: isMobile ? 52 : 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      border: Border.all(
                        color: AppTheme.primary,
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildInitialAvatar(tenantName);
                                  },
                                )
                              : _buildInitialAvatar(tenantName),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 🧾 ข้อมูลผู้เช่า (ชื่อ + เบอร์ + สถานะ)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🏷 ชื่อผู้เช่า
                      Text(
                        tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 📞 เบอร์โทรศัพท์ (อยู่ใต้ชื่อแทนคำบรรยายผู้เช่า)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 🎯 แถบสถานะ + ป้ายผู้เช่า (อยู่ใต้เบอร์โทร)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // ✅ สถานะผู้เช่า
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isActive ? 'กำลังใช้งาน' : 'ปิดใช้งาน',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? const Color(0xFF166534)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🪪 ป้าย "ผู้เช่า"
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'ผู้เช่า',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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

                const SizedBox(width: 8),

                // ⋯ เมนูเพิ่มเติม + ลูกศรขวา (โซน action)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (canManage)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: Colors.grey.shade700,
                        ),
                        tooltip: 'ตัวเลือกเพิ่มเติม',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        onSelected: (value) async {
                          final String? idStr = tenantId;
                          if (idStr == null || idStr.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ไม่พบรหัสผู้เช่า'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          switch (value) {
                            // 👁 ดูรายละเอียด
                            case 'view':
                              if (_isAnonymous) {
                                _showLoginPrompt('ดูรายละเอียดผู้เช่า');
                                return;
                              }
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TenantDetailUI(tenantId: idStr),
                                ),
                              );
                              if (result == true && mounted) {
                                await _loadTenants();
                              }
                              break;

                            // ✏ แก้ไขผู้เช่า
                            case 'edit':
                              if (_isAnonymous) {
                                _showLoginPrompt('แก้ไขผู้เช่า');
                                return;
                              }
                              if (!canManage) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('คุณไม่มีสิทธิ์จัดการผู้เช่า'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              final editResult = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TenantEditUI(
                                    tenantId: idStr,
                                    tenantData: tenant,
                                  ),
                                ),
                              );
                              if (editResult == true && mounted) {
                                await _loadTenants();
                              }
                              break;

                            // 🔄 เปลี่ยนสถานะใช้งาน
                            case 'toggle_status':
                              if (_isAnonymous) {
                                _showLoginPrompt(
                                    isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน');
                                return;
                              }
                              if (!canManage) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'คุณไม่มีสิทธิ์เปลี่ยนสถานะผู้เช่า'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              _toggleTenantStatus(
                                idStr,
                                tenantName,
                                isActive,
                              );
                              break;

                            // 🗑 ลบผู้เช่า
                            case 'delete':
                              if (_isAnonymous) {
                                _showLoginPrompt('ลบผู้เช่า');
                                return;
                              }
                              if (!canManage) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('คุณไม่มีสิทธิ์ลบข้อมูลผู้เช่า'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              _deleteTenant(
                                idStr,
                                tenantName,
                              );
                              break;
                          }
                        },
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
                                  color:
                                      isActive ? Colors.orange : Colors.green,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                                  style: TextStyle(
                                    color:
                                        isActive ? Colors.orange : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('ลบ', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 8),
                    // 👉 ลูกศรบอกว่ากดเข้าไปดูต่อได้
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 Avatar fallback ตอนโหลดรูปไม่ได้ / ไม่มีรูป
  Widget _buildInitialAvatar(String name) {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: isMobile ? 60 : 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              _isAnonymous
                  ? 'กรุณาเข้าสู่ระบบเพื่อดูข้อมูลผู้เช่า'
                  : _searchQuery.isNotEmpty
                      ? 'ไม่พบผู้เช่าที่ค้นหา'
                      : 'ยังไม่มีผู้เช่า',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'ลองเปลี่ยนคำค้นหา หรือกรองสถานะ'
                  : _isAnonymous
                      ? ''
                      : 'เริ่มต้นโดยการเพิ่มผู้เช่าใหม่',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty && _canManage)
              Padding(
                padding: EdgeInsets.only(top: isMobile ? 20 : 24),
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddTenant,
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มผู้เช่า'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 24,
                      vertical: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// Helper method for info rows

// Format Phone Number
  String _formatPhoneNumber(String phone) {
    if (phone == 'ไม่ระบุ' || phone.length != 10) return phone;
    return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
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
}
