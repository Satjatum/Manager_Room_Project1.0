import 'package:flutter/material.dart';
// Page //
import '../sadmin/invoicelist_ui.dart';
import '../sadmin/issuelist_ui.dart';
import '../tenant/tenant_pay_history_ui.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/mainnavbar.dart';
// Services //
import '../../services/auth_service.dart';
import '../../services/tenant_service.dart';
import '../../services/contract_service.dart';
import '../../models/user_models.dart';

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
  UserModel? currentUser;
  Map<String, dynamic>? tenantInfo;
  Map<String, dynamic>? activeContract;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTenantData();
  }

  Future<void> _loadTenantData() async {
    try {
      // Get current user
      currentUser = await AuthService.getCurrentUser();
      debugPrint(
          'Current User: ${currentUser?.userName}, Tenant ID: ${currentUser?.tenantId}');

      if (currentUser?.tenantId != null) {
        // Get tenant info
        tenantInfo = await TenantService.getTenantById(currentUser!.tenantId!);
        debugPrint('Tenant Info: $tenantInfo');

        // Get active contract for this tenant
        final contracts = await ContractService.getAllContracts(
          tenantId: currentUser!.tenantId!,
          status: 'active',
          limit: 1,
        );

        debugPrint('Found ${contracts.length} active contracts');
        if (contracts.isNotEmpty) {
          activeContract = contracts.first;
          debugPrint('Active Contract Data: $activeContract');
          debugPrint('Contract Keys: ${activeContract!.keys.toList()}');
          debugPrint('Contract Price: ${activeContract!['contract_price']}');
        }
      }
    } catch (e) {
      debugPrint('Error loading tenant data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper methods to get tenant data or fallback to widget params or "-"
  String _getTenantName() {
    return tenantInfo?['tenant_fullname'] ??
        currentUser?.tenantFullName ??
        widget.tenantName ??
        'ผู้เช่า';
  }

  String _getRoomType() {
    return activeContract?['roomcate_name'] ?? widget.roomType ?? '-';
  }

  String _getRoomNumber() {
    return activeContract?['room_number'] ?? widget.roomNumber ?? '-';
  }

  String _getBranchName() {
    return activeContract?['branch_name'] ?? widget.branchName ?? '-';
  }

  double _getRentalFee() {
    // Debug log to check available fields
    if (activeContract != null) {
      debugPrint('Checking rental fee fields in contract...');
    }

    // Try different possible field names for rental fee
    // contract_price is the main field according to database schema
    final possibleFeeFields = [
      'contract_price', // Main field from database schema
      'rental_fee',
      'rent_amount',
      'monthly_rent',
      'rent_fee',
      'contract_amount',
      'amount',
      'room_price',
      'fee'
    ];

    if (activeContract != null) {
      for (String field in possibleFeeFields) {
        if (activeContract![field] != null) {
          final value = activeContract![field];
          debugPrint('Found $field: $value');
          if (value is num && value > 0) {
            return value.toDouble();
          }
        }
      }

      // Also check nested room data
      if (activeContract!['rooms'] is Map) {
        final roomData = activeContract!['rooms'] as Map<String, dynamic>;
        debugPrint('Room data: $roomData');

        final possibleRoomFields = ['room_price', 'price'];
        for (String field in possibleRoomFields) {
          if (roomData[field] != null) {
            final value = roomData[field];
            debugPrint('Found room $field: $value');
            if (value is num && value > 0) {
              return value.toDouble();
            }
          }
        }
      }
    }

    if (widget.rentalFee != null && widget.rentalFee! > 0) {
      return widget.rentalFee!;
    }
    return 0.0;
  }

  String _getRentalFeeDisplay() {
    final fee = _getRentalFee();
    if (fee > 0) {
      return '฿${fee.toStringAsFixed(2)}';
    }
    return '-';
  }

  String? _getProfileImageUrl() {
    return tenantInfo?['tenant_profile'] ??
        currentUser?.tenantProfile ??
        widget.profileImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primary,
          ),
        ),
        bottomNavigationBar: const Mainnavbar(currentIndex: 0),
      );
    }
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
                  tenantName: _getTenantName(),
                  roomType: _getRoomType(),
                  roomNumber: _getRoomNumber(),
                  branchName: _getBranchName(),
                  rentalFeeDisplay: _getRentalFeeDisplay(),
                  profileImageUrl: _getProfileImageUrl(),
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
  final String rentalFeeDisplay;
  final String? profileImageUrl;

  const _TenantInfoCard({
    required this.tenantName,
    required this.roomType,
    required this.roomNumber,
    required this.branchName,
    required this.rentalFeeDisplay,
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(color: AppTheme.primary, width: 2.5),
                  ),
                  child: ClipOval(
                    child: profileImageUrl != null &&
                            profileImageUrl!.isNotEmpty &&
                            (profileImageUrl!.startsWith('http://') ||
                                profileImageUrl!.startsWith('https://'))
                        ? Image.network(
                            profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildInitialAvatar(tenantName),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              );
                            },
                          )
                        : _buildInitialAvatar(tenantName),
                  ),
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
                    value: rentalFeeDisplay,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Avatar fallback ตอนโหลดรูปไม่ได้ / ไม่มีรูป
  Widget _buildInitialAvatar(String name) {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      return words[0][0].toUpperCase();
    }
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
