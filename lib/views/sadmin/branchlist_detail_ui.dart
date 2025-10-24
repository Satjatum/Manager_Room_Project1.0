import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_ui.dart';
import '../../models/user_models.dart';
import '../../middleware/auth_middleware.dart';
import '../../services/branch_service.dart';
import '../../services/branch_manager_service.dart';
import '../widgets/colors.dart';
import 'branch_edit_ui.dart';

class BranchListDetail extends StatefulWidget {
  final String branchId;

  const BranchListDetail({
    Key? key,
    required this.branchId,
  }) : super(key: key);

  @override
  State<BranchListDetail> createState() => _BranchListDetailState();
}

class _BranchListDetailState extends State<BranchListDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _branchManagers = [];
  Map<String, dynamic>? _branchData;
  Map<String, dynamic> _branchStats = {};
  bool _isLoadingManagers = false;
  bool _isLoading = true;
  UserModel? _currentUser;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    _loadBranchDetails();
  }

  Future<void> _loadBranchManagers() async {
    setState(() => _isLoadingManagers = true);
    try {
      final managers =
          await BranchManagerService.getBranchManagers(widget.branchId);
      if (mounted) {
        setState(() {
          _branchManagers = managers;
          _isLoadingManagers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManagers = false);
      }
      print('Error loading managers: $e');
    }
  }

  Future<void> _loadBranchDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final branchData = await BranchService.getBranchById(widget.branchId);
      final stats = await BranchService.getBranchStatistics(widget.branchId);
      await _loadBranchManagers();

      if (mounted) {
        setState(() {
          _branchData = branchData;
          _branchStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                    child:
                        Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _toggleBranchStatus() async {
    if (_isAnonymous || _branchData == null) return;

    final currentStatus = _branchData!['is_active'] ?? false;
    final branchName = _branchData!['branch_name'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentStatus
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                currentStatus
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: currentStatus
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                currentStatus ? 'Deactivate Branch' : 'Activate Branch',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Do you want to ${currentStatus ? 'deactivate' : 'activate'} the branch'),
            SizedBox(height: 4),
            Text(
              '"$branchName"',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(currentStatus ? 'Deactivate' : 'Activate'),
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
                  Text('Processing...'),
                ],
              ),
            ),
          ),
        );

        final result = await BranchService.toggleBranchStatus(widget.branchId);
        if (mounted) Navigator.pop(context);

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
            await _loadBranchDetails();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
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

  Future<void> _deleteBranch() async {
    if (_isAnonymous || _branchData == null) return;

    final branchName = _branchData!['branch_name'] ?? '';

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
              Text(
                'Delete Branch?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
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
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: Colors.red.shade600, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This action cannot be undone.\nAll data will be permanently deleted.',
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
                      child: Text('Cancel',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
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
                          Text('Delete',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
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
                        Icon(Icons.delete_sweep_rounded,
                            color: Colors.red.shade600, size: 28),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Deleting Branch',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
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

        final result =
            await BranchService.permanentDeleteBranch(widget.branchId);
        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (result['success']) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(result['message'] ??
                            'Branch deleted successfully')),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
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

  bool get _canManage {
    if (_isAnonymous) return false;
    if (_currentUser?.userRole == UserRole.superAdmin) return true;
    if (_currentUser?.userRole == UserRole.admin) {
      final uid = _currentUser!.userId;
      return _branchManagers.any((m) {
        final directId = m['user_id'];
        final nested = m['users'] as Map<String, dynamic>?;
        final nestedId = nested?['user_id'];
        return directId == uid || nestedId == uid;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Branch Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF10B981), strokeWidth: 3),
        ),
      );
    }

    if (_branchData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Branch Details'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              SizedBox(height: 16),
              Text(
                'Branch not found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
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

    final isActive = _branchData!['is_active'] ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildCustomHeader(isActive),

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
                      text: 'Details'),
                  Tab(
                      icon: Icon(Icons.analytics_outlined, size: 20),
                      text: 'Statistics'),
                  Tab(
                      icon: Icon(Icons.settings_outlined, size: 20),
                      text: 'Management'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildStatsTab(),
                  _buildManageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(bool isActive) {
    final hasImage = _branchData!['branch_image'] != null &&
        _branchData!['branch_image'].toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          // Top bar with back button
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Branch Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Branch Image
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[200],
            child: hasImage
                ? Image.network(
                    _branchData!['branch_image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),

          // Branch Info
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _branchData!['branch_name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (_branchData!['branch_code'] != null) ...[
                        SizedBox(height: 4),
                        Text(
                          'Code: ${_branchData!['branch_code']}',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                      SizedBox(height: 12),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              isActive ? Color(0xFF10B981) : Colors.grey[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 64, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _loadBranchDetails,
      color: Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(
              'Basic Information',
              Icons.info_outline,
              [
                _buildInfoRow('Branch Name',
                    _branchData!['branch_name'] ?? 'Not specified'),
                _buildInfoRow('Branch Code',
                    _branchData!['branch_code'] ?? 'Not specified'),
                _buildInfoRow(
                    'Phone', _branchData!['branch_phone'] ?? 'Not specified'),
                _buildInfoRow('Address',
                    _branchData!['branch_address'] ?? 'Not specified'),
              ],
            ),
            SizedBox(height: 20),
            _buildInfoSection(
              'Branch Managers',
              Icons.people_outline,
              [
                if (_isLoadingManagers)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF10B981)),
                    ),
                  )
                else if (_branchManagers.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No managers assigned',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey[600]),
                    ),
                  )
                else
                  ..._branchManagers
                      .map((manager) => _buildManagerCard(manager))
                      .toList(),
              ],
            ),
            if (_branchData!['branch_desc'] != null &&
                _branchData!['branch_desc'].toString().isNotEmpty) ...[
              SizedBox(height: 20),
              _buildInfoSection(
                'Description',
                Icons.description_outlined,
                [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _branchData!['branch_desc'],
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadBranchDetails,
      color: Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Rooms',
                    _branchStats['total_rooms']?.toString() ?? '0',
                    Icons.hotel_outlined,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Occupied',
                    _branchStats['occupied_rooms']?.toString() ?? '0',
                    Icons.people_outline,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Available',
                    _branchStats['available_rooms']?.toString() ?? '0',
                    Icons.meeting_room_outlined,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Maintenance',
                    _branchStats['maintenance_rooms']?.toString() ?? '0',
                    Icons.build_outlined,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildOccupancyCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildManageTab() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionCard(
            icon: Icons.hotel_outlined,
            title: 'View Rooms',
            subtitle: 'View all rooms in this branch',
            color: Colors.blue,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomListUI(
                    branchId: widget.branchId,
                    branchName: _branchData!['branch_name'] ?? '',
                  ),
                ),
              );
              if (result == true) await _loadBranchDetails();
            },
          ),
          SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.person_outline,
            title: 'View Tenants',
            subtitle: 'View all tenants in this branch',
            color: Colors.green,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TenantListUI(
                    branchId: widget.branchId,
                    branchName: _branchData!['branch_name'] ?? '',
                  ),
                ),
              );
              if (result == true) await _loadBranchDetails();
            },
          ),
          if (_canManage) ...[
            SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.edit_outlined,
              title: 'Edit Branch',
              subtitle: 'Update branch information and details',
              color: Color(0xFF14B8A6),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BranchEditPage(branchId: widget.branchId),
                  ),
                );
                if (result == true) await _loadBranchDetails();
              },
            ),
            SizedBox(height: 12),
            _buildActionCard(
              icon: isActive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              title: isActive ? 'Deactivate Branch' : 'Activate Branch',
              subtitle: isActive
                  ? 'Hide this branch from the system'
                  : 'Show this branch in the system',
              color: isActive ? Colors.orange : Colors.green,
              onTap: _toggleBranchStatus,
            ),
            if (_currentUser?.userRole == UserRole.superAdmin) ...[
              SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Branch',
                subtitle: 'Permanently delete this branch',
                color: Colors.red,
                onTap: _deleteBranch,
              ),
            ],
          ] else if (_isAnonymous) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please log in to access management features',
                      style:
                          TextStyle(color: Colors.blue.shade700, fontSize: 14),
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

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Color(0xFF10B981), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Text(': ',
              style: TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> manager) {
    final userData = manager['users'] as Map<String, dynamic>;
    final isPrimary = manager['is_primary'] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPrimary ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.blue.shade100 : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: isPrimary ? Colors.blue.shade700 : Colors.grey.shade700,
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData['user_name'] ?? 'No Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userData['user_email'] ?? 'No Email',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isPrimary)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Primary',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyCard() {
    final totalRooms = _branchStats['total_rooms'] ?? 0;
    final occupiedRooms = _branchStats['occupied_rooms'] ?? 0;
    final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) : 0.0;

    return Container(
      padding: EdgeInsets.all(20),
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
              Icon(Icons.analytics_outlined,
                  color: Color(0xFF10B981), size: 22),
              SizedBox(width: 10),
              Text(
                'Occupancy Rate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Occupancy',
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.grey[700]),
              ),
              Text(
                '${(occupancyRate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: occupancyRate > 0.8
                      ? Colors.green
                      : occupancyRate > 0.5
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: occupancyRate,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                occupancyRate > 0.8
                    ? Colors.green
                    : occupancyRate > 0.5
                        ? Colors.orange
                        : Colors.red,
              ),
              minHeight: 10,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Occupied',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$occupiedRooms',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Available',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${totalRooms - occupiedRooms}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  bool get isActive => _branchData?['is_active'] ?? false;
}
