import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/branch_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

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
        branches = await BranchService.getBranchesByUser();
        if (user.userRole == UserRole.admin) {
          if (branches.isNotEmpty) {
            initialBranchId = branches.first['branch_id'];
          }
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
      // อัปเดตสถานะบิลเกินกำหนดอัตโนมัติ
      try {
        await InvoiceService.updateOverdueInvoices();
      } catch (_) {}

      final status = _invoiceTabStatus();
      final invoices = await InvoiceService.getAllInvoices(
        branchId: _currentBranchFilter(),
        status: status,
        searchQuery: _search.isEmpty ? null : _search,
      );

      setState(() {
        _invoices = invoices;
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

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รายการบิล',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'รายการบิลทั้งหมดในสาขา',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            // Search Bar
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
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
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

            const SizedBox(height: 16),

            // แท็บตัวกรองตามสถานะบิล
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
                      child: _buildInvoiceListView(),
                    ),
            ),
          ],
        ),
      ),
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
      itemBuilder: (context, index) {
        return _invoiceCard(_invoices[index]);
      },
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv) {
    final invoiceId = (inv['invoice_id'] ?? '').toString();
    final total = _asDouble(inv['total_amount']);
    final paid = _asDouble(inv['paid_amount']);
    final remaining = (total - paid).clamp(0.0, double.infinity).toDouble();
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

    return Container(
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
          // Status row
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
          // Amount block
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              if (paid > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('ชำระแล้ว',
                        style: TextStyle(fontSize: 12, color: Colors.green)),
                    const Spacer(),
                    Text(
                      '${_formatMoney(paid)} บาท',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
              if (remaining > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('คงเหลือ',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                    const Spacer(),
                    Text(
                      '${_formatMoney(remaining)} บาท',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

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
