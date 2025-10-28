import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:manager_room_project/views/superadmin/contract_add_ui.dart';
import 'package:manager_room_project/views/sadmin/contract_edit_ui.dart';
import 'package:manager_room_project/views/sadmin/contractlist_detail_ui.dart';
import '../../services/tenant_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import '../widgets/colors.dart';
import 'tenant_edit_ui.dart';

class TenantDetailUI extends StatefulWidget {
  final String tenantId;

  const TenantDetailUI({
    Key? key,
    required this.tenantId,
  }) : super(key: key);

  @override
  State<TenantDetailUI> createState() => _TenantDetailUIState();
}

class _TenantDetailUIState extends State<TenantDetailUI>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _tenantData;
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  bool _isDeleting = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await AuthMiddleware.getCurrentUser();
      final tenant = await TenantService.getTenantById(widget.tenantId);
      final stats = await TenantService.getTenantStatistics(widget.tenantId);

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _tenantData = tenant;
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _toggleStatus() async {
    final currentStatus = _tenantData?['is_active'] ?? false;
    final tenantName = _tenantData?['tenant_fullname'] ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentStatus
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                currentStatus
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: currentStatus
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                currentStatus ? 'ปิดใช้งานผู้เช่า' : 'เปิดใช้งานผู้เช่า',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'คุณต้องการ${currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน'}ผู้เช่า'),
            const SizedBox(height: 4),
            Text(
              '"$tenantName"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('หรือไม่?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final result = await TenantService.toggleTenantStatus(widget.tenantId);
        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (result['success']) {
            _showSuccessSnackBar(result['message']);
            _loadData();
          } else {
            _showErrorSnackBar(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  Future<void> _deleteTenant() async {
    // Check if user is superadmin
    if (_currentUser?.userRole != UserRole.superAdmin) {
      _showErrorSnackBar('เฉพาะ SuperAdmin เท่านั้นที่สามารถลบผู้เช่าได้');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ยืนยันการลบ',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณต้องการลบผู้เช่านี้ถาวรหรือไม่?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'การลบจะไม่สามารถกู้คืนได้',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบถาวร'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);

      try {
        final result = await TenantService.deleteTenant(widget.tenantId);

        if (mounted) {
          setState(() => _isDeleting = false);

          if (result['success']) {
            _showSuccessSnackBar(result['message']);
            Navigator.pop(context, true);
          } else {
            _showErrorSnackBar(result['message']);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
        }
      }
    }
  }

  Future<void> _editTenant() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantEditUI(
          tenantId: widget.tenantId,
          tenantData: _tenantData!,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'T';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading || _isDeleting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(_isDeleting ? 'กำลังลบข้อมูล...' : 'กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : _tenantData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('ไม่พบข้อมูลผู้เช่า'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('กลับ'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildModernHeader(),
                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom:
                                BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: Colors.grey[600],
                          indicatorColor: AppTheme.primary,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.info_outline, size: 20),
                              text: 'รายละเอียด',
                            ),
                            Tab(
                              icon: Icon(Icons.description_outlined, size: 20),
                              text: 'สัญญา',
                            ),
                            Tab(
                              icon: Icon(Icons.payments_outlined, size: 20),
                              text: 'การชำระเงิน',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDetailsTab(),
                            _buildContractsTab(),
                            _buildPaymentsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              _buildStatisticsCards(),
              const SizedBox(height: 16),
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: _buildContractInfo(),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: _buildPaymentInfo(),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    final tenantName = _tenantData?['tenant_fullname'] ?? 'ไม่ระบุชื่อ';
    final tenantPhone = _tenantData?['tenant_phone'] ?? '-';
    final tenantProfile = _tenantData?['tenant_profile'];
    final isActive = _tenantData?['is_active'] ?? false;

    final hasImage =
        tenantProfile != null && tenantProfile.toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ข้อมูลผู้เช่า',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined,
                              size: 20, color: Color(0xFF14B8A6)),
                          SizedBox(width: 12),
                          Text('แก้ไข'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isActive ? 'ปิดใช้งาน' : 'เปิดใช้งาน',
                            style: TextStyle(
                              color: isActive ? Colors.orange : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_currentUser?.userRole == UserRole.superAdmin)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('ลบ', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editTenant();
                        break;
                      case 'toggle':
                        _toggleStatus();
                        break;
                      case 'delete':
                        _deleteTenant();
                        break;
                    }
                  },
                ),
              ],
            ),
          ),

          // Profile section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? Image.network(
                            tenantProfile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildAvatarPlaceholder(tenantName),
                          )
                        : _buildAvatarPlaceholder(tenantName),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อและ Status ในแถวเดียวกัน
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tenantName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.primary
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: AppTheme.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final totalContracts = _statistics?['total_contracts'] ?? 0;
    final activeContract = _statistics?['active_contract'];
    final pendingInvoices = _statistics?['pending_invoices_count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.description_outlined,
            title: 'สัญญาทั้งหมด',
            value: '$totalContracts',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline,
            title: 'สัญญาปัจจุบัน',
            value: activeContract != null ? '1' : '0',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.pending_actions,
            title: 'ค้างชำระ',
            value: '$pendingInvoices',
            color: pendingInvoices > 0 ? const Color(0xFFF59E0B) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'ข้อมูลส่วนตัว',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildModernInfoRow(
            icon: Icons.credit_card,
            label: 'เลขบัตรประชาชน',
            value: _tenantData?['tenant_idcard'] ?? '-',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildModernInfoRow(
            icon: Icons.phone,
            label: 'เบอร์โทรศัพท์',
            value: _tenantData?['tenant_phone'] ?? '-',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          _buildModernInfoRow(
            icon: Icons.wc,
            label: 'เพศ',
            value: _getGenderText(_tenantData?['gender']),
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildModernInfoRow(
            icon: Icons.calendar_today,
            label: 'วันที่เพิ่มข้อมูล',
            value: _formatDate(_tenantData?['created_at']),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContractInfo() {
    final activeContract = _statistics?['active_contract'];
    final totalContracts = _statistics?['total_contracts'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ข้อมูลสัญญาเช่า',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // แสดงข้อมูลสัญญาปัจจุบัน
          if (activeContract != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'มีสัญญาเช่าที่ใช้งานอยู่',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContractDetailUI(
                                  contractId: activeContract['contract_id'],
                                ),
                              ),
                            ).then((_) => _loadData());
                          },
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('ดูสัญญา'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (_currentUser != null &&
                          _currentUser!.hasAnyPermission([
                            DetailedPermission.all,
                            DetailedPermission.manageContracts,
                          ])) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContractEditUI(
                                    contractId: activeContract['contract_id'],
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('แก้ไข'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ไม่มีสัญญาเช่าที่ใช้งานอยู่',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // แสดงจำนวนสัญญาทั้งหมด
          if (totalContracts > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'ประวัติสัญญา: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$totalContracts สัญญา',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final recentPayments = _statistics?['recent_payments'] as List? ?? [];
    final pendingInvoicesCount = _statistics?['pending_invoices_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'ข้อมูลการชำระเงิน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (pendingInvoicesCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.warning_rounded,
                        color: Colors.red.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'มีใบแจ้งหนี้ค้างชำระ $pendingInvoicesCount รายการ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (recentPayments.isNotEmpty) ...[
            Text(
              'การชำระเงินล่าสุด',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...recentPayments.take(5).map((payment) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment['payment_status'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getPaymentStatusIcon(payment['payment_status']),
                        color:
                            _getPaymentStatusColor(payment['payment_status']),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '฿${payment['payment_amount']?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(payment['payment_date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment['payment_status'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getPaymentStatusText(payment['payment_status']),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              _getPaymentStatusColor(payment['payment_status']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'ยังไม่มีประวัติการชำระเงิน',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getGenderText(String? gender) {
    switch (gender) {
      case 'male':
        return 'ชาย';
      case 'female':
        return 'หญิง';
      case 'other':
        return 'อื่นๆ';
      default:
        return '-';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateStr;
    }
  }

  IconData _getPaymentStatusIcon(String? status) {
    switch (status) {
      case 'verified':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusText(String? status) {
    switch (status) {
      case 'verified':
        return 'ยืนยันแล้ว';
      case 'pending':
        return 'รอตรวจสอบ';
      case 'rejected':
        return 'ปฏิเสธ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
}
