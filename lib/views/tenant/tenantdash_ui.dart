import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/setting_ui.dart';
import 'package:manager_room_project/views/tenant/bill_list_ui.dart';

import '../widgets/colors.dart';

class TenantdashUi extends StatefulWidget {
  final String? tenantName;
  final String? roomNumber;

  const TenantdashUi({super.key, this.tenantName, this.roomNumber});

  @override
  State<TenantdashUi> createState() => _TenantdashUiState();
}

class _TenantdashUiState extends State<TenantdashUi> {
  @override
  Widget build(BuildContext context) {
    // Quick actions
    final items = [
      _DashItem(
        icon: Icons.report_problem_outlined,
        label: 'แจ้งปัญหา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IssueListUi()),
        ),
      ),
      _DashItem(
        icon: Icons.receipt_long_outlined,
        label: 'บิลของฉัน',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantBillListPage()),
        ),
      ),
      _DashItem(
        icon: Icons.settings_outlined,
        label: 'ตั้งค่า',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingUi()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'แดชบอร์ดผู้เช่า',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'เลือกเมนูการทำงาน',
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
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  // Quick Actions Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'เมนู',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Actions Wrap
                  _QuickActionsWrap(items: items),
                ],
              ),
            ),
          ],
        ),
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
        final double minTileW = isCompact ? 100 : 130;
        int columns = (constraints.maxWidth / (minTileW)).floor();
        if (columns < 1) columns = 1;
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
