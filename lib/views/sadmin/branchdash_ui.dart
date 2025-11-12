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

    // Define the list of dashboard actions. Each card in the grid is built
    // using these descriptors. Keeping this list near the top of the build
    // method makes it easier to add or remove items later on.
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
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Capture the full screen width. We'll compute our responsive
              // breakpoints based on the entire available width rather than
              // constraining the content to a fixed maximum. This allows the
              // dashboard to stretch across the screen on larger displays.
              final double screenW = constraints.maxWidth;
              // Compose the header with a back button and title. On larger screens
              // the header remains aligned to the left, while on phones it
              // stretches across the width.
              final header = Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            'เลือกเมนูการทำงานของสาขา',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              // Determine the number of columns based on available width. The grid
              // uses a fixed cross axis count so the cards fill the entire row
              // before wrapping to the next line. Adjust these breakpoints to
              // your liking to achieve a consistent look across devices.
              int crossAxisCount;
              if (screenW < 480) {
                crossAxisCount = 2; // small phones
              } else if (screenW < 800) {
                crossAxisCount = 3; // large phones / small tablets
              } else if (screenW < 1100) {
                crossAxisCount = 4; // tablets / small laptops
              } else if (screenW < 1400) {
                crossAxisCount = 5; // medium desktops
              } else {
                crossAxisCount = 6; // large desktops / wide screens
              }

              // Build the list containing the branch name card (if provided) and the
              // responsive grid. Using a fixed cross axis count ensures the
              // buttons span the entire width of the content area before
              // starting a new line.
              final contentList = ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if ((branchName ?? '').isNotEmpty)
                    _BranchNameCard(name: branchName!),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _DashCard(item: items[i]),
                  ),
                ],
              );

              // Assemble the final layout. On mobile devices we center the content
              // horizontally within the viewport; on larger screens we left align
              // the content within the maximum width to provide a more desktop‑like
              // experience.
              if (isMobileApp) {
                // On mobile devices, stretch the content across the full width of the
                // screen. We no longer use ConstrainedBox so the grid fills
                // horizontally before wrapping.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(child: contentList),
                  ],
                );
              }
              // Desktop/web: likewise stretch the dashboard to fill the available
              // width. The crossAxisCount calculation above handles responsive
              // column counts.
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

// Responsive content widths (Mobile S/M/L, Tablet, Laptop, Laptop L, 4K)
// Previously the layout limited its width using _maxContentWidth, but now
// the dashboard stretches to fill the available space. The helper is kept
// for legacy compatibility but returns the input unchanged.
double _maxContentWidth(double screenWidth) => screenWidth;

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
    // Each dashboard card uses a subtle elevation and increased padding to
    // create a modern, touch‑friendly appearance. The circular icon
    // container scales up slightly and the font size is increased to aid
    // readability on larger screens.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
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
    // Display the branch name in its own card with a larger icon and
    // comfortable padding. This card sits above the grid and is only
    // shown when a branch name is provided.
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.business,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
