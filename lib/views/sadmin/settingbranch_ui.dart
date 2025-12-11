import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Page //
import '../payment_setting_ui.dart';
import '../payment_qr_management_ui.dart';
import 'amenities_ui.dart';
import 'roomtype_ui.dart';
import 'roomcate_ui.dart';
// Utilit //
import '../utility_setting_ui.dart';
// Widgets //
import '../widgets/colors.dart';

class SettingbranchUi extends StatefulWidget {
  final String branchId;
  final String? branchName;

  const SettingbranchUi({super.key, required this.branchId, this.branchName});

  @override
  State<SettingbranchUi> createState() => _SettingbranchUiState();
}

class _SettingbranchUiState extends State<SettingbranchUi> {
  @override
  Widget build(BuildContext context) {
    // บางกรณี Subnavbar อาจส่ง branchId เป็น "" (string ว่าง)
    // เพื่อป้องกัน error หน้าลูก ให้แปลงเป็น null เพื่อให้หน้าเลือกสาขาได้
    final String? lockedBranchId =
        (widget.branchId.trim().isEmpty) ? null : widget.branchId;

    // เตรียมรายการการตั้งค่า (แยกข้อมูลออกเพื่อใช้กับ Wrap)
    final List<_SettingItem> items = [
      _SettingItem(
        icon: Icons.bolt,
        title: 'ตั้งค่าอัตราค่าบริการ',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UtilityRatesManagementUi(branchId: lockedBranchId),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.account_balance_wallet,
        title: 'ตั้งค่าค่าปรับ',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSettingsUi(branchId: lockedBranchId),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.qr_code_2,
        title: 'ตั้งค่าบัญชีชำระเงิน',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentQrManagementUi(branchId: lockedBranchId),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.stars,
        title: 'สิ่งอำนวยความสะดวก',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AmenitiesUI(
              branchId: lockedBranchId,
              branchName: widget.branchName,
            ),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.category,
        title: 'ประเภทห้อง',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomTypesUi(
              branchId: lockedBranchId,
              branchName: widget.branchName,
            ),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.grid_view,
        title: 'หมวดหมู่ห้อง',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomCateUi(
              branchId: lockedBranchId,
              branchName: widget.branchName,
            ),
          ),
        ),
      ),
    ];

    final platform = Theme.of(context).platform;
    !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header สไตล์เดียวกับ branchlist_ui
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                        const Text(
                          'ตั้งค่าสาขา',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.branchName?.isNotEmpty == true
                              ? 'สาขา: ${widget.branchName}'
                              : 'ปรับการตั้งค่าที่สำคัญของสาขา',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // รายการการ์ด (Auto Wrap)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // คำนวณขนาดการ์ดให้พอดีตามหน้าจอ
                    double cardWidth;
                    if (constraints.maxWidth > 1200) {
                      cardWidth =
                          (constraints.maxWidth - 72) / 4; // 4 การ์ดต่อแถว
                    } else if (constraints.maxWidth > 900) {
                      cardWidth =
                          (constraints.maxWidth - 48) / 3; // 3 การ์ดต่อแถว
                    } else {
                      cardWidth =
                          (constraints.maxWidth - 32) / 2; // 2 การ์ดต่อแถว
                    }

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: items.map((item) {
                        return SizedBox(
                          width: cardWidth,
                          child: _SettingGridCard(item: item),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  _SettingItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _SettingGridCard extends StatelessWidget {
  final _SettingItem item;
  const _SettingGridCard({required this.item});

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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: AppTheme.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
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
