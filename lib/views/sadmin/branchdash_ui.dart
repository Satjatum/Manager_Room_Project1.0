import 'package:flutter/material.dart';
//  Page //
import 'invoicelist_ui.dart';
import 'roomlist_ui.dart';
import 'tenantlist_ui.dart';
import 'issuelist_ui.dart';
import 'meterlist_ui.dart';
import 'meter_billing_ui.dart';
import 'payment_verification_ui.dart';
import 'settingbranch_ui.dart';
// Services //
import '../../services/branch_service.dart';
import '../../services/issue_service.dart';
import '../../services/invoice_service.dart';
// Widget //
import '../widgets/colors.dart';

class BranchDashboardPage extends StatelessWidget {
  final String? branchId;
  final String? branchName;

  const BranchDashboardPage({Key? key, this.branchId, this.branchName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future<bool> _confirmExit() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.exit_to_app,
                    color: Colors.blue.shade600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'ออกจากแดชบอร์ดสาขา',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'คุณต้องการกลับไปหน้าก่อนหน้าหรือไม่?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
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
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
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
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ยืนยัน',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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

      return confirm == true;
    }

    Future<Map<String, dynamic>> _loadStats() async {
      final String? bId = branchId;
      if (bId == null || bId.isEmpty) {
        return {
          'total_rooms': 0,
          'occupied_rooms': 0,
          'available_rooms': 0,
          'maintenance_rooms': 0,
          'occupancy_rate': 0,
          'issue_pending': 0,
          'invoice_pending': 0,
        };
      }

      final branchStats = await BranchService.getBranchStatistics(bId);
      final issueStats = await IssueService.getIssueStatistics(branchId: bId);
      final invoiceStats = await InvoiceService.getInvoiceStats(branchId: bId);

      return {
        'total_rooms': branchStats['total_rooms'] ?? 0,
        'occupied_rooms': branchStats['occupied_rooms'] ?? 0,
        'available_rooms': branchStats['available_rooms'] ?? 0,
        'maintenance_rooms': branchStats['maintenance_rooms'] ?? 0,
        'occupancy_rate': branchStats['occupancy_rate'] ?? 0,
        'issue_pending': issueStats['pending'] ?? 0,
        'invoice_pending': invoiceStats['pending'] ?? 0,
      };
    }

    // Quick actions (ตามที่กำหนด)
    final items = [
      _DashItem(
        icon: Icons.meeting_room_outlined,
        label: 'ห้องพัก',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomListUi(
              branchId: branchId,
              branchName: branchName,
              hideBottomNav: true,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.people_outline,
        label: 'ผู้เช่า',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TenantListUI(
              branchId: branchId,
              branchName: branchName,
              hideBottomNav: true,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.report_problem_outlined,
        label: 'แจ้งปัญหา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IssueListUi(
              branchId: branchId,
              branchName: branchName,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.speed_outlined,
        label: 'มิเตอร์',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MeterListUi(
              branchId: branchId,
              branchName: branchName,
              hideBottomNav: true,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.receipt_outlined,
        label: 'ออกบิล',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MeterBillingPage(
              branchId: branchId,
              branchName: branchName,
              hideBottomNav: true,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.document_scanner_outlined,
        label: 'รายการบิล',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceListUi(
              branchId: branchId,
            ),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.verified_outlined,
        label: 'ตรวจสอบบิล',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentVerificationUi(branchId: branchId),
          ),
        ),
      ),
      _DashItem(
        icon: Icons.settings_outlined,
        label: 'ตั้งค่าสาขา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingbranchUi(
              branchId: branchId ?? '',
              branchName: branchName,
            ),
          ),
        ),
      ),
    ];

    Widget _statsFuture({required bool isCompact}) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: LinearProgressIndicator(minHeight: 2),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'เกิดข้อผิดพลาดในการโหลดสถิติ: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final int totalRooms = (data['total_rooms'] ?? 0) as int;
          final int occupied = (data['occupied_rooms'] ?? 0) as int;
          final int available = (data['available_rooms'] ?? 0) as int;
          final int maintenance = (data['maintenance_rooms'] ?? 0) as int;
          final int occRate = (data['occupancy_rate'] ?? 0) as int;
          final int issuePending = (data['issue_pending'] ?? 0) as int;
          final int invoicePending = (data['invoice_pending'] ?? 0) as int;

          double _ratio(int part) => totalRooms > 0 ? part / totalRooms : 0.0;

          final stats = <_StatItem>[
            _StatItem(
              title: 'ห้องทั้งหมด',
              value: '$totalRooms',
              trendText: '',
              isUp: true,
              leading: Icons.meeting_room_outlined,
              progress: totalRooms == 0 ? 0.0 : 1.0,
            ),
            _StatItem(
              title: 'มีผู้เช่า',
              value: '$occupied',
              trendText: '',
              isUp: true,
              leading: Icons.people_alt_outlined,
              progress: _ratio(occupied),
            ),
            _StatItem(
              title: 'ว่าง',
              value: '$available',
              trendText: '',
              isUp: false,
              leading: Icons.hotel_class_outlined,
              progress: _ratio(available),
            ),
            _StatItem(
              title: 'ซ่อมบำรุง',
              value: '$maintenance',
              trendText: '',
              isUp: false,
              leading: Icons.build_outlined,
              progress: _ratio(maintenance),
            ),
            _StatItem(
              title: 'อัตราเข้าพัก',
              value: '${occRate.toString()}%',
              trendText: '',
              isUp: true,
              leading: Icons.pie_chart_outline,
              progress: (occRate.clamp(0, 100)) / 100.0,
            ),
            _StatItem(
              title: 'ปัญหาค้าง',
              value: '$issuePending',
              trendText: '',
              isUp: false,
              leading: Icons.report_problem_outlined,
              progress: null,
            ),
            _StatItem(
              title: 'บิลค้าง',
              value: '$invoicePending',
              trendText: '',
              isUp: false,
              leading: Icons.receipt_long_outlined,
              progress: null,
            ),
          ];

