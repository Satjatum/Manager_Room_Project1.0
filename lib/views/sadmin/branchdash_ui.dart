import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_ui.dart';
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/sadmin/meterlist_ui.dart';
import 'package:manager_room_project/views/sadmin/meter_billing_ui.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_ui.dart';
import 'package:manager_room_project/views/sadmin/settingbranch_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

class BranchDashboardPage extends StatelessWidget {
  final String? branchId;
  final String? branchName;

  const BranchDashboardPage({Key? key, this.branchId, this.branchName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future<bool> _confirmExit() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ออกจากแดชบอร์ดสาขา'),
          content: const Text('คุณต้องการกลับไปหน้าก่อนหน้าหรือไม่?'),
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
      return ok == true;
    }

    // Quick actions (ตามที่กำหนด)
    final items = [
      _DashItem(
        icon: Icons.meeting_room_outlined,
        label: 'ห้องพัก',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomListUI(
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
            builder: (_) => IssuelistUi(
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
            builder: (_) => MeterReadingsListPage(
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
        icon: Icons.verified_outlined,
        label: 'ตรวจสอบบิล',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentVerificationPage(branchId: branchId),
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

    // ตัวอย่างข้อมูลสถิติสำหรับ "Today's Performance"
    // สามารถเชื่อมต่อข้อมูลจริงภายหลังได้
    /* final stats = <_StatItem>[
      _StatItem(title: 'Total Sales', value: '', trendText: '+5.2%', isUp: true, 
          leading: Icons.attach_money),
      _StatItem(title: 'Customer Footfall', value: '86', trendText: '-1.5%', isUp: false, 
          leading: Icons.reduce_capacity_outlined),
      _StatItem(title: 'New Orders', value: '12', trendText: '+10%', isUp: true, 
          leading: Icons.shopping_bag_outlined),
      _StatItem(title: 'Completed Tasks', value: '25', trendText: '+3%', isUp: true, 
          leading: Icons.task_alt_outlined),
    ];
*/

    final stats = <_StatItem>[
      _StatItem(title: 'ห้องทั้งหมด', value: '120', trendText: '', isUp: true, leading: Icons.meeting_room_outlined, progress: 1.0),
      _StatItem(title: 'มีผู้เช่า', value: '102', trendText: '', isUp: true, leading: Icons.people_alt_outlined, progress: 0.85),
      _StatItem(title: 'ว่าง', value: '14', trendText: '', isUp: false, leading: Icons.hotel_class_outlined, progress: 0.15),
      _StatItem(title: 'ซ่อมบำรุง', value: '4', trendText: '', isUp: false, leading: Icons.build_outlined, progress: 0.03),
      _StatItem(title: 'อัตราเข้าพัก', value: '85%', trendText: '', isUp: true, leading: Icons.pie_chart_outline, progress: 0.85),
      _StatItem(title: 'ปัญหาค้าง', value: '7', trendText: '', isUp: false, leading: Icons.report_problem_outlined, progress: 0.14),
      _StatItem(title: 'บิลค้าง', value: '9', trendText: '', isUp: false, leading: Icons.receipt_long_outlined, progress: 0.18),
    ];

    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

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
                    final maxW = _maxContentWidth(constraints.maxWidth);
                    // กำหนดความกว้างสูงสุดของคอนเทนต์แล้วจัดวางภายในตามส่วนต่าง ๆ

                    final content = ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if ((branchName ?? '').isNotEmpty)
                          _BranchNameCard(name: branchName!),
                        const SizedBox(height: 12),
                        _StatsSection(stats: stats, isCompact: maxW < 600),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            'Quick Actions',
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

                    if (isMobileApp) {
                      // Center on native phones
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: content,
                        ),
                      );
                    }
                    // Desktop/Web: left align within responsive max width
                    return Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: content,
                      ),
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
  final bool isCompact; // ใช้สำหรับ mobile layout
  const _StatsSection({required this.stats, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Today's Performance",
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
            // Mobile/จอเล็ก: แสดงเป็นหน้าละ 4 สถิติ (2x2) แบบปัดหน้าได้
            if (isCompact) {
              final pages = <Widget>[];
              for (int i = 0; i < stats.length; i += 4) {
                final slice = stats.sublist(i, (i + 4).clamp(0, stats.length));
                pages.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        for (final s in slice) _StatCard(item: s),
                      ],
                    ),
                  ),
                );
              }
              // ความสูงแต่ละหน้าให้พอสำหรับ 2 แถว
              final double gridHeight = 250;
              return SizedBox(
                height: gridHeight,
                child: PageView(
                  children: pages,
                ),
              );
            }

            // จอใหญ่: autowrap 4 คอลัมน์
            final double spacing = 12;
            const int columns = 4;
            final double itemW = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final s in stats)
                  SizedBox(width: itemW, child: _StatCard(item: s)),
              ],
            );
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
    final Color trendColor = item.isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final IconData trendIcon = item.isUp ? Icons.trending_up : Icons.trending_down;

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
          if (item.progress != null)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: LinearProgressIndicator(
                      value: item.progress!.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${(item.progress! * 100).round()}%",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          if (item.progress == null && item.trendText.isNotEmpty)
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
            )
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
        final double minTileW = isCompact ? 100 : 130; // ทำปุ่มเล็กลงให้ wrap ได้แน่นขึ้น
        final int columns = (constraints.maxWidth / (minTileW)).floor().clamp(2, 6);
        final double itemW = (constraints.maxWidth - spacing * (columns - 1)) / columns;
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

// Responsive content widths (Mobile S/M/L, Tablet, Laptop, Laptop L, 4K)
double _maxContentWidth(double screenWidth) {
  if (screenWidth >= 2560) return 1280; // 4K
  if (screenWidth >= 1440) return 1100; // Laptop L
  if (screenWidth >= 1200) return 1000; // Laptop
  if (screenWidth >= 900) return 860; // Tablet landscape / small desktop
  if (screenWidth >= 600) return 560; // Mobile L / Tablet portrait
  return screenWidth; // Mobile S/M
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
