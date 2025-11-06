import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/views/sadmin/payment_verification_detail_ui.dart';
import 'package:manager_room_project/services/receipt_print_service.dart';

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
  late TabController _tabController;
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = all (for superadmin)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _load();
    });
    _initialize();
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
      if (_tabController.index == 0) {
        // ค้างชำระ: แสดงบิลที่ยังไม่ชำระ (pending/partial/overdue)
        final all = await InvoiceService.getAllInvoices(
          branchId: _currentBranchFilter(),
          limit: 500,
        );
        final unpaid = all.where((inv) {
          final st = (inv['invoice_status'] ?? '').toString();
          return st != 'paid' && st != 'cancelled';
        }).toList();
        setState(() {
          _invoices = unpaid;
          _slips = [];
          _loading = false;
        });
      } else {
        final status = _slipTabStatus();
        final res = await PaymentService.listPaymentSlips(
          status: status,
          branchId: _currentBranchFilter(),
        );
        // If showing "ชำระแล้ว" (verified), include PromptPay payments that have no slip
        List<Map<String, dynamic>> ppPaid = [];
        if (status == 'verified') {
          ppPaid = await PaymentService.listPromptPayVerifiedPayments(
            branchId: _currentBranchFilter(),
          );
        }
        // เงื่อนไขตามนโยบาย:
        // - ธนาคาร: ต้องมีสลิปรออนุมัติ (แสดงในแท็บรอดำเนินการ)
        // - PromptPay: ถ้าชำระครบจำนวนจะอนุมัติอัตโนมัติและไม่ต้องตรวจสอบสลิป → ไม่ต้องแสดงใน Pending
        final filtered = (status == 'pending')
            ? res.where((e) => (e['payment_method'] ?? 'transfer') == 'transfer').toList()
            : res;
        setState(() {
          _slips = [
            ...filtered,
            ...ppPaid,
          ];
          _invoices = [];
          _loading = false;
        });
      }
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

  String _slipTabStatus() {
    // index 1..3 => slips
    switch (_tabController.index) {
      case 1:
        return 'pending'; // รอดำเนินการ: มีสลิปรออนุมัติ
      case 2:
        return 'verified'; // ชำระแล้ว: อนุมัติแล้ว
      case 3:
        return 'rejected'; // ปฏิเสธ
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
    final platform = Theme.of(context).platform;
    final bool isMobileApp = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (meterlist style)
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new,
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
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tabs (neutral like meterlist)
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
                            Tab(text: 'รอดำเนินการ'),
                            Tab(text: 'ชำระแล้ว'),
                            Tab(text: 'ปฏิเสธ'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // On mobile app, always show list for simplicity
                          if (isMobileApp || constraints.maxWidth <= 600) {
                            return (_tabController.index == 0)
                                ? _buildInvoiceListView()
                                : _buildSlipListView();
                          }

                          // Web/Desktop: grid for wider screens
                          if (_tabController.index == 0) {
                            return _buildInvoiceGridView(constraints.maxWidth);
                          } else {
                            return _buildSlipGridView(constraints.maxWidth);
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
      itemBuilder: (context, index) => _slipCard(_slips[index]),
    );
  }

  Widget _buildInvoiceListView() {
    if (_invoices.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('ไม่พบข้อมูล')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _invoices.length,
      itemBuilder: (context, index) => _invoiceCard(_invoices[index]),
    );
  }

  // Grid builders (web/desktop)
  Widget _buildSlipGridView(double screenWidth) {
    if (_slips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text('ไม่พบข้อมูล'),
        ),
      );
    }

    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
    }

    const double horizontalPadding = 24;
    const double crossSpacing = 16;
    final double availableWidth = screenWidth -
        (horizontalPadding * 2) -
        (crossSpacing * (crossAxisCount - 1));
    final double tileWidth = availableWidth / crossAxisCount;

    final double estHeader = tileWidth < 300 ? 140 : 120; // title/rows
    final double estMedia = 96; // image height in card
    final double estButtons = 56; // actions row
    final double estimatedTileHeight =
        estHeader + estMedia + estButtons + 24; // paddings
    double dynamicAspect = tileWidth / estimatedTileHeight;
    dynamicAspect = dynamicAspect.clamp(0.70, 1.20);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: dynamicAspect,
      ),
      itemCount: _slips.length,
      itemBuilder: (context, index) => _slipCard(_slips[index]),
    );
  }

  Widget _buildInvoiceGridView(double screenWidth) {
    if (_invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text('ไม่พบข้อมูล'),
        ),
      );
    }

    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
    }

    const double horizontalPadding = 24;
    const double crossSpacing = 16;
    final double availableWidth = screenWidth -
        (horizontalPadding * 2) -
        (crossSpacing * (crossAxisCount - 1));
    final double tileWidth = availableWidth / crossAxisCount;

    final double estHeader = tileWidth < 300 ? 120 : 100;
    final double estInfo = tileWidth < 300 ? 100 : 80;
    final double estimatedTileHeight = estHeader + estInfo + 24;
    double dynamicAspect = tileWidth / estimatedTileHeight;
    dynamicAspect = dynamicAspect.clamp(0.80, 1.40);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: dynamicAspect,
      ),
      itemCount: _invoices.length,
      itemBuilder: (context, index) => _invoiceCard(_invoices[index]),
    );
  }

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
    final amount = _asDouble(s['paid_amount']);
    final status = (s['slip_status'] ?? 'pending').toString();
    final createdAt = (s['created_at'] ?? '').toString();
    final canAction = status == 'pending';
    final isPromptPay = (s['payment_method'] ?? 'transfer') == 'promptpay' ||
        (s['is_promptpay'] == true);

    return LayoutBuilder(builder: (context, constraints) {
      final double width = constraints.maxWidth;
      final bool isSmall = width < 320;
      final double titleSize = isSmall ? 15 : 16;
      final double bodySize = isSmall ? 12 : 13;
      final double iconSize = isSmall ? 16 : 18;
      final double mediaHeight = (width * 0.35).clamp(96.0, 140.0);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentVerificationDetailPage(
                  slipId: (s['slip_id'] ?? '').toString(),
                ),
              ),
            );
            if (mounted) await _load();
          },
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
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: iconSize, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (s['invoice_number'] ?? '-').toString(),
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(status),
                      const SizedBox(width: 6),
                      _methodChip(isPromptPay ? 'promptpay' : 'transfer'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Media
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ((s['slip_image'] ?? '').toString().isNotEmpty)
                        ? Image.network(
                            s['slip_image'],
                            height: mediaHeight,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: mediaHeight,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Icon(Icons.image,
                                color: Colors.grey[400], size: 36),
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((s['tenant_name'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: iconSize, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (s['tenant_name'] ?? '-').toString(),
                                  style: TextStyle(
                                      fontSize: bodySize,
                                      color: Colors.grey[700]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.meeting_room_outlined,
                                  size: iconSize, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text((s['room_number'] ?? '-').toString(),
                                  style: TextStyle(
                                      fontSize: bodySize,
                                      color: Colors.grey[700])),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business_outlined,
                                  size: iconSize, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text((s['branch_name'] ?? '-').toString(),
                                  style: TextStyle(
                                      fontSize: bodySize,
                                      color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payments,
                              size: iconSize, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text('${amount.toStringAsFixed(2)} บาท',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          const Spacer(),
                          const Icon(Icons.schedule,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(createdAt.split('T').first,
                              style: TextStyle(
                                  fontSize: bodySize, color: Colors.grey[700])),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    children: [
                      if (canAction && !isPromptPay) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectSlip(s),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('ปฏิเสธ',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveSlip(s),
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('อนุมัติ',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentVerificationDetailPage(
                                    slipId: (s['slip_id'] ?? '').toString(),
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text('รายละเอียด'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (status == 'verified')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async => _printSlip(s),
                              icon:
                                  const Icon(Icons.print, color: Colors.white),
                              label: const Text('พิมพ์สลิป',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
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

  Widget _invoiceCard(Map<String, dynamic> inv) {
    double _asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final total = _asDouble(inv['total_amount']);
    final paid = _asDouble(inv['paid_amount']);
    final remain = total - paid;
    final status = (inv['invoice_status'] ?? '').toString();
    final due = (inv['due_date'] ?? '').toString();

    Color sc;
    String st;
    switch (status) {
      case 'overdue':
        sc = Colors.red;
        st = 'เกินกำหนด';
        break;
      case 'partial':
        sc = Colors.orange;
        st = 'ชำระบางส่วน';
        break;
      case 'pending':
      default:
        sc = Colors.blueGrey;
        st = 'ค้างชำระ';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16),
                const SizedBox(width: 6),
                Text(
                  (inv['invoice_number'] ?? '-').toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.1),
                    border: Border.all(color: sc.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    st,
                    style: TextStyle(
                        color: sc, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (due.isNotEmpty) ...[
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(due.split('T').first),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text('ผู้เช่า: ${(inv['tenant_name'] ?? '-')}'),
            Text(
                'ห้อง: ${(inv['room_number'] ?? '-')} • สาขา: ${(inv['branch_name'] ?? '-')}'),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16),
                const SizedBox(width: 6),
                Text('รวม ${total.toStringAsFixed(2)} บาท',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text('ชำระแล้ว ${paid.toStringAsFixed(2)}'),
                const Spacer(),
                Text('คงเหลือ ${remain.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    String t;
    switch (status) {
      case 'verified':
        c = Colors.green;
        t = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        c = Colors.red;
        t = 'ถูกปฏิเสธ';
        break;
      default:
        c = Colors.orange;
        t = 'รอตรวจสอบ';
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

  Widget _methodChip(String method) {
    final isPP = method == 'promptpay';
    final c = isPP ? Colors.indigo : Colors.teal;
    final t = isPP ? 'PromptPay' : 'โอนธนาคาร';
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
}
