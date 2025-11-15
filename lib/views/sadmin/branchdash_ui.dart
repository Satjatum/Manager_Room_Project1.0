import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
//--------
import 'roomlist_ui.dart';
import 'tenantlist_ui.dart';
import 'issuelist_ui.dart';
import 'meter_billing_ui.dart';
import 'meterlist_ui.dart';
import 'payment_verification_ui.dart';
import 'settingbranch_ui.dart';
//--------
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/services/issue_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';

// Local page palette (only for this screen)
class _PageTheme {
  // สีเขียวหลัก 0xFF10B981 ใช้กับ icon / badge / จุดเน้น
  static const Color primary = Color(0xFF10B981);

  // Background ทั้งหน้า
  static const Color pageBackground = Colors.white;

  // สี container/card
  static const Color surface = Colors.white;

  // เส้นขอบบาง ๆ
  static const Color border = Color(0xFFE5E7EB);

  // สีพื้นอ่อน ๆ สำหรับ icon circle
  static const Color soft = Color(0xFFF3F4F6);

  // ใช้ในกรณีต้องการเงาบางมาก (ส่วนใหญ่จะไม่ใช้)
  static const Color cardShadow = Color(0x00000000);
}

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

    // Dashboard items (logic เดิม)
    final items = <_DashItem>[
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

              // === Auto-wrap Grid สำหรับปุ่มเมนู ===
              const double gridHorizontalPadding = 12;
              const double dashMinWidth = 120; // ความกว้างขั้นต่ำของการ์ดปุ่ม
              const double dashDesiredHeight = 90;
              const double dashSpacing = 16;

              final double contentWidth = screenW - (gridHorizontalPadding * 2);

              int dashCrossAxisCount =
                  ((contentWidth + dashSpacing) / (dashMinWidth + dashSpacing))
                      .floor();

              // อย่างน้อย 2 คอลัมน์
              if (dashCrossAxisCount < 2) dashCrossAxisCount = 2;
              // กันไม่ให้ถี่เกิน (เช่น จอใหญ่มาก)
              if (dashCrossAxisCount > 6) dashCrossAxisCount = 6;

              final double dashChildAspectRatio =
                  dashMinWidth / dashDesiredHeight;

              final contentList = ListView(
                padding: const EdgeInsets.fromLTRB(
                    gridHorizontalPadding, 0, gridHorizontalPadding, 24),
                children: [
                  if ((branchId ?? '').isNotEmpty)
                    _BranchHeaderCard(
                      branchId: branchId!,
                      fallbackName: branchName,
                    ),
                  if ((branchId ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _BranchStats(branchId: branchId!),
                    ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: dashCrossAxisCount,
                      crossAxisSpacing: dashSpacing,
                      mainAxisSpacing: 18,
                      childAspectRatio: dashChildAspectRatio,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _DashCard(item: items[i]),
                  ),
                ],
              );

              if (isMobileApp) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(child: contentList),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  Expanded(child: contentList),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// helper เดิม (เผื่อ project ส่วนอื่นยังอ้างถึง)
double _maxContentWidth(double screenWidth) => screenWidth;

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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // รูปสาขา/ไอคอนสาขา (พื้นหลังขาว)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _PageTheme.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.apartment_rounded,
                          color: _PageTheme.primary,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 14),
                // ชื่อสาขา + code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (branchCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _PageTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            branchCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _PageTheme.primary,
                            ),
                          ),
                        ),
                      if (branchCode.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        branchName.isNotEmpty ? branchName : 'สาขา',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ข้อมูลภาพรวมของสาขานี้',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // badge สถานะ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _PageTheme.primary.withOpacity(0.08)
                        : _PageTheme.soft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive ? _PageTheme.primary : Colors.grey[400]!,
                    ),
                  ),
                  child: Text(
                    isActive ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? _PageTheme.primary : Colors.grey[700],
                    ),
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
