import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_detail_ui.dart';
import 'package:manager_room_project/services/receipt_print_service.dart';
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
      _tabController; // ตัวกรองตามสถานะบิล: pending/partial/paid/overdue/cancelled
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = all (for superadmin)
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    // มี 5 แท็บตามสถานะใน Database ของบิล: pending, partial, paid, overdue, cancelled
    _tabController = TabController(length: 5, vsync: this);
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
      // โหลดสลิปทั้งหมด แล้วค่อยกรองตามสถานะบิล (pending/partial/paid/overdue/cancelled)
      final invStatus = _invoiceTabStatus();
      final res = await PaymentService.listPaymentSlips(
        status: 'all',
        branchId: _currentBranchFilter(),
        search: _search.isEmpty ? null : _search,
      );
      // แสดงเฉพาะวิธีโอนธนาคารเท่านั้น (PromptPay ถูกถอดออก)
      final filtered = res
          .where((e) => (e['payment_method'] ?? 'transfer') == 'transfer')
          .toList();
      // กรองตามสถานะของบิล
      final byInvoiceStatus = filtered
          .where((e) => (e['invoice_status'] ?? '').toString() == invStatus)
          .toList();

      setState(() {
        _slips = byInvoiceStatus;
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

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _approveSlip(Map<String, dynamic> slip) async {
    final controller = TextEditingController(
      text: (_asDouble(slip['paid_amount'])).toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('อนุมัติการชำระเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'จำนวนเงินที่อนุมัติ',
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ถ้ามี)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(controller.text) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง')),
        );
      }
      return;
    }

    try {
      setState(() => _loading = true);
      final result = await PaymentService.verifySlip(
        slipId: slip['slip_id'],
        approvedAmount: amount,
        paymentMethod: 'transfer',
        adminNotes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'สำเร็จ')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติไม่สำเร็จ: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectSlip(Map<String, dynamic> slip) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปฏิเสธสลิป'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'ระบุเหตุผล',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ปฏิเสธ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _loading = true);
      final result = await PaymentService.rejectSlip(
        slipId: slip['slip_id'],
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'สำเร็จ')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $e')),
        );
      }
      setState(() => _loading = false);
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
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ตรวจสอบ อนุมัติ/ปฏิเสธ และติดตามสถานะการชำระ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Branch filter (for SuperAdmin/Admin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildBranchFilter(),
            ),

            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ค้นหา: เลขบิล / ชื่อผู้เช่า / เบอร์โทร / จำนวนเงิน',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  isDense: true,
                ),
              ),
            ),

            // แท็บตัวกรองตามสถานะบิลจาก Database
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

  // ไม่ใช้รายการ Invoice ในหน้านี้อีกต่อไป (ใช้เฉพาะสลิปตามตัวกรองแท็บ)

  // Grid builders removed — enforce ListView everywhere

  Future<bool> _confirmExitBranch() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากสาขานี้?'),
        content: const Text(
            'คุณกำลังดูข้อมูลภายใต้สาขาที่เลือกอยู่ ต้องการออกจากสาขานี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันออก'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildBranchFilter() {
    // SuperAdmin: show dropdown for all branches (with 'ทั้งหมด')
    // Admin: if multiple managed branches, allow selection; if single, show label only
    if (_currentUser == null) return const SizedBox.shrink();

    final isSuper = _currentUser!.userRole == UserRole.superAdmin;
    final isAdmin = _currentUser!.userRole == UserRole.admin;

    if (!isSuper && !isAdmin) return const SizedBox.shrink();

    if (_branches.isEmpty) {
      return const SizedBox.shrink();
    }

    final options = [
      if (isSuper)
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('ทุกสาขา'),
        ),
      ..._branches.map((b) => DropdownMenuItem<String>(
            value: b['branch_id'] as String,
            child: Text(b['branch_name']?.toString() ?? '-'),
          )),
    ];

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.apartment, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _selectedBranchId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: options,
                    onChanged: widget.branchId != null
                        ? null
                        : (val) async {
                            setState(() {
                              _selectedBranchId = val;
                            });
                            await _load();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slipCard(Map<String, dynamic> s) {
    final invoiceId = (s['invoice_id'] ?? '').toString();
    final slipId = (s['slip_id'] ?? '').toString();
    final tenantName = (s['tenant_name'] ?? '-').toString();
    final roomcate = (s['roomcate_name'] ?? '-').toString();
    final roomNumber = (s['room_number'] ?? '-').toString();
    final invoiceNumber = (s['invoice_number'] ?? '-').toString();
    final status = (s['invoice_status'] ?? '').toString();
    final dateStr = _formatThaiDate(
        (s['payment_date'] ?? s['created_at'] ?? '').toString());
    final amount =
        _asDouble(s['invoice_total'] ?? s['total_amount'] ?? s['paid_amount']);

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
            // Status row (dot + label) — match _invoiceCard
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),

            const SizedBox(height: 8),

            // Title: ชื่อผู้เช่า - ประเภทห้อง เลขที่ห้อง
            Text(
              '$tenantName - $roomcate เลขที่ $roomNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),
            // Sub: Bill #... • วันที่ พ.ศ.
            Text(
              'Bill #$invoiceNumber • $dateStr',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),
            // Amount block
            Row(
              children: [
                const Text('ยอดรวม',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Text(
                  '${_formatMoney(amount)} บาท',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSlip(Map<String, dynamic> slip) async {
    try {
      await ReceiptPrintService.printSlipFromSlipRow(slip);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('พิมพ์สลิปไม่สำเร็จ: $e')),
      );
    }
  }

  // การ์ดแสดงใบแจ้งหนี้ (คงไว้ใช้ซ้ำที่อื่นได้) — แตะเพื่อไปหน้ารายละเอียดสลิปถ้ามี
  Widget _invoiceCard(Map<String, dynamic> inv) {
    double _asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final invoiceId = (inv['invoice_id'] ?? '').toString();
    final total = _asDouble(inv['total_amount']);
    final status = (inv['invoice_status'] ?? '').toString();
    final due = (inv['due_date'] ?? '').toString();
    final tenantName = (inv['tenant_name'] ?? '-').toString();
    final roomNumber = (inv['room_number'] ?? '-').toString();
    final roomcate = (inv['roomcate_name'] ?? '-').toString();
    final invoiceNumber = (inv['invoice_number'] ?? '-').toString();

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

    return InkWell(
      onTap: () async {
        if (invoiceId.isEmpty) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentVerificationDetailPage(invoiceId: invoiceId),
          ),
        );
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
            // Status row (dot + label)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),

            const SizedBox(height: 8),

            // Title: ชื่อผู้เช่า - ประเภทห้อง เลขที่ห้อง
            Text(
              '$tenantName - $roomcate เลขที่ $roomNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),
            // Sub: Bill #... • วันที่ พ.ศ.
            Text(
              'Bill #$invoiceNumber • ${_formatThaiDate(due)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),
            // Amount block bottom-right similar to sample
            Row(
              children: [
                const Text('ยอดรวม',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Text(
                  '${_formatMoney(total)} บาท',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    // Deprecated: slip status removed; reuse invoice status chip if needed
    return _invoiceStatusChip(status);
  }

  // ป้ายแสดงสถานะบิลตาม Database
  Widget _invoiceStatusChip(String status) {
    Color c;
    String t;
    switch (status) {
      case 'paid':
        c = const Color(0xFF22C55E);
        t = 'ชำระแล้ว';
        break;
      case 'overdue':
        c = const Color(0xFFEF4444);
        t = 'เกินกำหนด';
        break;
      case 'partial':
        c = const Color(0xFFF59E0B);
        t = 'ชำระบางส่วน';
        break;
      case 'cancelled':
        c = Colors.grey;
        t = 'ยกเลิก';
        break;
      case 'pending':
      default:
        c = const Color(0xFF3B82F6);
        t = 'รอดำเนินการ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // slip status chip removed (invoice-level verification only)

  // PromptPay method chip removed (no PromptPay UI)

  String _formatMoney(double v) {
    final s = v.toStringAsFixed(2);
    // simple thousand separator
    final parts = s.split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      buf.write(intPart[i]);
      final left = intPart.length - i - 1;
      if (left > 0 && left % 3 == 0) buf.write(',');
    }
    return buf.toString() + '.' + dec;
  }

  // แปลง ISO date เป็นรูปแบบไทย (พ.ศ.) "วัน-เดือน-ปี"
  String _formatThaiDate(String iso) {
    if (iso.isEmpty) return '-';
    DateTime? dt;
    try {
      dt = DateTime.tryParse(iso);
    } catch (_) {}
    dt ??= DateTime.now();
    const thMonths = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    final y = dt.year + 543;
    final m = thMonths[dt.month];
    final d = dt.day.toString();
    return '$d $m $y';
  }
}
