import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_detail_ui.dart';
// import removed: tenant bill detail is not used from this page

class PaymentVerificationPage extends StatefulWidget {
  final String? branchId;
  const PaymentVerificationPage({super.key, this.branchId});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _slips = [];
  List<Map<String, dynamic>> _invoices = [];
  late TabController
      _tabController; // ตัวกรองตามสถานะการชำระ: all/pending/approved/rejected
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = all (for superadmin)
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    // มี 4 แท็บเฉพาะสลิป: all, pending, approved, rejected
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _load();
    });
    _searchCtrl.addListener(() {
      final val = _searchCtrl.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (_search != val) {
          setState(() => _search = val);
          _load();
        }
      });
    });
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
        branches = await BranchService.getBranchesByUser();
        if (user.userRole == UserRole.admin) {
          if (branches.isNotEmpty)
            initialBranchId = branches.first['branch_id'];
        } else if (user.userRole == UserRole.superAdmin) {
          initialBranchId = null; // default see all
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
      // อัปเดตสถานะบิลเกินกำหนดอัตโนมัติเมื่อเข้าหน้านี้
      try {
        await InvoiceService.updateOverdueInvoices();
      } catch (_) {}

      // โหลดสลิปทั้งหมด แยกตามแท็บ (ไม่ dedupe อีกต่อไป — แสดงเป็นประวัติครบ)
      final uiStatus =
          _getPaymentTabStatus(); // all | pending | approved | rejected
      final serviceStatus = (uiStatus == 'approved')
          ? 'verified'
          : uiStatus; // map ไป status ใน service

      // ดึงข้อมูลสลิปตามสถานะจาก service และกรองเฉพาะโอนธนาคาร
      final res = await PaymentService.listPaymentSlips(
        status: serviceStatus,
        branchId: _currentBranchFilter(),
        search: _search.isEmpty ? null : _search,
      );
      final deduped = res
          .where((e) => (e['payment_method'] ?? 'transfer') == 'transfer')
          .toList();

      setState(() {
        _slips = deduped;
        _invoices = const [];
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

  // ยกเลิก dedupe: แสดงทุกสลิปตามตัวกรอง เพื่อคงประวัติย้อนหลังครบถ้วน

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

  // แปลง index แท็บ ไปเป็นสถานะการชำระที่ต้องการ
  String _getPaymentTabStatus() {
    switch (_tabController.index) {
      case 0:
        return 'all';
      case 1:
        return 'pending';
      case 2:
        return 'approved';
      case 3:
        return 'rejected';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    // แสดง Header/Tab คงที่ แล้วให้โหลดเฉพาะส่วนรายการ (body)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (meterlist style)
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบสลิปชำระเงิน',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ตรวจสอบและติดตามสถานะการชำระ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
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
                    // Update the search query and apply filters whenever the user types.
                    // Note: debounce logic is already handled in initState
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหา',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey[600], size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.grey[600], size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                              _load();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // แท็บตัวกรองตามสถานะการชำระ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    Tab(text: 'ทั้งหมด'),
                    Tab(text: 'รอตรวจสอบ'),
                    Tab(text: 'อนุมัติ'),
                    Tab(text: 'ปฏิเสธ'),
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
                      child: _buildSlipListView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // List builders (mobile/narrow)
  Widget _buildSlipListView() {
    if (_slips.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('ไม่พบข้อมูล')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _slips.length,
      itemBuilder: (context, index) {
        return _slipCard(_slips[index]);
      },
    );
  }

  Widget _slipCard(Map<String, dynamic> s) {
    final invoiceId = (s['invoice_id'] ?? '').toString();
    final slipId = (s['slip_id'] ?? '').toString();
    final tenantName = (s['tenant_name'] ?? '-').toString();
    final roomcate = (s['roomcate_name'] ?? '-').toString();
    final roomNumber = (s['room_number'] ?? '-').toString();
    final invoiceNumber = (s['invoice_number'] ?? '-').toString();

    // Slip-level status (separated from invoice status)
    final bool isVerified =
        (s['payment_id'] != null && s['payment_id'].toString().isNotEmpty);
    final bool isRejected = (!isVerified &&
        (s['rejection_reason'] != null ||
            (s['verified_at'] != null &&
                s['verified_at'].toString().isNotEmpty)));
    Color statusColor;
    String statusLabel;
    if (isVerified) {
      statusColor = const Color(0xFF22C55E);
      statusLabel = 'อนุมัติแล้ว';
    } else if (isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'ถูกปฏิเสธ';
    } else {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'รอตรวจสอบ';
    }

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => slipId.isNotEmpty
                ? PaymentVerificationDetailPage(slipId: slipId)
                : PaymentVerificationDetailPage(invoiceId: invoiceId),
          ),
        );
        if (mounted) await _load();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // บรรทัดแรก: ไอคอน + ชื่อผู้เช่า | ประเภทห้อง เลขที่ห้อง + Badge สถานะ
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$tenantName | $roomcateเลขที่ $roomNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge สถานะ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // บรรทัดที่สอง: เลขที่บิล + ลูกศร
            Row(
              children: [
                Expanded(
                  child: Text(
                    'เลขที่บิล: $invoiceNumber',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