          return _StatsSection(stats: stats, isCompact: isCompact);
        },
      );
    }

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section (theme-aligned with branchlist_ui / settingbranch_ui)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black87),
                      onPressed: () async {
                        if (await _confirmExit()) {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      tooltip: 'ย้อนกลับ',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'แดชบอร์ดสาขา',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (branchName == null || branchName!.isEmpty)
                                ? 'เลือกเมนูการทำงานของสาขา'
                                : 'เลือกเมนูการทำงานของสาขา',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          // เอารหัสสาขาออก และย้ายชื่อสาขาไปแสดงในส่วนเนื้อหาด้านล่างเป็น Card
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content section — Responsive breakpoints; center only on phone
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // แสดงเต็มความกว้างหน้าจอ และปรับย่ออัตโนมัติตามขนาดหน้าจอ
                    final bool isCompact = constraints.maxWidth < 600;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if ((branchName ?? '').isNotEmpty)
                          _BranchNameCard(name: branchName!),
                        const SizedBox(height: 12),
                        _statsFuture(isCompact: isCompact),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            'เมนู',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _QuickActionsWrap(items: items),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------- Today's Performance ----------------------
class _StatItem {
  final String title;
  final String value;
  final String trendText; // e.g. +5.2%
  final bool isUp;
  final IconData leading;
  final double? progress; // 0..1 สำหรับแสดงแถบความคืบหน้า

  _StatItem({
    required this.title,
    required this.value,
    required this.trendText,
    required this.isUp,
    required this.leading,
    this.progress,
  });
}

class _StatsSection extends StatelessWidget {
  final List<_StatItem> stats;
  final bool isCompact; // kept for potential fine-tuning
  const _StatsSection({required this.stats, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "สถิติ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 14;
            final bool isMobile = constraints.maxWidth < 600;

            // สำหรับมือถือ: แสดง 2 บรรทัด แต่ละคอลัมน์มี 2 cards (บน-ล่าง)
            if (isMobile) {
              final double cardWidth = (constraints.maxWidth - spacing) / 2;
              final int columns = (stats.length / 2).ceil();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int col = 0; col < columns; col++) ...[
                      Column(
                        children: [
                          // Card บน
                          SizedBox(
                            width: cardWidth,
                            child: _StatCard(item: stats[col * 2]),
                          ),
                          // Card ล่าง (ถ้ามี)
                          if (col * 2 + 1 < stats.length) ...[
                            SizedBox(height: spacing),
                            SizedBox(
                              width: cardWidth,
                              child: _StatCard(item: stats[col * 2 + 1]),
                            ),
                          ],
                        ],
                      ),
                      if (col != columns - 1) SizedBox(width: spacing),
                    ],
                  ],
                ),
              );
            }
            // สำหรับหน้าจอใหญ่ที่มี stats > 4
            else if (stats.length > 4) {
              final double tileW = constraints.maxWidth < 1200 ? 220 : 240;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < stats.length; i++) ...[
                      SizedBox(width: tileW, child: _StatCard(item: stats[i])),
                      if (i != stats.length - 1) const SizedBox(width: spacing),
                    ],
                  ],
                ),
              );
            }
            // สำหรับกรณีที่มี stats <= 4 บนหน้าจอใหญ่
            else {
              final int columns = stats.isEmpty ? 1 : stats.length;
              final double itemW =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final s in stats)
                    SizedBox(width: itemW, child: _StatCard(item: s)),
                ],
              );
            }
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final Color trendColor =
        item.isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final IconData trendIcon =
        item.isUp ? Icons.trending_up : Icons.trending_down;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.leading, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          // Progress bar removed per request; show trend only if provided
          if (item.trendText.isNotEmpty)
            Row(
              children: [
                Icon(trendIcon, size: 16, color: trendColor),
                const SizedBox(width: 6),
                Text(
                  item.trendText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------- Quick Actions Wrap ----------------------
class _QuickActionsWrap extends StatelessWidget {
  final List<_DashItem> items;
  const _QuickActionsWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;
        final double spacing = 10;
        final double minTileW =
            isCompact ? 100 : 130; // ทำปุ่มเล็กลงให้ wrap ได้แน่นขึ้น
        int columns = (constraints.maxWidth / (minTileW)).floor();
        if (columns < 1) columns = 1; // ไม่กำหนดจำนวนตายตัว ให้ขึ้นกับหน้าจอ
        final double itemW =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final it in items)
              SizedBox(
                width: itemW,
                child: _DashCard(item: it),
              )
          ],
        );
      },
    );
  }
}

class _DashItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _DashItem({required this.icon, required this.label, required this.onTap});
}

class _DashCard extends StatelessWidget {
  final _DashItem item;
  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ชิปแสดงข้อมูล (กรอบ + ไอคอน) สำหรับชื่อสาขา/รหัสสาขา
class _BranchNameCard extends StatelessWidget {
  final String name;
  const _BranchNameCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.business, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
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
      ),
    );
  }
}
