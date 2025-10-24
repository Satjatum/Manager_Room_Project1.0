import 'package:flutter/material.dart';
import 'package:manager_room_project/views/widgets/mainnavbar.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/issue_service.dart';
// Quick navigation targets
import 'package:manager_room_project/views/sadmin/branchlist_ui.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_ui.dart';
import 'package:manager_room_project/views/sadmin/meterlist_ui.dart';
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_ui.dart';
import 'package:manager_room_project/views/sadmin/user_management_ui.dart';

class SuperadmindashUi extends StatefulWidget {
  const SuperadmindashUi({super.key});

  @override
  State<SuperadmindashUi> createState() => _SuperadmindashUiState();
}

class _SuperadmindashUiState extends State<SuperadmindashUi> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = ทุกสาขา
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await BranchService.getActiveBranches();
      setState(() {
        _branches = branches;
        _selectedBranchId = null; // ค่าเริ่มต้น: ทุกสาขา
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _getStatsForBranch(String branchId) async {
    // ดึงสถิติเกี่ยวกับห้อง + รายได้/ค้างชำระ + ปัญหา
    final roomStats = await BranchService.getBranchStatistics(branchId);
    final now = DateTime.now();
    final invoiceStats = await InvoiceService.getInvoiceStats(
      branchId: branchId,
      month: now.month,
      year: now.year,
    );
    final issueStats =
        await IssueService.getIssueStatistics(branchId: branchId);

    return {
      ...roomStats,
      'invoice': invoiceStats,
      'issues': issueStats,
    };
  }

  Future<List<Map<String, dynamic>>> _getAllBranchesStats() async {
    final futures = _branches.map((b) async {
      final stats = await _getStatsForBranch(b['branch_id']);
      return {
        'branch_id': b['branch_id'],
        'branch_name': b['branch_name'],
        'stats': stats,
      };
    }).toList();
    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const Mainnavbar(currentIndex: 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadBranches)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.dashboard_rounded,
                                  color: AppTheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Super Admin Dashboard',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ภาพรวมหลายสาขาและลัดไปยังหน้าสำคัญ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'รีเฟรช',
                              onPressed: _loadBranches,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),

                      // Branch filter styled like branchlist_ui
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                                  child: DropdownButton<String?>(
                                    value: _selectedBranchId,
                                    isExpanded: true,
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    onChanged: (val) =>
                                        setState(() => _selectedBranchId = val),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('ทุกสาขา'),
                                      ),
                                      ..._branches.map(
                                        (b) => DropdownMenuItem<String?>(
                                          value: b['branch_id'] as String?,
                                          child: Text(b['branch_name'] ?? '-'),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick navigation buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _QuickActions(
                          onOpenBranches: () => _openPage(const BranchlistUi()),
                          onOpenRooms: () => _openPage(RoomListUI(
                            branchId: _selectedBranchId,
                            branchName: _selectedBranchId == null
                                ? null
                                : _branches.firstWhere(
                                    (b) => b['branch_id'] == _selectedBranchId,
                                    orElse: () => {},
                                  )['branch_name'],
                          )),
                          onOpenTenants: () => _openPage(TenantListUI(
                            branchId: _selectedBranchId,
                            branchName: _selectedBranchId == null
                                ? null
                                : _branches.firstWhere(
                                    (b) => b['branch_id'] == _selectedBranchId,
                                    orElse: () => {},
                                  )['branch_name'],
                          )),
                          onOpenMeters: () =>
                              _openPage(const MeterReadingsListPage()),
                          onOpenIssues: () =>
                              _openPage(const IssuesListScreen()),
                          onOpenPayments: () =>
                              _openPage(const PaymentVerificationPage()),
                          onOpenUsers: () =>
                              _openPage(const UserManagementUi()),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Stats content
                      Expanded(
                        child: _selectedBranchId == null
                            ? FutureBuilder<List<Map<String, dynamic>>>(
                                future: _getAllBranchesStats(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  if (snapshot.hasError) {
                                    return _ErrorView(
                                      message: snapshot.error.toString(),
                                      onRetry: _loadBranches,
                                    );
                                  }
                                  final items = snapshot.data ?? [];
                                  if (items.isEmpty) {
                                    return const _EmptyView(
                                        message: 'ไม่พบสาขาที่ใช้งาน');
                                  }
                                  return RefreshIndicator(
                                    onRefresh: _loadBranches,
                                    color: AppTheme.primary,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 12, 24, 24),
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        final stats = Map<String, dynamic>.from(
                                            item['stats'] as Map);
                                        return _BranchStatsCard(
                                          title: item['branch_name'] ?? '-',
                                          stats: stats,
                                        );
                                      },
                                    ),
                                  );
                                },
                              )
                            : FutureBuilder<Map<String, dynamic>>(
                                future: _getStatsForBranch(_selectedBranchId!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  if (snapshot.hasError) {
                                    return _ErrorView(
                                      message: snapshot.error.toString(),
                                      onRetry: _loadBranches,
                                    );
                                  }
                                  final stats = snapshot.data ?? {};
                                  final name = _branches.firstWhere(
                                        (b) =>
                                            b['branch_id'] == _selectedBranchId,
                                        orElse: () => {'branch_name': 'สาขา'},
                                      )['branch_name'] ??
                                      'สาขา';
                                  return RefreshIndicator(
                                    onRefresh: _loadBranches,
                                    color: AppTheme.primary,
                                    child: ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 12, 24, 24),
                                      children: [
                                        _BranchStatsCard(
                                            title: name, stats: stats),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _BranchFilter extends StatelessWidget {
  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId; // null = ทุกสาขา
  final ValueChanged<String?> onChanged;

  const _BranchFilter({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          const Text('สาขา: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              value: selectedBranchId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('ทุกสาขา'),
                ),
                ...branches.map(
                  (b) => DropdownMenuItem<String?>(
                    value: b['branch_id'] as String?,
                    child: Text(b['branch_name'] ?? '-'),
                  ),
                )
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchStatsCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> stats;

  const _BranchStatsCard({required this.title, required this.stats});

  int _asInt(dynamic v) => (v is int)
      ? v
      : (v is num)
          ? v.toInt()
          : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final total = _asInt(stats['total_rooms']);
    final occ = _asInt(stats['occupied_rooms']);
    final avail = _asInt(stats['available_rooms']);
    final maint = _asInt(stats['maintenance_rooms']);
    final occRate = _asInt(stats['occupancy_rate']);
    final invoice = Map<String, dynamic>.from(stats['invoice'] ?? {});
    final issues = Map<String, dynamic>.from(stats['issues'] ?? {});
    final totalRevenue = (invoice['total_revenue'] ?? 0).toString();
    final collected = (invoice['collected_amount'] ?? 0).toString();
    final pendingAmt = (invoice['pending_amount'] ?? 0).toString();
    final pendingIssues = _asInt(issues['pending']);
    final inProgressIssues = _asInt(issues['in_progress']);
    final resolvedIssues = _asInt(issues['resolved']);

    return Container(
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(
                    label: 'ห้องทั้งหมด',
                    value: total.toString(),
                    icon: Icons.meeting_room),
                _StatTile(
                    label: 'มีผู้เช่า',
                    value: occ.toString(),
                    icon: Icons.people),
                _StatTile(
                    label: 'ว่าง',
                    value: avail.toString(),
                    icon: Icons.event_available),
                _StatTile(
                    label: 'ซ่อมบำรุง',
                    value: maint.toString(),
                    icon: Icons.build),
                _StatTile(
                    label: 'อัตราเข้าพัก',
                    value: '$occRate%',
                    icon: Icons.percent),
                _StatTile(
                    label: 'รายได้รวม (เดือนนี้)',
                    value: totalRevenue,
                    icon: Icons.payments),
                _StatTile(
                    label: 'ชำระแล้ว', value: collected, icon: Icons.task_alt),
                _StatTile(
                    label: 'ค้างชำระ',
                    value: pendingAmt,
                    icon: Icons.warning_amber_rounded),
                _StatTile(
                    label: 'ปัญหา - รอรับ',
                    value: pendingIssues.toString(),
                    icon: Icons.report_gmailerrorred),
                _StatTile(
                    label: 'ปัญหา - ดำเนินการ',
                    value: inProgressIssues.toString(),
                    icon: Icons.build_circle),
                _StatTile(
                    label: 'ปัญหา - ปิดงาน',
                    value: resolvedIssues.toString(),
                    icon: Icons.verified),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: Colors.grey[800]),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenBranches;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenTenants;
  final VoidCallback onOpenMeters;
  final VoidCallback onOpenIssues;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenUsers;

  const _QuickActions({
    required this.onOpenBranches,
    required this.onOpenRooms,
    required this.onOpenTenants,
    required this.onOpenMeters,
    required this.onOpenIssues,
    required this.onOpenPayments,
    required this.onOpenUsers,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.business_outlined,
        label: 'สาขา',
        onTap: onOpenBranches,
      ),
      _QuickActionItem(
        icon: Icons.meeting_room_outlined,
        label: 'ห้องพัก',
        onTap: onOpenRooms,
      ),
      _QuickActionItem(
        icon: Icons.people_outline,
        label: 'ผู้เช่า',
        onTap: onOpenTenants,
      ),
      _QuickActionItem(
        icon: Icons.speed_outlined,
        label: 'มิเตอร์',
        onTap: onOpenMeters,
      ),
      _QuickActionItem(
        icon: Icons.report_problem_outlined,
        label: 'ปัญหา',
        onTap: onOpenIssues,
      ),
      _QuickActionItem(
        icon: Icons.verified_outlined,
        label: 'ชำระเงิน',
        onTap: onOpenPayments,
      ),
      _QuickActionItem(
        icon: Icons.admin_panel_settings_outlined,
        label: 'ผู้ดูแล',
        onTap: onOpenUsers,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      // Responsive grid count
      int crossAxisCount = 2;
      final w = constraints.maxWidth;
      if (w > 1200) {
        crossAxisCount = 6;
      } else if (w > 900) {
        crossAxisCount = 5;
      } else if (w > 700) {
        crossAxisCount = 4;
      } else if (w > 500) {
        crossAxisCount = 3;
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          return _QuickActionCard(item: it);
        },
      );
    });
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionItem(
      {required this.icon, required this.label, required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
