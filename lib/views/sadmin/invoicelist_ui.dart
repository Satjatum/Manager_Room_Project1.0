import 'package:flutter/material.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/sadmin/invoicelist_detail_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/utils/formatMonthy.dart';
import 'dart:async';

class InvoiceListUi extends StatefulWidget {
  final String? branchId;
  const InvoiceListUi({super.key, this.branchId});

  @override
  State<InvoiceListUi> createState() => _InvoiceListUiState();
}

class _InvoiceListUiState extends State<InvoiceListUi>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _invoices = [];
  late TabController _tabController;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  // สำหรับ Tenant: เก็บ invoice IDs ที่มีสลิปรอตรวจสอบหรือถูกปฏิเสธ
  Set<String> _pendingInvoiceIds = <String>{};
  Set<String> _rejectedInvoiceIds = <String>{};

  void _applyFilters() {
    final val = _searchCtrl.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_search != val) {
        setState(() => _search = val);
        _load();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _load();
    });
    _searchCtrl.addListener(_applyFilters);
    _initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.getCurrentUser();
      List<Map<String, dynamic>> branches = [];
      String? initialBranchId;

      if (user != null) {
        // โหลดสาขาตาม role
        if (user.userRole == UserRole.admin ||
            user.userRole == UserRole.superAdmin) {
          branches = await BranchService.getBranchesByUser();
          if (user.userRole == UserRole.admin) {
            if (branches.isNotEmpty) {
              initialBranchId = branches.first['branch_id'];
            }
          } else if (user.userRole == UserRole.superAdmin) {
            initialBranchId = null; // default see all
          }
        }
      }

      setState(() {
        _currentUser = user;
        _branches = branches;
        _selectedBranchId = widget.branchId ?? initialBranchId;
      });

      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // อัปเดตสถานะบิลที่เกินกำหนดอัตโนมัติเมื่อเปิดหน้า
      try {
        await InvoiceService.updateOverdueInvoices();
      } catch (_) {}

      final status = _invoiceTabStatus();
      List<Map<String, dynamic>> invList = [];

      if (_currentUser == null) {
        setState(() {
          _invoices = [];
          _loading = false;
        });
        return;
      }

      // จัดการตามบทบาท
      if (_currentUser!.userRole == UserRole.tenant) {
        // ผู้เช่า: เห็นแค่ของตัวเอง
        final tenantId = _currentUser!.tenantId;
        if (tenantId == null) {
          setState(() {
            _invoices = [];
            _loading = false;
          });
          return;
        }

        invList = await InvoiceService.getAllInvoices(
          tenantId: tenantId,
          status: status,
          limit: 500,
          orderBy: 'due_date',
          ascending: true,
        );

        // Mark invoices that have submitted slip but not yet verified (pending review)
        try {
          final ids = invList
              .map((e) => (e['invoice_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toList();
          final pending = await PaymentService.getInvoicesWithPendingSlip(
            invoiceIds: ids,
            tenantId: tenantId,
          );
          final rejected = await PaymentService.getInvoicesWithRejectedSlip(
            invoiceIds: ids,
            tenantId: tenantId,
          );
          _pendingInvoiceIds = pending;
          _rejectedInvoiceIds = rejected;
        } catch (_) {
          _pendingInvoiceIds = <String>{};
          _rejectedInvoiceIds = <String>{};
        }
      } else if (_currentUser!.userRole == UserRole.admin) {
        // Admin: เห็นแค่สาขาที่ตัวเองดูแล
        final branchId = _currentBranchFilter();
        invList = await InvoiceService.getAllInvoices(
          branchId: branchId,
          status: status,
          searchQuery: _search.isEmpty ? null : _search,
        );
      } else if (_currentUser!.userRole == UserRole.superAdmin) {
        // SuperAdmin: เห็นทั้งหมด
        invList = await InvoiceService.getAllInvoices(
          branchId: _currentBranchFilter(), // null = all branches
          status: status,
          searchQuery: _search.isEmpty ? null : _search,
        );
      }

      setState(() {
        _invoices = invList;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
        );
      }
    }
  }

  String? _currentBranchFilter() {
    if (_currentUser == null) return null;
    if (_currentUser!.userRole == UserRole.superAdmin) {
      return _selectedBranchId; // null = all branches
    }
    if (_currentUser!.userRole == UserRole.admin) {
      return _selectedBranchId ??
          (_branches.isNotEmpty
              ? _branches.first['branch_id'] as String
              : null);
    }
    return null;
  }

  // แปลง index แท็บ ไปเป็นสถานะบิลที่ต้องการ
  String _invoiceTabStatus() {
    switch (_tabController.index) {
      case 0:
        return 'pending';
      case 1:
        return 'partial';
      case 2:
        return 'paid';
      case 3:
        return 'overdue';
      case 4:
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดข้อความ header ตาม role
    String headerTitle = 'รายการบิล';
    String headerSubtitle = 'ดูและจัดการบิลทั้งหมด';

    if (_currentUser?.userRole == UserRole.tenant) {
      headerTitle = 'บิลค่าเช่า';
      headerSubtitle = 'ดูและจัดการบิลค่าเช่าของคุณ';
    } else if (_currentUser?.userRole == UserRole.admin) {
      headerSubtitle = 'รายการบิลในสาขาที่ดูแล';
    } else if (_currentUser?.userRole == UserRole.superAdmin) {
      headerSubtitle = 'รายการบิลทั้งหมดในระบบ';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headerSubtitle,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar (แสดงสำหรับ admin และ superadmin เท่านั้น)
            if (_currentUser?.userRole == UserRole.admin ||
                _currentUser?.userRole == UserRole.superAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (value) {
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'ค้นหาบิล...',
                      hintStyle:
                          TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

            if (_currentUser?.userRole == UserRole.admin ||
                _currentUser?.userRole == UserRole.superAdmin)
              const SizedBox(height: 16),

            // Tabs by invoice status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'ค้างชำระ'),
                    Tab(text: 'ชำระบางส่วน'),
                    Tab(text: 'ชำระแล้ว'),
                    Tab(text: 'เกินกำหนด'),
                    Tab(text: 'ยกเลิก'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildListView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_invoices.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('ไม่พบบิลในสถานะนี้')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _invoices.length,
      itemBuilder: (context, index) => _invoiceCard(_invoices[index]),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv) {
    final invoiceId = (inv['invoice_id'] ?? '').toString();
    final status = (inv['invoice_status'] ?? '').toString();
    final tenantName = (inv['tenant_name'] ?? '-').toString();
    final roomNumber = (inv['room_number'] ?? '-').toString();
    final roomcate = (inv['roomcate_name'] ?? '-').toString();
    final invoiceMonth = inv['invoice_month'] ?? 0;
    final invoiceYear = inv['invoice_year'] ?? 0;

    // สำหรับ tenant: แสดงสถานะสลิปรอตรวจสอบหรือถูกปฏิเสธ
    final bool isPendingReview = _currentUser?.userRole == UserRole.tenant &&
        _pendingInvoiceIds.contains(invoiceId) &&
        status != 'paid' &&
        status != 'cancelled';
    final bool isRejected = _currentUser?.userRole == UserRole.tenant &&
        !isPendingReview &&
        _rejectedInvoiceIds.contains(invoiceId) &&
        status != 'paid' &&
        status != 'cancelled';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = const Color(0xFF22C55E);
        statusLabel = 'ชำระแล้ว';
        break;
      case 'overdue':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'เกินกำหนด';
        break;
      case 'partial':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'ชำระบางส่วน';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = 'ยกเลิก';
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'ค้างชำระ';
    }

    String billingPeriod = '-';
    if (invoiceMonth is int && invoiceYear is int &&
        invoiceMonth >= 1 && invoiceMonth <= 12) {
      billingPeriod =
          'รอบบิลเดือน ${Formatmonthy.formatBillingCycleTh(month: invoiceMonth, year: invoiceYear)}';
    }

    return InkWell(
      onTap: () async {
        if (invoiceId.isEmpty) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceListDetailUi(invoiceId: invoiceId),
          ),
        );
        _load();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: ชื่อผู้เช่า | ประเภทห้องเลขที่ห้อง
                  Text(
                    '$tenantName | $roomcateเลขที่ $roomNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Billing period
                  Text(
                    billingPeriod,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right side: Status badge and arrow
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Trailing arrow
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
