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
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleStatus() async {
    final currentStatus = _tenantData?['is_active'] ?? false;
    final confirmMessage = currentStatus
        ? 'คุณต้องการปิดใช้งานผู้เช่านี้หรือไม่?'
        : 'คุณต้องการเปิดใช้งานผู้เช่านี้หรือไม่?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการดำเนินการ'),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : AppTheme.primary,
            ),
            child: Text(currentStatus ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await TenantService.toggleTenantStatus(widget.tenantId);

        if (result['success']) {
          _showSuccessSnackBar(result['message']);
          _loadData();
        } else {
          _showErrorSnackBar(result['message']);
        }
      } catch (e) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
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
        title: const Text('ยืนยันการลบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณต้องการลบผู้เช่านี้ถาวรหรือไม่?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                        ),
                        child: const Text('กลับ'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildCustomHeader(),
                      // Tabs (match style from branchlist_detail_ui.dart)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildInfoSection(),
        ),
      ),
    );
  }

  Widget _buildContractsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildContractInfo(),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _buildPaymentInfo(),
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    final tenantName = _tenantData?['tenant_fullname'] ?? 'ไม่ระบุชื่อ';
    final tenantPhone = _tenantData?['tenant_phone'] ?? '-';
    final tenantProfile = _tenantData?['tenant_profile'];
    final isActive = _tenantData?['is_active'] ?? false;

    final hasImage = tenantProfile != null && tenantProfile.toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Top bar with back button and title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
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
              ],
            ),
          ),

          // Image area
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[200],
            child: hasImage
                ? Image.network(
                    tenantProfile,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildHeaderImagePlaceholder(),
                  )
                : _buildHeaderImagePlaceholder(),
          ),

          // Basic info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            tenantPhone,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primary : Colors.grey[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'ใช้งานอยู่' : 'ปิดใช้งาน',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildHeaderImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'ข้อมูลส่วนตัว',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.credit_card,
                label: 'เลขบัตรประชาชน',
                value: _tenantData?['tenant_idcard'] ?? '-',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.wc,
                label: 'เพศ',
                value: _getGenderText(_tenantData?['gender']),
              ),
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: 'วันที่เพิ่มข้อมูล',
                value: _formatDate(_tenantData?['created_at']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractInfo() {
    final activeContract = _statistics?['active_contract'];
    final totalContracts = _statistics?['total_contracts'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header พร้อมปุ่มดูทั้งหมด
              Row(
                children: [
                  Icon(Icons.description, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลสัญญาเช่า',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  // ปุ่มดูสัญญาทั้งหมด - แสดงเสมอถ้ามีสิทธิ์
                  // if (_currentUser != null &&
                  //     _currentUser!.hasAnyPermission([
                  //       DetailedPermission.all,
                  //       DetailedPermission.manageContracts,
                  //       DetailedPermission.viewContracts,
                  //     ]))
                  //   Container(
                  //     decoration: BoxDecoration(
                  //       color: AppTheme.primary.withOpacity(0.1),
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     child: Material(
                  //       color: Colors.transparent,
                  //       child: InkWell(
                  //         borderRadius: BorderRadius.circular(8),
                  //         onTap: () {
                  //           // ไปหน้ารายการสัญญาของผู้เช่านี้
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (context) => ContractListUI(
                  //                 tenantId: widget.tenantId,
                  //                 tenantName: _tenantData?['tenant_fullname'],
                  //               ),
                  //             ),
                  //           ).then((_) => _loadData());
                  //         },
                  //         child: Padding(
                  //           padding: EdgeInsets.symmetric(
                  //             horizontal: 12,
                  //             vertical: 6,
                  //           ),
                  //           child: Row(
                  //             mainAxisSize: MainAxisSize.min,
                  //             children: [
                  //               Icon(
                  //                 Icons.list_alt,
                  //                 size: 18,
                  //                 color: AppTheme.primary,
                  //               ),
                  //               SizedBox(width: 4),
                  //               Text(
                  //                 'ดูทั้งหมด',
                  //                 style: TextStyle(
                  //                   fontSize: 13,
                  //                   fontWeight: FontWeight.w600,
                  //                   color: AppTheme.primary,
                  //                 ),
                  //               ),
                  //               if (totalContracts > 0) ...[
                  //                 SizedBox(width: 4),
                  //                 Container(
                  //                   padding: EdgeInsets.symmetric(
                  //                     horizontal: 6,
                  //                     vertical: 2,
                  //                   ),
                  //                   decoration: BoxDecoration(
                  //                     color: AppTheme.primary,
                  //                     borderRadius: BorderRadius.circular(10),
                  //                   ),
                  //                   child: Text(
                  //                     '$totalContracts',
                  //                     style: TextStyle(
                  //                       fontSize: 11,
                  //                       color: Colors.white,
                  //                       fontWeight: FontWeight.bold,
                  //                     ),
                  //                   ),
                  //                 ),
                  //               ],
                  //             ],
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
              const SizedBox(height: 16),

              // แสดงข้อมูลสัญญาปัจจุบัน
              if (activeContract != null) ...[
                // ปุ่มจัดการสัญญาปัจจุบัน
                Row(
                  children: [
                    // ปุ่มดูสัญญา
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
                        icon: Icon(Icons.visibility, size: 18),
                        label: Text('ดูสัญญา'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    // ปุ่มแก้ไข (เฉพาะผู้ที่มีสิทธิ์)
                    if (_currentUser != null &&
                        _currentUser!.hasAnyPermission([
                          DetailedPermission.all,
                          DetailedPermission.manageContracts,
                        ])) ...[
                      SizedBox(width: 8),
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
                          icon: Icon(Icons.edit, size: 18),
                          label: Text('แก้ไข'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                // กรณีไม่มีสัญญาที่ใช้งานอยู่
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ไม่มีสัญญาเช่าที่ใช้งานอยู่',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ปุ่มสร้างสัญญาใหม่
                      // if (_currentUser != null &&
                      //     _currentUser!.hasAnyPermission([
                      //       DetailedPermission.all,
                      //       DetailedPermission.manageContracts,
                      //     ])) ...[
                      //   const SizedBox(height: 12),
                      //   SizedBox(
                      //     width: double.infinity,
                      //     child: ElevatedButton.icon(
                      //       onPressed: () {
                      //         Navigator.push(
                      //           context,
                      //           MaterialPageRoute(
                      //             builder: (context) => ContractAddUI(
                      //               tenantId: widget.tenantId,
                      //               tenantData: _tenantData,
                      //             ),
                      //           ),
                      //         ).then((_) => _loadData());
                      //       },
                      //       icon: Icon(Icons.add_circle_outline, size: 20),
                      //       label: Text(
                      //         'สร้างสัญญาใหม่',
                      //         style: TextStyle(
                      //           fontSize: 15,
                      //           fontWeight: FontWeight.w600,
                      //         ),
                      //       ),
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.green,
                      //         foregroundColor: Colors.white,
                      //         padding: EdgeInsets.symmetric(vertical: 12),
                      //         elevation: 2,
                      //       ),
                      //     ),
                      //   ),
                      // ],
                    ],
                  ),
                ),
              ],

              // แสดงจำนวนสัญญาทั้งหมด
              if (totalContracts > 0) ...[
                const Divider(height: 24),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history,
                          color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ประวัติสัญญา: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
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
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final recentPayments = _statistics?['recent_payments'] as List? ?? [];
    final pendingInvoicesCount = _statistics?['pending_invoices_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'ข้อมูลการชำระเงิน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pendingInvoicesCount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'มีใบแจ้งหนี้ค้างชำระ $pendingInvoicesCount รายการ',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                ...recentPayments.take(5).map((payment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getPaymentStatusIcon(payment['payment_status']),
                          color:
                              _getPaymentStatusColor(payment['payment_status']),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '฿${payment['payment_amount']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor(
                                    payment['payment_status'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getPaymentStatusText(payment['payment_status']),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getPaymentStatusColor(
                                  payment['payment_status']),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'ยังไม่มีประวัติการชำระเงิน',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
