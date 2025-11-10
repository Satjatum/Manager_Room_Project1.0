import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/issuelist_detail_ui.dart';
import 'package:manager_room_project/views/tenant/issue_add_ui.dart';
import '../../services/issue_service.dart';
import '../../services/auth_service.dart';
import '../../services/branch_service.dart';
import '../../models/user_models.dart';
import '../widgets/colors.dart';

class IssueListUi extends StatefulWidget {
  final String? branchId;
  final String? branchName;
  const IssueListUi({
    Key? key,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<IssueListUi> createState() => _IssueListUiState();
}

class _IssueListUiState extends State<IssueListUi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  UserModel? _currentUser;

  List<Map<String, dynamic>> _allIssues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _branches = [];

  String _selectedType = 'all';
  String? _selectedBranchId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    // Initialize locked branch context if provided
    _selectedBranchId = widget.branchId;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _applyFilters();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      _currentUser = await AuthService.getCurrentUser();

      if (_currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load sequentially to ensure issues are ready before computing statistics
      await _loadBranches();
      await _loadIssues();
      await _loadStatistics();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _loadBranches() async {
    try {
      if (_currentUser?.userRole == UserRole.superAdmin) {
        _branches = await BranchService.getAllBranches();
      } else if (_currentUser?.userRole == UserRole.admin) {
        _branches = await BranchService.getBranchesByUser();
      }
    } catch (e) {
      print('Error loading branches: $e');
      _branches = [];
    }
  }

  Future<void> _loadIssues() async {
    try {
      // Role-based visibility
      if (_currentUser?.userRole == UserRole.tenant) {
        // Tenants: only their own issues (service enforces tenant_id)
        _allIssues = await IssueService.getIssuesByUser();
      } else if (_currentUser?.userRole == UserRole.admin ||
          _currentUser?.userRole == UserRole.superAdmin) {
        // Admin/Superadmin: see all issues in the selected branch (if any)
        _allIssues = await IssueService.getAllIssues(
          branchId: _selectedBranchId,
        );
      } else {
        // Fallback to user-based scope
        _allIssues = await IssueService.getIssuesByUser(
          branchId: _selectedBranchId,
        );
      }
      _applyFilters();
    } catch (e) {
      print('Error loading issues: $e');
      _allIssues = [];
      _filteredIssues = [];
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // For Admin without a specific branch filter, aggregate from loaded issues (managed branches only)
      if (_currentUser?.userRole == UserRole.admin &&
          (_selectedBranchId == null || _selectedBranchId!.isEmpty)) {
        _statistics = _computeStatisticsFromIssues(_allIssues);
        setState(() {});
        return;
      }

      _statistics = await IssueService.getIssueStatistics(
        branchId: _selectedBranchId,
      );
      setState(() {});
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Map<String, dynamic> _computeStatisticsFromIssues(
      List<Map<String, dynamic>> issues) {
    int total = issues.length;
    int pending = issues.where((i) => i['issue_status'] == 'pending').length;
    int inProgress =
        issues.where((i) => i['issue_status'] == 'in_progress').length;
    int resolved = issues.where((i) => i['issue_status'] == 'resolved').length;
    int cancelled =
        issues.where((i) => i['issue_status'] == 'cancelled').length;

    return {
      'total': total,
      'pending': pending,
      'in_progress': inProgress,
      'resolved': resolved,
      'cancelled': cancelled,
    };
  }

  void _applyFilters() {
    if (!mounted || _allIssues.isEmpty) {
      setState(() => _filteredIssues = []);
      return;
    }

    List<Map<String, dynamic>> filtered = List.from(_allIssues);

    // Filter by tab status
    String tabStatus = _getStatusFromTab(_tabController.index);
    if (tabStatus != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_status'] == tabStatus)
          .toList();
    }

    // Filter by branch (for superadmin/admin)
    if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
      filtered = filtered
          .where((issue) => issue['branch_id'] == _selectedBranchId)
          .toList();
    }

    // Filter by type
    if (_selectedType != 'all') {
      filtered = filtered
          .where((issue) => issue['issue_type'] == _selectedType)
          .toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((issue) {
        final issueNum = issue['issue_num']?.toString().toLowerCase() ?? '';
        final title = issue['issue_title']?.toString().toLowerCase() ?? '';
        final roomNumber = issue['room_number']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return issueNum.contains(query) ||
            title.contains(query) ||
            roomNumber.contains(query);
      }).toList();
    }

    setState(() => _filteredIssues = filtered);
  }

  String _getStatusFromTab(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'pending';
      case 2:
        return 'in_progress';
      case 3:
        return 'resolved';
      case 4:
        return 'cancelled';
      default:
        return 'all';
    }
  }

  int _getIssueCountByStatus(String status) {
    if (_statistics.isEmpty) return 0;
    if (status == 'all') return _statistics['total'] ?? 0;
    return _statistics[status] ?? 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  IconData _getIssueTypeIcon(String type) {
    switch (type) {
      case 'repair':
        return Icons.build;
      case 'maintenance':
        return Icons.engineering;
      case 'complaint':
        return Icons.report_problem;
      case 'suggestion':
        return Icons.lightbulb;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.info;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateIssue = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageIssues,
          DetailedPermission.createIssues,
        ]) ??
        false;

    final isTenant = _currentUser?.userRole == UserRole.tenant;
    final canFilterByBranch = _currentUser?.hasAnyPermission([
          DetailedPermission.all,
          DetailedPermission.manageBranches,
        ]) ??
        false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Section (branchlist style)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Title
                  Row(
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
                      if (!isTenant) const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'แจ้งปัญหา',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'สำหรับแจ้งปัญหา',
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

                  const SizedBox(height: 16),

                  // Search bar (branchlist style)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ค้นหาเลขที่แจ้ง, หัวข้อ, หมายเลขห้อง...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _applyFilters();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _applyFilters();
                      },
                    ),
                  ),

                  // Branch filter (for superadmin/admin)
                  if (canFilterByBranch &&
                      _branches.isNotEmpty &&
                      widget.branchId == null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBranchId ?? 'all',
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: [
                            const DropdownMenuItem<String>(
                                value: 'all', child: Text('ทุกสาขา')),
                            ..._branches.map((branch) {
                              return DropdownMenuItem<String>(
                                value: branch['branch_id'],
                                child: Text(branch['branch_name'] ?? ''),
                              );
                            }).toList(),
                          ],
                          onChanged: (String? value) async {
                            setState(() {
                              _selectedBranchId = value == 'all' ? null : value;
                            });
                            await _loadIssues();
                            await _loadStatistics();
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Statistics tracking bar (hidden for tenant)
                  if (!isTenant) _buildTrackingBar(),

                  const SizedBox(height: 12),

                  // Tab bar (neutral style)
                  Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      onTap: (index) => _applyFilters(),
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(text: "ทั้งหมด (${_getIssueCountByStatus('all')})"),
                        Tab(
                            text:
                                "รอดำเนินการ (${_getIssueCountByStatus('pending')})"),
                        Tab(
                            text:
                                "กำลังดำเนินการ (${_getIssueCountByStatus('in_progress')})"),
                        Tab(
                            text:
                                "เสร็จสิ้น (${_getIssueCountByStatus('resolved')})"),
                        Tab(
                            text:
                                "ยกเลิก (${_getIssueCountByStatus('cancelled')})"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Issues list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'กำลังโหลดข้อมูล...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredIssues.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primary,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            int cols = 1;
                            if (width >= 1200) {
                              cols = 4;
                            } else if (width >= 992) {
                              cols = 3;
                            } else if (width >= 768) {
                              cols = 2;
                            }

                            if (cols == 1) {
                              return ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _filteredIssues.length,
                                itemBuilder: (context, index) {
                                  final issue = _filteredIssues[index];
                                  return _buildIssueCard(issue);
                                },
                              );
                            }

                            double aspect;
                            if (cols >= 4) {
                              aspect = 0.95;
                            } else if (cols == 3) {
                              aspect = 1.05;
                            } else {
                              aspect = 1.1;
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: aspect,
                              ),
                              itemCount: _filteredIssues.length,
                              itemBuilder: (context, index) {
                                final issue = _filteredIssues[index];
                                return _buildIssueCard(issue);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: isTenant
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateIssueScreen(),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'แจ้งปัญหาใหม่',
            )
          : null,
      bottomNavigationBar: null,
    );
  }

  Widget _buildTrackingBar() {
    final total = _getIssueCountByStatus('all');
    final pending = _getIssueCountByStatus('pending');
    final inProgress = _getIssueCountByStatus('in_progress');
    final resolved = _getIssueCountByStatus('resolved');

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สถิติการแจ้งปัญหา',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'ทั้งหมด $total รายการ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (pending > 0)
                    Expanded(
                      flex: pending,
                      child: Container(color: Colors.orange),
                    ),
                  if (inProgress > 0)
                    Expanded(
                      flex: inProgress,
                      child: Container(color: Colors.blue),
                    ),
                  if (resolved > 0)
                    Expanded(
                      flex: resolved,
                      child: Container(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.orange, 'รอดำเนินการ', pending, total),
              _buildLegendItem(
                  Colors.blue, 'กำลังดำเนินการ', inProgress, total),
              _buildLegendItem(Colors.green, 'เสร็จสิ้น', resolved, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count, int total) {
    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // Tracking process stepper inside issue card
  Widget _buildTrackingProcess(String status) {
    final steps = const [
      {'key': 'pending', 'label': 'รอดำเนินการ'},
      {'key': 'in_progress', 'label': 'กำลังทำ'},
      {'key': 'resolved', 'label': 'เสร็จสิ้น'},
    ];

    int active = 0;
    switch (status) {
      case 'pending':
        active = 1;
        break;
      case 'in_progress':
        active = 2;
        break;
      case 'resolved':
        active = 3;
        break;
      case 'cancelled':
        active = 0; // cancelled -> no progress
        break;
      default:
        active = 0;
    }

    Color stepColor(int index) {
      if (status == 'cancelled') return Colors.grey;
      return index <= active ? AppTheme.primary : Colors.grey[300]!;
    }

    Color labelColor(int index) {
      if (status == 'cancelled') return Colors.grey;
      return index <= active ? AppTheme.primary : Colors.grey[600]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: stepColor(i + 1).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: stepColor(i + 1), width: 2),
                ),
                child: Icon(
                  i + 1 <= active ? Icons.check : Icons.circle,
                  size: 12,
                  color: stepColor(i + 1),
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(height: 2, color: stepColor(i + 1)),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
                  steps[i]['label'] as String,
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == steps.length - 1
                          ? TextAlign.right
                          : TextAlign.center),
                  style: TextStyle(
                    fontSize: 11,
                    color: labelColor(i + 1),
                    fontWeight:
                        i + 1 <= active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ไม่มีปัญหาในหมวดนี้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เมื่อมีการรายงานปัญหา จะแสดงในที่นี่',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final issueNum = issue['issue_num'] ?? '';
    final title = issue['issue_title'] ?? '';
    final roomNumber = issue['room_number'] ?? '';
    final branchName = issue['branch_name'] ?? '';
    final status = issue['issue_status'] ?? '';
    final type = issue['issue_type'] ?? '';
    final createdAt = issue['created_at'] != null
        ? DateTime.parse(issue['created_at'])
        : null;
    final assignedUserName = issue['assigned_user_name'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IssueListDetailUi(
                issueId: issue['issue_id'],
              ),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title first
              Row(
                children: [
                  Icon(_getIssueTypeIcon(type),
                      size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    issueNum,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _getStatusColor(status), width: 1),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Details (white box with grey border)
              Builder(builder: (context) {
                final roomCate = (issue['room_category_name'] ??
                        issue['room_type_name'] ??
                        issue['roomcate'] ??
                        '')
                    .toString();
                final roomInfo = roomCate.isNotEmpty
                    ? '$roomCate  $roomNumber'
                    : roomNumber.toString();
                final desc = (issue['issue_desc'] ?? '').toString();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.meeting_room,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              roomInfo,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Tracking Process
              _buildTrackingProcess(status),

              // Footer
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null ? _formatDateTime(createdAt) : 'ไม่ระบุ',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  if (assignedUserName != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_pin,
                            size: 14,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            assignedUserName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
