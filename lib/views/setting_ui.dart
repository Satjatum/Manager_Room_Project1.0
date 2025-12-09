import 'package:flutter/material.dart';

import 'widgets/mainnavbar.dart';
// Models //
import '../../models/user_models.dart';
// Middleware //
import '../../middleware/auth_middleware.dart';
// Services //
import '../services/auth_service.dart';
// Page //
import 'login_ui.dart';
import 'sadmin/user_management_ui.dart';
// Widgets //
import 'widgets/snack_message.dart';

class SettingUi extends StatefulWidget {
  const SettingUi({Key? key}) : super(key: key);

  @override
  State<SettingUi> createState() => _SettingUiState();
}

class _SettingUiState extends State<SettingUi> {
  UserModel? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (mounted) {
        setState(() {
          currentUser = user;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ===== Actions (ไม่แตะ logic) =====
  Future<void> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'คุณต้องการออกจากระบบหรือไม่?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'คุณจะต้องเข้าสู่ระบบใหม่ในครั้งต่อไป',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ยืนยัน',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) await _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pop();
        debugPrint('ออกจากระบบเรียบร้อยแล้ว');
        SnackMessage.showSuccess(context, 'ออกจากระบบเรียบร้อยแล้ว');

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginUi()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        debugPrint('เกิดข้อผิดพลาดในการออกจากระบบ');
      }
    }
  }

  // ===== Build =====
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1200;
    final isWeb = size.width >= 1200;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: Text('ไม่สามารถโหลดข้อมูลผู้ใช้ได้')),
        bottomNavigationBar: const Mainnavbar(currentIndex: 1),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildResponsiveBody(isMobile, isTablet, isWeb),
      ),
      bottomNavigationBar: const Mainnavbar(currentIndex: 1),
    );
  }

  Widget _buildResponsiveBody(bool isMobile, bool isTablet, bool isWeb) {
    final horizontal = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ตั้งค่าระบบ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'จัดการข้อมูลส่วนตัวและการตั้งค่า',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                sliver: SliverList.list(children: [
                  _UserCard(user: currentUser!, isMobile: isMobile),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    isMobile: isMobile,
                    currentUser: currentUser!,
                    onOpenUserManagement: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserManagementUi()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FullWidthButton(
                    label: 'ออกจากระบบ',
                    icon: Icons.logout,
                    background: Colors.red,
                    foreground: Colors.white,
                    onPressed: _showLogoutConfirmation,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== Reusable UI pieces (UI only) =====

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xff10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (primary).withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (primary).withOpacity(.25)),
      ),
      child: Text(text, style: TextStyle(color: primary, fontSize: 12)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.tint});
  final IconData icon;
  final String title;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (tint ?? const Color(0xff10B981)).withOpacity(.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tint ?? const Color(0xff10B981)),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isMobile});
  final UserModel user;
  final bool isMobile;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(children: [
            CircleAvatar(
              radius: isMobile ? 36 : 44,
              backgroundColor: const Color(0xff10B981).withOpacity(.1),
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 28 : 34,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff10B981),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            )
          ]),
          const SizedBox(height: 10),
          Text(user.displayName,
              style: TextStyle(
                  fontSize: isMobile ? 20 : 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user.userEmail, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 8),
          _ChipPill(user.roleDisplayName),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('เข้าสู่ระบบล่าสุด: ${user.lastLoginDisplay}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.isMobile,
    required this.currentUser,
    required this.onOpenUserManagement,
  });
  final bool isMobile;
  final UserModel currentUser;
  final VoidCallback onOpenUserManagement;

  @override
  Widget build(BuildContext context) {
    // ในหน้า Settings หลัก ให้แสดงเฉพาะ "จัดการผู้ใช้งาน" ตามที่ต้องการ
    final canSeeSettings = currentUser.userRole == UserRole.superAdmin;
    if (!canSeeSettings) return const SizedBox.shrink();

    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(
            icon: Icons.settings_applications,
            title: 'ตั้งค่าระบบ',
            tint: Colors.indigo),
        const SizedBox(height: 6),
        const Divider(height: 20),
        _SettingTile(
          icon: Icons.admin_panel_settings,
          title: 'จัดการผู้ใช้งาน',
          subtitle: 'เพิ่ม แก้ไข และจัดการผู้ใช้ระบบ',
          onTap: onOpenUserManagement,
        ),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black45),
        ]),
      ),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
