import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/views/sadmin/branchdash_ui.dart';
// Removed: payment_qr_management_ui.dart (not used)
import 'package:manager_room_project/views/sadmin/issuelist_ui.dart';
import 'package:manager_room_project/views/sadmin/meterlist_ui.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_ui.dart';
import 'package:manager_room_project/views/sadmin/roomlist_ui.dart';
import 'package:manager_room_project/views/sadmin/settingbranch_ui.dart';
import 'package:manager_room_project/views/sadmin/tenantlist_ui.dart';
import 'package:manager_room_project/views/tenant/tenantdash_ui.dart';
import 'package:manager_room_project/views/tenant/bill_list_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../login_ui.dart';
import '../setting_ui.dart';

class Subnavbar extends StatefulWidget {
  final int currentIndex;
  final String? branchId;
  final String? branchName;

  const Subnavbar({
    Key? key,
    this.currentIndex = 0,
    this.branchId,
    this.branchName,
  }) : super(key: key);

  @override
  State<Subnavbar> createState() => _SubnavbarState();
}

class _SubnavbarState extends State<Subnavbar> {
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
      print('Error loading user: $e');
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
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'แดชบอร์ด',
      ),
    ];

    _pages = [
      BranchDashboardPage(),
    ];
  }

  void _setupAdminNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.meeting_room_outlined,
        activeIcon: Icons.meeting_room,
        label: 'ห้อง',
      ),
      NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'ผู้เช่า',
      ),
      NavItem(
        icon: Icons.report_gmailerrorred_outlined,
        activeIcon: Icons.report,
        label: 'แจ้งปัญหา',
      ),
      NavItem(
        icon: Icons.speed_outlined,
        activeIcon: Icons.speed,
        label: 'มิเตอร์',
      ),
      NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'บิลชำระ',
      ),
    ];

    _pages = [
      RoomListUI(
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
      TenantListUI(
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
      IssuelistUi(
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
      MeterReadingsListPage(
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
      // Use PaymentVerificationPage instead of PaymentQrManagementUi
      PaymentVerificationPage(
        branchId: widget.branchId,
      ),
    ];
  }

  void _setupUserNavigation() {
    _navigationItems = [];

    _pages = [];
  }

  void _setupTenantNavigation() {
    _navigationItems = [
      NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'หน้าแรก',
      ),
      NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'บิลของฉัน',
      ),
      NavItem(
        icon: Icons.report_problem_outlined,
        activeIcon: Icons.report_problem,
        label: 'แจ้งปัญหา',
      ),
      NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'โปรไฟล์',
      ),
    ];

    _pages = [
      const TenantdashUi(), // index 0
      const TenantBillsListPage(), // index 1
      IssuelistUi(
        // index 2
        branchId: widget.branchId,
        branchName: widget.branchName,
      ),
      const SettingUi(), // index 3
    ];
  }

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
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
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
