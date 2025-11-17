import 'package:flutter/material.dart';
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/setting_ui.dart';
import 'package:manager_room_project/views/tenant/bill_list_ui.dart';

import '../widgets/colors.dart';

class TenantdashUi extends StatefulWidget {
  const TenantdashUi({super.key});

  @override
  State<TenantdashUi> createState() => _TenantdashUiState();
}

class _TenantdashUiState extends State<TenantdashUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แดชบอร์ดผู้เช่า'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สวัสดี',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'เมนูด่วน',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = [
      _GridItem(
        icon: Icons.assignment_outlined,
        label: 'รายการปัญหา',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IssueListUi()),
        ),
      ),
      _GridItem(
        icon: Icons.receipt_long_outlined,
        label: 'บิลของฉัน',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantBillsListPage()),
        ),
      ),
      _GridItem(
        icon: Icons.settings_outlined,
        label: 'ตั้งค่า',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingUi()),
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _MenuCard(item: items[i]),
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _GridItem({required this.icon, required this.label, required this.onTap});
}

class _MenuCard extends StatelessWidget {
  final _GridItem item;
  const _MenuCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withOpacity(.25)),
              ),
              child: Icon(item.icon, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
