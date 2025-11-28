import 'package:flutter/material.dart';
// Page //
import '../sadmin/invoicelist_ui.dart';
import '../sadmin/issuelist_ui.dart';
import '../tenant/tenant_pay_history_ui.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/mainnavbar.dart';

class TenantdashUi extends StatefulWidget {
  final String? tenantName;
  final String? roomNumber;
  final String? profileImageUrl;
  final String? roomType;
  final String? branchName;
  final double? rentalFee;

  const TenantdashUi({
    super.key,
    this.tenantName,
    this.roomNumber,
    this.profileImageUrl,
    this.roomType,
    this.branchName,
    this.rentalFee,
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceListUi()),
        ),
      ),
      _DashItem(
        icon: Icons.history,
        label: 'ประวัติการชำระ',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantPayHistoryUi()),
        ),
      ),
      _DashItem(
        icon: Icons.build_outlined,
        label: 'แจ้งปัญหา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IssueListUi()),
        ),
      ),
      // _DashItem(
      //   icon: Icons.headset_mic_outlined,
      //   label: 'ตั้งค่า',
      //   onTap: () => Navigator.push(
      //     context,
      //     MaterialPageRoute(builder: (_) => const SettingUi()),
      //   ),
      // ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tenant Info Card
                _TenantInfoCard(
                  tenantName: widget.tenantName ?? 'ผู้เช่า',
                  roomType: widget.roomType ?? '-',
                  roomNumber: widget.roomNumber ?? '-',
                  branchName: widget.branchName ?? '-',
                  rentalFee: widget.rentalFee ?? 0.0,
                  profileImageUrl: widget.profileImageUrl,
                ),
                const SizedBox(height: 24),

                // Quick Actions Title
                const Text(
                  'เมนู',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions Wrap (Auto wrap)
                _QuickActionsWrap(items: items),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Mainnavbar(currentIndex: 0),
    );
  }
}

// ---------------------- Tenant Info Card ----------------------
class _TenantInfoCard extends StatelessWidget {
  final String tenantName;
  final String roomType;
  final String roomNumber;
  final String branchName;
  final double rentalFee;
  final String? profileImageUrl;

  const _TenantInfoCard({
    required this.tenantName,
    required this.roomType,
    required this.roomNumber,
    required this.branchName,
    required this.rentalFee,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Profile
            Row(
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  backgroundImage: profileImageUrl != null
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: profileImageUrl == null
                      ? Icon(Icons.person, size: 36, color: AppTheme.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูลผู้เช่า',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tenantName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Divider
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 16),
            // Info Grid
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.category_outlined,
                    label: 'ประเภทห้อง',
                    value: roomType,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.meeting_room_outlined,
                    label: 'เลขห้อง',
                    value: roomNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.business_outlined,
                    label: 'สาขา',
                    value: branchName,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.payments_outlined,
                    label: 'ค่าเช่าตามสัญญา',
                    value: '฿${rentalFee.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ---------------------- Quick Actions Wrap (Auto wrap) ----------------------
class _QuickActionsWrap extends StatelessWidget {
  final List<_DashItem> items;
  const _QuickActionsWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;
        final double spacing = 12;
        final double minTileW = isCompact ? 100 : 130;
        int columns = (constraints.maxWidth / minTileW).floor();
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
                child: _ActionCard(item: it),
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

  _DashItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ActionCard extends StatelessWidget {
  final _DashItem item;
  const _ActionCard({required this.item});

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
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),

                // Label
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
