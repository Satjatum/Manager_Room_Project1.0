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
                    // Determine columns by available width
                    int cross = 4;
                    if (maxW < 360) {
                      cross = 2; // Mobile S
                    } else if (maxW < 480) {
                      cross = 3; // Mobile M/L
                    } else {
                      cross = 4; // Tablet and above
                    }

                    final content = ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if ((branchName ?? '').isNotEmpty)
                          _BranchNameCard(name: branchName!),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _DashCard(item: items[i]),
                        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
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
