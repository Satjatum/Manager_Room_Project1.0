import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/views/tenant/bill_detail_ui.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

class TenantBillListPage extends StatefulWidget {
  const TenantBillListPage({super.key});

  @override
  State<TenantBillListPage> createState() => _TenantBillListPageState();
}

class _TenantBillListPageState extends State<TenantBillListPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _invoices = [];
  late TabController _tabController; // pending/partial/paid/overdue/cancelled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _load();
    });
    _load();
  }

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await AuthMiddleware.getCurrentUser();
      if (user == null || user.tenantId == null) {
        setState(() {
          _invoices = [];
          _loading = false;
        });
        return;
      }
      // อัปเดตสถานะบิลที่เกินกำหนดอัตโนมัติเมื่อเปิดหน้า
      try {
        await InvoiceService.updateOverdueInvoices();
      } catch (_) {}
      final status = _invoiceTabStatus();
      final invList = await InvoiceService.getAllInvoices(
        tenantId: user.tenantId,
        status: status,
        limit: 500,
        orderBy: 'due_date',
        ascending: true,
      );
      setState(() {
        _invoices = invList;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: ' + e.toString())),
        );
      }
    }
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
                          'บิลค่าเช่า',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ดูและจัดการบิลค่าเช่าของคุณ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
            builder: (_) => TenantBillDetailUi(invoiceId: invoiceId),
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
            // Amount block bottom-right
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

  String _formatMoney(double v) {
    final s = v.toStringAsFixed(2);
    // thousand separator
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

  // แปลง ISO เป็นวันที่ไทย (พ.ศ.) แบบ d MMM yyyy
  String _formatThaiDate(String iso) {
    if (iso.isEmpty) return '-';
    DateTime? dt = DateTime.tryParse(iso);
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