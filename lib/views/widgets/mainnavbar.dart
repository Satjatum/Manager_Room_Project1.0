import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/sadmin/branchlist_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../login_ui.dart';
import '../setting_ui.dart';

class Mainnavbar extends StatefulWidget {
  final int currentIndex;

  const Mainnavbar({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  State<Mainnavbar> createState() => _MainnavbarState();
}

class _MainnavbarState extends State<Mainnavbar> {
  UserModel? _currentUser;
  bool _isLoading = true;
  List<NavItem> _navigationItems = [];
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _setupNavigationByRole(user);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ไม่สามารถโหลดข้อมูลผู้ใช้ได้ $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupNavigationByRole(UserModel? user) {
    if (user == null) {
      _navigationItems = [];
      _pages = [];
      return;
    }

    switch (user.userRole) {
      case UserRole.superAdmin:
        _setupSuperAdminNavigation();
        break;
      case UserRole.admin:
        _setupAdminNavigation();
        break;
      case UserRole.user:
        _setupUserNavigation();
        break;
      case UserRole.tenant:
        _setupTenantNavigation();
        break;
    }
  }

  void _setupSuperAdminNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'สาขา',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [
      const BranchlistUi(),
      const SettingUi(),
    ];
  }

  void _setupAdminNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'สาขา',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [
      const BranchlistUi(),
      const SettingUi(),
    ];
  }

  void _setupTenantNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'หน้าหลัก',
      ),
      NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'ตั้งค่า',
      ),
    ];

    _pages = [
      const TenantdashUi(),
      const SettingUi(),
    ];
  }

  void _setupUserNavigation() {
    _navigationItems = [];

    _pages = [];
  }

  // Tenant navigation removed

  void _onItemTapped(BuildContext context, int index) {
    // ตรวจสอบ authentication แบบ synchronous ก่อน
    if (_currentUser == null) {
      _navigateToLogin(context);
      return;
    }

    // Navigation ทันทีโดยไม่รอ
    if (index < _pages.length && index < _navigationItems.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _pages[index]),
      );
    }
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginUi()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_navigationItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = widget.currentIndex == index;

              return Expanded(
                child: _buildNavItem(item, isSelected, index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(NavItem item, bool isSelected, int index) {
    return InkWell(
      onTap: () => _onItemTapped(context, index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItem({required this.icon, required this.activeIcon, required this.label});
}
