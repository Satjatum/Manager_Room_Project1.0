import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/invoicelist_ui.dart';
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/setting_ui.dart';
import 'package:manager_room_project/views/tenant/tenant_pay_history_ui.dart';
import '../widgets/colors.dart';

class TenantdashUi extends StatefulWidget {
  final String? tenantName;
  final String? roomNumber;
  final String? profileImageUrl;

  const TenantdashUi({
    super.key,
    this.tenantName,
    this.roomNumber,
    this.profileImageUrl,
  });

  @override
  State<TenantdashUi> createState() => _TenantdashUiState();
}

class _TenantdashUiState extends State<TenantdashUi> {
  @override
  Widget build(BuildContext context) {
    // Quick actions with descriptions
    final items = [
      _DashItem(
        icon: Icons.payment,
        label: 'ชำระค่าเช่า',
        description: 'ชำระค่าห้องพัก',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceListUi()),
        ),
      ),
      _DashItem(
        icon: Icons.history,
        label: 'ประวัติการใช้งาน',
        description: 'ดูรายการย้อนหลัง',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantPayHistoryUi()),
        ),
      ),
      _DashItem(
        icon: Icons.build_outlined,
        label: 'แจ้งปัญหา',
        description: 'รายงานปัญหา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IssueListUi()),
        ),
      ),
      _DashItem(
        icon: Icons.headset_mic_outlined,
        label: 'ตั้งค่า',
        description: 'ตั้งค่า',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingUi()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Profile
                _WelcomeHeader(
                  name: widget.tenantName ?? 'ผู้เช่า',
                  roomNumber: widget.roomNumber,
                  profileImageUrl: widget.profileImageUrl,
                ),
                const SizedBox(height: 24),

                // Quick Actions Title
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions Grid (2x2)
                _QuickActionsGrid(items: items),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------- Welcome Header ----------------------
class _WelcomeHeader extends StatelessWidget {
  final String name;
  final String? roomNumber;
  final String? profileImageUrl;

  const _WelcomeHeader({
    required this.name,
    this.roomNumber,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile Image
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          backgroundImage:
              profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
          child: profileImageUrl == null
              ? Icon(Icons.person, size: 32, color: AppTheme.primary)
              : null,
        ),
        const SizedBox(width: 12),

        // Welcome Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $name!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (roomNumber != null && roomNumber!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Unit: $roomNumber',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------- Quick Actions Grid (2x2) ----------------------
class _QuickActionsGrid extends StatelessWidget {
  final List<_DashItem> items;
  const _QuickActionsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _ActionCard(item: items[index]),
    );
  }
}

class _DashItem {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  _DashItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _DashItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF2196F3),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),

              // Label
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Description
              Text(
                item.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
