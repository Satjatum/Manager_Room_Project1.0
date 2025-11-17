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
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/services/issue_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';

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

    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: _PageTheme.pageBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double screenW = constraints.maxWidth;

              // Header ด้านบน (พื้นหลังขาว)
              final header = Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black87,
                      ),
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
                          const Text(
                            'แดชบอร์ดสาขา',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เลือกเมนูการทำงานของสาขา',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

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
                        _statsFuture(isCompact: maxW < 600),
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

class _DashCard extends StatefulWidget {
  final _DashItem item;
  const _DashCard({required this.item});

  @override
  State<_DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<_DashCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hovered ? 1.02 : 1.0,
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.item.onTap,
            borderRadius: borderRadius,
            child: Ink(
              decoration: BoxDecoration(
                color: _PageTheme.surface,
                borderRadius: borderRadius,
                border: Border.all(
                  color: _hovered
                      ? _PageTheme.primary.withOpacity(0.8)
                      : _PageTheme.border,
                  width: 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _PageTheme.primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.item.icon,
                        size: 22,
                        color: _PageTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
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
        ),
      ),
    );
  }
}

// การ์ดหัวสาขา: background ขาว, container ขาว, icon/badge ใช้สีเขียวหลัก
class _BranchHeaderCard extends StatelessWidget {
  final String branchId;
  final String? fallbackName;
  const _BranchHeaderCard({required this.branchId, this.fallbackName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: BranchService.getBranchById(branchId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final String branchName =
            (data != null ? (data['branch_name']?.toString() ?? '') : '')
                    .trim()
                    .isNotEmpty
                ? data!['branch_name'].toString()
                : (fallbackName ?? '');
        final String branchCode =
            (data != null ? (data['branch_code']?.toString() ?? '') : '')
                .trim();
        final bool isActive =
            (data != null ? (data['is_active'] as bool?) ?? false : false);
        final String? imageUrl =
            data != null ? (data['branch_image'] as String?) : null;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _PageTheme.border),
          ),
          color: _PageTheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // รูปสาขา/ไอคอนสาขา (พื้นหลังขาว)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _PageTheme.soft,
                    borderRadius: BorderRadius.circular(14),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ====================== สถิติภาพรวมของสาขา ======================

class _BranchStats extends StatelessWidget {
  final String branchId;
  const _BranchStats({required this.branchId});

  Future<Map<String, dynamic>> _load() async {
    final now = DateTime.now();
    final stats = await Future.wait([
      BranchService.getBranchStatistics(branchId),
      IssueService.getIssueStatistics(branchId: branchId),
      InvoiceService.getInvoiceStats(
        branchId: branchId,
        month: now.month,
        year: now.year,
      ),
    ]);

    final branch = stats[0];
    final issues = stats[1];
    final invoices = stats[2];

    final int issuePending =
        (issues['pending'] ?? 0) + (issues['in_progress'] ?? 0);
    final int invoicePending = (invoices['pending'] ?? 0) +
        (invoices['partial'] ?? 0) +
        (invoices['overdue'] ?? 0);

    return {
      'total_rooms': branch['total_rooms'] ?? 0,
      'occupied_rooms': branch['occupied_rooms'] ?? 0,
      'available_rooms': branch['available_rooms'] ?? 0,
      'maintenance_rooms': branch['maintenance_rooms'] ?? 0,
      'occupancy_rate': branch['occupancy_rate'] ?? 0,
      'issue_pending': issuePending,
      'invoice_pending': invoicePending,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StatsSkeleton();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;

        final tiles = <Widget>[
          _StatTile(
            label: 'ห้องทั้งหมด',
            value: data['total_rooms'].toString(),
            icon: Icons.meeting_room_outlined,
          ),
          _StatTile(
            label: 'มีผู้เช่า',
            value: data['occupied_rooms'].toString(),
            icon: Icons.person_pin_circle_rounded,
          ),
          _StatTile(
            label: 'ว่าง',
            value: data['available_rooms'].toString(),
            icon: Icons.event_available_outlined,
          ),
          _StatTile(
            label: 'ซ่อมบำรุง',
            value: data['maintenance_rooms'].toString(),
            icon: Icons.build_circle_outlined,
          ),
          _StatTile(
            label: 'อัตราเข้าพัก',
            value: '${data['occupancy_rate']}%',
            icon: Icons.pie_chart_outline,
          ),
          _StatTile(
            label: 'ปัญหาค้าง',
            value: data['issue_pending'].toString(),
            icon: Icons.report_gmailerrorred_outlined,
          ),
          _StatTile(
            label: 'บิลค้าง',
            value: data['invoice_pending'].toString(),
            icon: Icons.receipt_long_outlined,
          ),
        ];

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;

            const double minTileWidth = 180;
            const double spacing = 12;

            final double contentWidth = w;
            int crossAxisCount =
                ((contentWidth + spacing) / (minTileWidth + spacing)).floor();

            if (crossAxisCount < 2) crossAxisCount = 2;
            if (crossAxisCount > 6) crossAxisCount = 6;

            const double desiredHeight = 80;
            final double aspectRatio = minTileWidth / desiredHeight;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // หัวข้อ section สถิติ
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _PageTheme.primary.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights_outlined,
                          size: 16,
                          color: _PageTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'สถิติภาพรวมของสาขา',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: aspectRatio,
                  children: tiles,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _PageTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _PageTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _PageTheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _PageTheme.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        const double minTileWidth = 180;
        const double spacing = 12;

        final double contentWidth = w;
        int crossAxisCount =
            ((contentWidth + spacing) / (minTileWidth + spacing)).floor();
        if (crossAxisCount < 2) crossAxisCount = 2;
        if (crossAxisCount > 6) crossAxisCount = 6;

        const double desiredHeight = 80;
        final double aspectRatio = minTileWidth / desiredHeight;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
          children: List.generate(
            6,
            (i) => Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}
