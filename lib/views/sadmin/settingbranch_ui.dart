import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/payment_qr_management_ui.dart';
import 'package:manager_room_project/views/payment_setting_ui.dart';
import 'package:manager_room_project/views/utility_setting_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/views/sadmin/amenities_ui.dart';
import 'package:manager_room_project/views/sadmin/roomtype_ui.dart';
import 'package:manager_room_project/views/sadmin/roomcate_ui.dart';

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

    // เตรียมรายการการตั้งค่า (แยกข้อมูลออกเพื่อใช้กับ List/Grid)
    final List<_SettingItem> items = [
      _SettingItem(
        icon: Icons.bolt,
        title: 'ตั้งค่าอัตราค่าบริการ',
        subtitle: 'ค่าไฟฟ้า ค่าน้ำ ค่าส่วนกลางของสาขานี้',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UtilityRatesManagementUi(branchId: lockedBranchId),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.account_balance_wallet,
        title: 'ตั้งค่าค่าปรับและส่วนลด',
        subtitle: 'ค่าปรับชำระล่าช้า ส่วนลดชำระก่อนเวลา ',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSettingsUi(branchId: lockedBranchId),
          ),
        ),
      ),
      _SettingItem(
        icon: Icons.qr_code_2,
        title: 'ตั้งค่าบัญชีชำระเงิน ',
        subtitle: 'เพิ่ม/แก้ไข/ปิดใช้งาน บัญชีธนาคารและ QR ของสาขานี้',
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
        subtitle: 'เพิ่ม/แก้ไขรายการสิ่งอำนวยความสะดวกของห้องพัก',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AmenitiesUI()),
        ),
      ),
      _SettingItem(
        icon: Icons.category,
        title: 'ประเภทห้อง',
        subtitle: 'จัดการประเภทห้อง เช่น ห้องพัดลม ห้องแอร์',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoomTypesUI()),
        ),
      ),
      _SettingItem(
        icon: Icons.grid_view,
        title: 'หมวดหมู่ห้อง',
        subtitle: 'จัดการหมวดหมู่ห้อง เช่น ห้องเดี่ยว ห้องคู่',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoomCategoriesUI()),
        ),
      ),
    ];

    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
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
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // รายการการ์ด (responsive)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ถ้าเป็น Mobile (Android/iOS) ให้แสดงแบบคอลัมน์ (List) เสมอ
                    if (isMobileApp) {
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) => Column(
                          children: [
                            _SettingGridCard(item: items[index]),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }

                    int crossAxisCount = 1;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth > 900) {
                      crossAxisCount = 3;
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 2;
                    }

                    if (crossAxisCount == 1) {
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) => Column(
                          children: [
                            _SettingGridCard(item: items[index]),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _SettingGridCard(
                        item: items[index],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xff10B981);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
                blurRadius: 10, spreadRadius: -2, color: Color(0x11000000)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
