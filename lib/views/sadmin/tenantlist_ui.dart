import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/tenant_add_ui.dart';
import 'package:manager_room_project/views/sadmin/tenant_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_detail_ui.dart';
import 'package:manager_room_project/views/widgets/mainnavbar.dart';
import 'package:manager_room_project/views/widgets/subnavbar.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/tenant_service.dart';
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
      print('Error loading branches: $e');
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
          _isLoading = false;
        });
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('เปลี่ยนสถานะผู้เช่า $tenantName'),
        content: Text(currentStatus
            ? 'คุณต้องการปิดใช้งานผู้เช่านี้ใช่หรือไม่?'
            : 'คุณต้องการเปิดใช้งานผู้เช่านี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
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
              content: Text(e.toString().replaceAll('Exception: ', '')),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบผู้เช่า',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คุณต้องการลบผู้เช่า "$tenantName" และข้อมูลที่เกี่ยวข้องทั้งหมดหรือไม่?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '⚠️ ข้อมูลที่จะถูกลบ:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• ข้อมูลผู้เช่า'),
                  Text('• สัญญาเช่าทั้งหมด'),
                  Text('• ใบแจ้งหนี้'),
                  Text('• ข้อมูลการชำระเงิน'),
                  Text('• ข้อมูลมิเตอร์'),
                  SizedBox(height: 8),
                  Text(
                    '※ การลบนี้ไม่สามารถกู้คืนได้',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันการลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'กำลังลบข้อมูล...',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
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
              // Header Section (match branchlist_ui)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black87),
                      onPressed: () async {
                        if (lockedBranchId != null) {
                          await _confirmExitBranch();
                        } else if (Navigator.of(context).canPop()) {
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
                            'Tenant Management',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your tenants and details',
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
                          hintText: 'Search tenants by name, phone or id card',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
                                value: _selectedStatus,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    size: 20),
                                style: const TextStyle(
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
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Results Count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
            ? FloatingActionButton.extended(
                onPressed: _navigateToAddTenant,
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add),
                label: Text(isMobile ? 'เพิ่ม' : 'เพิ่มผู้เช่า'),
                tooltip: 'เพิ่มผู้เช่าใหม่',
              )
            : null,
        bottomNavigationBar: widget.hideBottomNav
            ? null
            : Subnavbar(
                currentIndex: 1,
                branchId: widget.branchId,
                branchName: widget.branchName,
              ),
      ),
    );
  }

  Widget _buildSearchHeader(double screenWidth, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ค้นหาผู้เช่า (ชื่อ, เบอร์โทร, บัตรประชาชน)',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: isMobile ? 13 : 14,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[700]),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
            ),
          ),

          // Branch Filter
          if (_branches.isNotEmpty && widget.branchId == null) ...[
            SizedBox(height: isMobile ? 8 : 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedBranchId ?? 'all',
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('ทุกสาขา'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'null',
                    child: Text('ยังไม่ระบุสาขา'),
                  ),
                  ..._branches.map((branch) {
                    return DropdownMenuItem<String>(
                      value: branch['branch_id'] as String,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              branch['branch_name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (branch['manager_count'] != null &&
                              branch['manager_count'] > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${branch['manager_count']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  _onBranchChanged(value == 'all' ? null : value);
                },
              ),
            ),
          ],

          // Active Filters Display
          if (_selectedBranchId != null ||
              _selectedStatus != 'all' ||
              _searchQuery.isNotEmpty) ...[
            SizedBox(height: isMobile ? 8 : 12),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 12,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_alt,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getActiveFiltersText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBranchId = widget.branchId;
                        _selectedStatus = 'all';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      _loadTenants();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
      // ใช้ GridView สำหรับหน้าจอใหญ่
      // คำนวณความสูง cell ให้เหมาะกับเนื้อหาของการ์ดแบบ compact (Row)
      const double horizontalPadding = 24;
      const double gridSpacing = 16;
      final double availableWidth = screenWidth -
          (horizontalPadding * 2) -
          (gridSpacing * (crossAxisCount - 1));
      final double itemWidth = availableWidth / crossAxisCount;

      double mainExtent;
      if (itemWidth >= 420) {
        mainExtent = 160; // กว้างมาก (4K/2.5K) เพิ่มพื้นที่ให้โปร่งและกันล้น
      } else if (itemWidth >= 360) {
        mainExtent = 155; // ~360–419px (เช่น Tablet 768 สองคอลัมน์)
      } else if (itemWidth >= 300) {
        mainExtent = 150; // ~300–359px (เช่น 1024/1440/2560 ตามคอลัมน์ที่คำนวณ)
      } else if (itemWidth >= 260) {
        mainExtent = 128;
      } else {
        mainExtent = 120; // ขั้นต่ำสำหรับช่วงแคบมาก
      }

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
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: _filteredTenants.length,
        itemBuilder: (context, index) {
          final tenant = _filteredTenants[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCompactTenantCard(tenant),
          );
        },
      );
    }
  }

  Widget _buildCompactTenantCard(Map<String, dynamic> tenant) {
    // Data preparation (use current available fields)
    final isActive = tenant['is_active'] ?? false;
    final tenantId = tenant['tenant_id'];
    final tenantName = tenant['tenant_fullname'] ?? 'ไม่ระบุชื่อ';
    final phone =
        _formatPhoneNumber(tenant['tenant_phone']?.toString() ?? 'ไม่ระบุ');
    final branchName = tenant['branch_name'] ?? 'ไม่ระบุสาขา';
    final profileImageUrl =
        (tenant['tenant_profile'] ?? tenant['tenant_profile_image'])
            ?.toString();

    final canManage = !_isAnonymous &&
        (_currentUser?.userRole == UserRole.superAdmin ||
            _currentUser?.userRole == UserRole.admin ||
            _currentUser?.hasAnyPermission([
                  DetailedPermission.all,
                  DetailedPermission.manageTenants,
                ]) ==
                true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (_isAnonymous) {
            _showLoginPrompt('ดูรายละเอียด');
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TenantDetailUI(tenantId: tenantId),
            ),
          );
          if (result == true && mounted) await _loadTenants();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final isCompact = w < 360;
              final avatarSize = isCompact ? 48.0 : 56.0;
              final nameSize = isCompact ? 15.0 : 16.0;
              final subSize = isCompact ? 12.0 : 13.0;
              final badgeFontSize = isCompact ? 11.0 : 12.0;

              return Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar + status dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.08),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 2),
                          ),
                          child: ClipOval(
                            child: (profileImageUrl != null &&
                                    profileImageUrl.isNotEmpty)
                                ? Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        _getInitials(tenantName),
                                        style: TextStyle(
                                          fontSize: avatarSize * 0.4,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _getInitials(tenantName),
                                      style: TextStyle(
                                        fontSize: avatarSize * 0.4,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: avatarSize * 0.24,
                            height: avatarSize * 0.24,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(width: isCompact ? 10 : 14),

                    // Info area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  tenantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Action menu
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    size: 18, color: Colors.grey.shade600),
                                tooltip: 'ตัวเลือก',
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'view':
                                      if (_isAnonymous) {
                                        _showLoginPrompt('ดูรายละเอียด');
                                        return;
                                      }
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TenantDetailUI(
                                              tenantId: tenantId),
                                        ),
                                      );
                                      if (result == true && mounted)
                                        await _loadTenants();
                                      break;
                                    case 'edit':
                                      if (_isAnonymous) {
                                        _showLoginPrompt('แก้ไข');
                                        return;
                                      }
                                      if (!canManage) return;
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TenantEditUI(
                                            tenantId: tenantId,
                                            tenantData: tenant,
                                          ),
                                        ),
                                      );
                                      if (result == true && mounted)
                                        await _loadTenants();
                                      break;
                                    case 'toggle':
                                      if (_isAnonymous) {
                                        _showLoginPrompt(isActive
                                            ? 'ปิดใช้งาน'
                                            : 'เปิดใช้งาน');
                                        return;
                                      }
                                      if (!canManage) return;
                                      _toggleTenantStatus(
                                        tenant['tenant_id'],
                                        tenant['tenant_fullname'] ?? '',
                                        isActive,
                                      );
                                      break;
                                    case 'delete':
                                      if (_isAnonymous) {
                                        _showLoginPrompt('ลบผู้เช่า');
                                        return;
                                      }
                                      _deleteTenant(
                                        tenant['tenant_id'],
                                        tenant['tenant_fullname'] ?? '',
                                      );
                                      break;
                                  }
                                },
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
                                  if (canManage) ...[
                                    if (canManage)
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.edit_outlined,
                                                size: 20,
                                                color: Color(0xFF14B8A6)),
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
                                            color: isActive
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            isActive
                                                ? 'ปิดใช้งาน'
                                                : 'เปิดใช้งาน',
                                            style: TextStyle(
                                              color: isActive
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: const [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 12),
                                          Text('ลบ',
                                              style: TextStyle(
                                                color: Colors.red,
                                              )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Phone
                          if (phone != 'ไม่ระบุ')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined,
                                    size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: subSize,
                                        color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),

                          if (phone != 'ไม่ระบุ') const SizedBox(height: 4),

                          // Branch
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.apartment_rounded,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  branchName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: subSize,
                                      color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Status badge (pill)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholderCompact(String tenantName) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                _getInitials(tenantName),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderBadgeCompact(String gender) {
    final genderData = _getGenderData(gender);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            genderData['color'].withOpacity(0.1),
            genderData['color'].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: genderData['color'].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            genderData['icon'],
            size: 14,
            color: genderData['color'],
          ),
          SizedBox(width: 6),
          Text(
            genderData['label'],
            style: TextStyle(
              fontSize: 12,
              color: genderData['color'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  Widget _buildTenantCard(Map<String, dynamic> tenant, double screenWidth) {
    final isActive = tenant['is_active'] ?? false;
    final profileImageUrl = tenant['tenant_profile'];
    final tenantId = tenant['tenant_id'];
    final branchName = tenant['branch_name'] ?? 'ไม่ระบุสาขา';
    final hasBranch = tenant['branch_id'] != null;

    // MediaQuery-based responsive design
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final orientation = mediaQuery.orientation;

    // Breakpoints
    final isCompact = screenWidth < 380;
    final isMobile = screenWidth < mobileBreakpoint;
    final isTablet =
        screenWidth >= mobileBreakpoint && screenWidth < tabletBreakpoint;
    final isDesktop = screenWidth >= desktopBreakpoint;
    final isLargeDesktop = screenWidth >= 1600;

    // Landscape detection
    final isLandscape = orientation == Orientation.landscape;

    // Dynamic sizing based on screen size and orientation
    final cardPadding = isCompact
        ? 14.0
        : isMobile
            ? (isLandscape ? 16.0 : 18.0)
            : isTablet
                ? 20.0
                : isDesktop
                    ? 24.0
                    : 28.0;

    final profileSize = isCompact
        ? 56.0
        : isMobile
            ? (isLandscape ? 60.0 : 68.0)
            : isTablet
                ? 72.0
                : isDesktop
                    ? 80.0
                    : 88.0;

    final titleSize = isCompact
        ? 15.5
        : isMobile
            ? (isLandscape ? 16.0 : 17.5)
            : isTablet
                ? 18.0
                : isDesktop
                    ? 19.0
                    : 20.0;

    final subtitleSize = isCompact
        ? 12.5
        : isMobile
            ? 13.5
            : isTablet
                ? 14.0
                : 14.5;

    final labelSize = isCompact
        ? 11.0
        : isMobile
            ? 11.5
            : 12.0;

    final iconSize = isCompact
        ? 18.0
        : isMobile
            ? 19.0
            : isTablet
                ? 20.0
                : 21.0;

    // Card elevation and border radius based on screen size
    final cardBorderRadius = isCompact
        ? 16.0
        : isMobile
            ? 18.0
            : 20.0;
    final contentBorderRadius = isCompact
        ? 12.0
        : isMobile
            ? 14.0
            : 16.0;

    // Spacing adjustments
    final verticalSpacing = isCompact
        ? 14.0
        : isMobile
            ? 16.0
            : isTablet
                ? 18.0
                : 20.0;
    final horizontalSpacing = isCompact
        ? 10.0
        : isMobile
            ? 12.0
            : isTablet
                ? 14.0
                : 16.0;

    return Container(
      margin: EdgeInsets.only(
        bottom: isCompact
            ? 10
            : isMobile
                ? 12
                : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDesktop ? 0.06 : 0.04),
            blurRadius: isDesktop ? 20 : 16,
            offset: Offset(0, isDesktop ? 6 : 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantDetailUI(tenantId: tenantId),
              ),
            );
            if (result == true && mounted) {
              await _loadTenants();
            }
          },
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section - Profile + Name + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Avatar with Status Indicator
                    Flexible(
                      flex: 0,
                      child: Stack(
                        children: [
                          _buildProfileImage(
                            profileImageUrl: profileImageUrl,
                            tenantName: tenant['tenant_fullname'] ?? '',
                            size: profileSize,
                          ),
                          // Status Dot Indicator
                          Positioned(
                            right: isCompact ? 0 : 2,
                            bottom: isCompact ? 0 : 2,
                            child: Container(
                              width: profileSize * 0.22,
                              height: profileSize * 0.22,
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: isCompact ? 2.0 : 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isActive
                                            ? Colors.green
                                            : Colors.orange)
                                        .withOpacity(0.3),
                                    blurRadius: isCompact ? 4 : 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: horizontalSpacing),

                    // Name and Status Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name
                          Text(
                            tenant['tenant_fullname'] ?? 'ไม่ระบุ',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: Colors.grey[900],
                              letterSpacing: -0.3,
                            ),
                            maxLines: isLandscape && isMobile ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isCompact ? 4 : 6),

                          // Status Badge
                          Wrap(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact
                                      ? 8
                                      : isMobile
                                          ? 10
                                          : 12,
                                  vertical: isCompact ? 4 : 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isActive
                                        ? [
                                            Colors.green.shade50,
                                            Colors.green.shade100
                                          ]
                                        : [
                                            Colors.orange.shade50,
                                            Colors.orange.shade100
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isCompact ? 16 : 20,
                                  ),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: isCompact ? 5 : 6,
                                      height: isCompact ? 5 : 6,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green
                                            : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: isCompact ? 4 : 6),
                                    Text(
                                      isActive ? 'ใช้งานอยู่' : 'ปิดการใช้งาน',
                                      style: TextStyle(
                                        fontSize: isCompact ? 10 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
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

                    // Actions Menu
                    SizedBox(width: isCompact ? 4 : 8),
                    Flexible(
                      flex: 0,
                      child: _buildActionsMenu(tenant, _canManage, isActive),
                    ),
                  ],
                ),

                SizedBox(height: verticalSpacing),

                // Info Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: constraints.maxWidth,
                      padding: EdgeInsets.all(
                        isCompact
                            ? 10
                            : isMobile
                                ? 14
                                : isTablet
                                    ? 16
                                    : 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.shade50,
                            Colors.grey.shade100.withOpacity(0.5),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(contentBorderRadius),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ID Card Row
                          _buildInfoRow(
                            icon: Icons.badge_rounded,
                            iconColor: Colors.indigo,
                            label: 'เลขบัตรประชาชน',
                            value: _formatIdCard(
                                tenant['tenant_idcard'] ?? 'ไม่ระบุ'),
                            labelSize: labelSize,
                            valueSize: subtitleSize,
                            iconSize: iconSize,
                            isCompact: isCompact,
                            isMobile: isMobile,
                            isDesktop: isDesktop,
                          ),

                          SizedBox(
                              height: isCompact
                                  ? 8
                                  : isMobile
                                      ? 10
                                      : 12),

                          // Phone Row
                          _buildInfoRow(
                            icon: Icons.phone_rounded,
                            iconColor: Colors.blue,
                            label: 'เบอร์โทรศัพท์',
                            value: _formatPhoneNumber(
                                tenant['tenant_phone'] ?? 'ไม่ระบุ'),
                            labelSize: labelSize,
                            valueSize: subtitleSize,
                            iconSize: iconSize,
                            isCompact: isCompact,
                            isMobile: isMobile,
                            isDesktop: isDesktop,
                          ),

                          SizedBox(
                              height: isCompact
                                  ? 8
                                  : isMobile
                                      ? 10
                                      : 12),

                          // Branch Row with Manager Count
                          _buildBranchInfoRow(
                            hasBranch: hasBranch,
                            branchName: branchName,
                            managerCount: tenant['branch_manager_count'],
                            labelSize: labelSize,
                            valueSize: subtitleSize,
                            iconSize: iconSize,
                            isCompact: isCompact,
                            isMobile: isMobile,
                            isDesktop: isDesktop,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Gender Badge (if available)
                if (tenant['gender'] != null) ...[
                  SizedBox(
                      height: isCompact
                          ? 8
                          : isMobile
                              ? 10
                              : 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildGenderBadge(
                      tenant['gender'],
                      isCompact,
                      isMobile,
                      isDesktop,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper method for info rows
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double labelSize,
    required double valueSize,
    required double iconSize,
    required bool isCompact,
    required bool isMobile,
    required bool isDesktop,
  }) {
    final iconPadding = isCompact
        ? 7.0
        : isMobile
            ? 9.0
            : 10.0;
    final iconContainerSize = iconSize + (iconPadding * 2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 0,
          child: Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.1),
                  iconColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
        SizedBox(width: isCompact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for branch info row
  Widget _buildBranchInfoRow({
    required bool hasBranch,
    required String branchName,
    required dynamic managerCount,
    required double labelSize,
    required double valueSize,
    required double iconSize,
    required bool isCompact,
    required bool isMobile,
    required bool isDesktop,
  }) {
    final iconPadding = isCompact
        ? 7.0
        : isMobile
            ? 9.0
            : 10.0;
    final iconContainerSize = iconSize + (iconPadding * 2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 0,
          child: Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasBranch
                    ? [
                        Colors.purple.withOpacity(0.1),
                        Colors.purple.withOpacity(0.05),
                      ]
                    : [
                        Colors.orange.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
            ),
            child: Icon(
              Icons.business_rounded,
              size: iconSize,
              color:
                  hasBranch ? Colors.purple.shade700 : Colors.orange.shade700,
            ),
          ),
        ),
        SizedBox(width: isCompact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'สาขา',
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      branchName,
                      style: TextStyle(
                        fontSize: valueSize,
                        color:
                            hasBranch ? Colors.grey[900] : Colors.orange[700],
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            hasBranch ? FontStyle.normal : FontStyle.italic,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasBranch &&
                      managerCount != null &&
                      managerCount > 0) ...[
                    SizedBox(width: isCompact ? 6 : 8),
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 6 : 8,
                          vertical: isCompact ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade100,
                              Colors.blue.shade50,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isCompact ? 10 : 12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: isCompact ? 10 : 12,
                              color: Colors.blue.shade700,
                            ),
                            SizedBox(width: isCompact ? 3 : 4),
                            Text(
                              '$managerCount',
                              style: TextStyle(
                                fontSize: isCompact ? 10 : 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

// Gender Badge
  Widget _buildGenderBadge(
    String gender,
    bool isCompact,
    bool isMobile,
    bool isDesktop,
  ) {
    final genderData = _getGenderData(gender);
    final badgeIconSize = isCompact
        ? 12.0
        : isMobile
            ? 13.0
            : 14.0;
    final badgeFontSize = isCompact
        ? 11.0
        : isMobile
            ? 11.5
            : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact
            ? 8
            : isMobile
                ? 10
                : 12,
        vertical: isCompact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            genderData['color'].withOpacity(0.1),
            genderData['color'].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
        border: Border.all(
          color: genderData['color'].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            genderData['icon'],
            size: badgeIconSize,
            color: genderData['color'],
          ),
          SizedBox(width: isCompact ? 5 : 6),
          Text(
            genderData['label'],
            style: TextStyle(
              fontSize: badgeFontSize,
              color: genderData['color'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

// Format ID Card
  String _formatIdCard(String idCard) {
    if (idCard == 'ไม่ระบุ' || idCard.length != 13) return idCard;
    return '${idCard.substring(0, 1)}-${idCard.substring(1, 5)}-${idCard.substring(5, 10)}-${idCard.substring(10, 12)}-${idCard.substring(12)}';
  }

// Format Phone Number
  String _formatPhoneNumber(String phone) {
    if (phone == 'ไม่ระบุ' || phone.length != 10) return phone;
    return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
  }

// Get Gender Data
  Map<String, dynamic> _getGenderData(String gender) {
    switch (gender) {
      case 'male':
        return {
          'label': 'ชาย',
          'icon': Icons.male_rounded,
          'color': Colors.blue.shade600,
        };
      case 'female':
        return {
          'label': 'หญิง',
          'icon': Icons.female_rounded,
          'color': Colors.pink.shade600,
        };
      default:
        return {
          'label': 'อื่นๆ',
          'icon': Icons.transgender_rounded,
          'color': Colors.purple.shade600,
        };
    }
  }

  Widget _buildActionsMenu(
      Map<String, dynamic> tenant, bool canManage, bool isActive) {
    final tenantId = tenant['tenant_id'];
    final isSuperAdmin = _currentUser?.userRole == UserRole.superAdmin;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[700], size: 20),
      tooltip: 'การทำงาน',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'view':
            if (_isAnonymous) {
              _showLoginPrompt('ดูรายละเอียด');
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantDetailUI(tenantId: tenantId),
              ),
            );
            if (result == true && mounted) {
              await _loadTenants();
            }
            break;
          case 'edit':
            if (_isAnonymous) {
              _showLoginPrompt('แก้ไข');
              return;
            }
            if (!canManage) return;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenantEditUI(
                  tenantId: tenantId,
                  tenantData: tenant,
                ),
              ),
            );
            if (result == true && mounted) {
              await _loadTenants();
            }
            break;
          case 'toggle':
            if (_isAnonymous) {
              _showLoginPrompt(isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน');
              return;
            }
            if (!canManage) return;
            _toggleTenantStatus(
              tenant['tenant_id'],
              tenant['tenant_fullname'] ?? '',
              isActive,
            );
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: const [
              Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
              SizedBox(width: 12),
              Text('ดูรายละเอียด'),
            ],
          ),
        ),
        if (canManage) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                SizedBox(width: 12),
                Text('แก้ไข'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: isActive ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 12),
                Text(
                  isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                  style: TextStyle(
                    color: isActive ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileImage({
    required String? profileImageUrl,
    required String tenantName,
    required double size,
  }) {
    return Hero(
      tag: 'tenant_profile_$tenantName',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.primary.withOpacity(0.1),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? Image.network(
                  profileImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildProfileFallback(tenantName, size);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    );
                  },
                )
              : _buildProfileFallback(tenantName, size),
        ),
      ),
    );
  }

  Widget _buildProfileFallback(String tenantName, double size) {
    return Container(
      color: AppTheme.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          _getInitials(tenantName),
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
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
