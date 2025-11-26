import 'package:flutter/material.dart';
import 'package:manager_room_project/services/invoice_service.dart';
import 'package:manager_room_project/services/meter_service.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/services/auth_service.dart';
import 'package:manager_room_project/services/payment_rate_service.dart';
import 'package:manager_room_project/services/receipt_print_service.dart';
import 'package:manager_room_project/models/user_models.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import 'package:manager_room_project/views/tenant/tenant_pay_bill_ui.dart';
import 'package:manager_room_project/utils/formatMonthy.dart';

class InvoiceListDetailUi extends StatefulWidget {
  final String invoiceId;
  const InvoiceListDetailUi({super.key, required this.invoiceId});

  @override
  State<InvoiceListDetailUi> createState() => _InvoiceListDetailUiState();
}

class _InvoiceListDetailUiState extends State<InvoiceListDetailUi> {
  bool _loading = true;
  Map<String, dynamic>? _invoice;
  final Map<String, Map<String, dynamic>> _readingById = {};
  Map<String, dynamic>? _latestSlip;
  Map<String, dynamic>? _paymentSettings;
  bool _pendingVerification = false;
  bool _rejectedSlip = false;
  String _rejectionReason = '';
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) {
      final out = <Map<String, dynamic>>[];
      for (final e in v) {
        if (e is Map) out.add(Map<String, dynamic>.from(e as Map));
      }
      return out;
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    if (v is List && v.isNotEmpty && v.first is Map) {
      return Map<String, dynamic>.from(v.first as Map);
    }
    return <String, dynamic>{};
  }

  String _thaiDate(String s) => Formatmonthy.formatThaiDateStr(s);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // โหลดข้อมูล user ปัจจุบัน
      final user = await AuthService.getCurrentUser();
      _currentUser = user;

      var invRaw = await InvoiceService.getInvoiceById(widget.invoiceId);
      // Hybrid: รีคอมพิวต์ค่าปรับล่าช้าเมื่อเปิดดูบิล
      try {
        final changed =
            await InvoiceService.recomputeLateFeeFromSettings(widget.invoiceId);
        if (changed) {
          invRaw = await InvoiceService.getInvoiceById(widget.invoiceId);
        }
      } catch (_) {}
      if (invRaw != null) {
        // โหลด payment_settings ถ้ามี
        try {
          final paymentSettingId = invRaw['payment_setting_id']?.toString();
          if (paymentSettingId != null && paymentSettingId.isNotEmpty) {
            // ดึงข้อมูล payment_settings โดยตรงจาก setting_id
            try {
              final settings =
                  await PaymentSettingsService.getPaymentSettingById(
                      paymentSettingId);
              if (settings != null) {
                _paymentSettings = settings;
                debugPrint('✅ โหลด payment_settings สำเร็จ: $paymentSettingId');
              } else {
                debugPrint('⚠️ ไม่พบ payment_settings: $paymentSettingId');
              }
            } catch (e) {
              debugPrint('❌ Error loading payment_settings: $e');
            }
          } else {
            debugPrint('ℹ️ บิลนี้ไม่มี payment_setting_id');
          }
        } catch (e) {
          debugPrint('❌ โหลด payment_settings ไม่สำเร็จ: $e');
        }

        // preload meter readings for utilities
        try {
          final utils = _asListOfMap(invRaw['utilities']);
          final ids = utils
              .map((u) => (u['reading_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          if (ids.isNotEmpty) {
            final futures = ids.map((id) async {
              final r = await MeterReadingService.getMeterReadingById(id);
              if (r != null) _readingById[id] = r;
            });
            await Future.wait(futures);
          }
        } catch (_) {}

        // สำหรับทุก role: ตรวจสอบสถานะสลิปล่าสุด
        try {
          final user = await AuthMiddleware.getCurrentUser();
          final tenantId = (invRaw['tenant_id'] ??
                  invRaw['tenants']?['tenant_id'] ??
                  user?.tenantId)
              ?.toString();
          if (tenantId != null && tenantId.isNotEmpty) {
            final slip = await PaymentService.getLatestSlipForInvoice(
              widget.invoiceId,
              tenantId: tenantId,
            );
            _latestSlip = slip;

            // ตรวจสอบสถานะสลิปเฉพาะเมื่อมีสลิปจริงๆ
            if (slip != null) {
              final paymentId = (slip['payment_id'] ?? '').toString();
              final verifiedAt = (slip['verified_at'] ?? '').toString();
              final rejection = (slip['rejection_reason'] ?? '').toString();
              _rejectionReason = rejection;
              final isVerified = paymentId.isNotEmpty;

              // สลิปถูกปฏิเสธ: ไม่มี payment_id แต่มี verified_at
              _rejectedSlip = !isVerified && verifiedAt.isNotEmpty;

              // สลิปรอตรวจสอบ: ไม่มี payment_id และไม่มี verified_at
              _pendingVerification = !isVerified && verifiedAt.isEmpty;
            } else {
              // ไม่มีสลิป: รีเซ็ตทุกค่า
              _pendingVerification = false;
              _rejectedSlip = false;
              _rejectionReason = '';
            }
          } else {
            _latestSlip = null;
            _pendingVerification = false;
            _rejectedSlip = false;
            _rejectionReason = '';
          }
        } catch (_) {
          _latestSlip = null;
          _pendingVerification = false;
          _rejectedSlip = false;
          _rejectionReason = '';
        }
      }
      setState(() {
        _invoice = invRaw;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โหลดรายละเอียดไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : (_invoice == null)
                ? const Center(child: Text('ไม่พบบิล'))
                : RefreshIndicator(
                    backgroundColor: Colors.white,
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: [
                        Row(
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
                                    'รายละเอียดบิลค่าเช่า',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ตรวจสอบรายละเอียดบิล',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInvoiceHeaderCard(),
                        if (_pendingVerification) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Color(0xFFB45309)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'กำลังตรวจสอบรอผู้ดูแลอนุมัติการชำระเงิน',
                                    style: TextStyle(color: Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_rejectedSlip) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFEF5350)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFD32F2F)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _rejectionReason.isNotEmpty
                                        ? 'สลิปถูกปฏิเสธ: $_rejectionReason\nกรุณาส่งสลิปใหม่'
                                        : 'สลิปถูกปฏิเสธ กรุณาส่งสลิปใหม่',
                                    style: const TextStyle(
                                        color: Color(0xFFB71C1C)),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInvoiceHeaderCard() {
    final inv = _asMap(_invoice);
    final room = inv['rooms'] ?? {};
    final tenant = inv['tenants'] ?? {};

    final invoiceNumber = (inv['invoice_number'] ?? '-').toString();
    final invoiceMonthStr = (inv['invoice_month'] ?? '-').toString();
    final invoiceYearStr = (inv['invoice_year'] ?? '-').toString();
    final issueDate = (inv['issue_date'] ?? '').toString();
    final dueDate = (inv['due_date'] ?? '').toString();
    final tenantName =
        (inv['tenant_name'] ?? tenant['tenant_fullname'] ?? '-').toString();
    final tenantPhone =
        (inv['tenant_phone'] ?? tenant['tenant_phone'] ?? '-').toString();
    final roomNumber =
        (inv['room_number'] ?? room['room_number'] ?? '-').toString();
    final invoiceStatus = (inv['invoice_status'] ?? '-').toString();

    double rentalAmount = _asDouble(inv['rental_amount']);
    double lateFeeAmount = _asDouble(inv['late_fee_amount']);
    final totalAmount = _asDouble(inv['total_amount']);
    final paidAmount = _asDouble(inv['paid_amount']);
    final double remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity).toDouble();

    final utils = _asListOfMap(inv['utilities']);
    final otherLines = _asListOfMap(inv['other_charge_lines']);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '#$invoiceNumber',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _invoiceStatusChip(invoiceStatus),
              ],
            ),
            const Divider(height: 20),
            const Text('รายละเอียดบิล',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _kv('เลขบิล', invoiceNumber),
            _kv(
              'รอบบิลเดือน',
              _formatBillingCycle(invoiceMonthStr, invoiceYearStr),
            ),
            _kv('ออกบิลวันที่', _thaiDate(issueDate)),
            _kv('ครบกำหนดชำระ', _thaiDate(dueDate)),
            const SizedBox(height: 8),
            _kv('ผู้เช่า', tenantName),
            _kv('เบอร์', tenantPhone),
            _kv('ห้อง', roomNumber),
            const Divider(height: 24),
            const Text('ค่าใช้จ่าย',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _moneyRow('ค่าเช่า', rentalAmount),
            ...utils.map((u) {
              final name = (u['utility_name'] ?? '').toString();
              final unitPrice = _asDouble(u['unit_price']);
              final usage = _asDouble(u['usage_amount']);
              final total = _asDouble(u['total_amount']);
              final readingId = (u['reading_id'] ?? '').toString();
              double? prev;
              double? curr;
              if (readingId.isNotEmpty && _readingById.containsKey(readingId)) {
                final r = _readingById[readingId]!;
                if (name.contains('น้ำ')) {
                  prev = _asDouble(r['water_previous_reading']);
                  curr = _asDouble(r['water_current_reading']);
                } else if (name.contains('ไฟ')) {
                  prev = _asDouble(r['electric_previous_reading']);
                  curr = _asDouble(r['electric_current_reading']);
                }
              }
              String sub = '';
              if (prev != null && curr != null) {
                sub = Formatmonthy.formatUtilitySubtext(
                  previous: prev,
                  current: curr,
                  usage: usage,
                  unitPrice: unitPrice,
                );
              } else if (usage > 0 || unitPrice > 0) {
                // กรณีไม่มีตัวเลขก่อน/หลัง ใช้รูปแบบ: "ยูนิต (ราคา)"
                sub =
                    '${usage.toStringAsFixed(2)} (${unitPrice.toStringAsFixed(2)})';
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _moneyRow(name, total),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              );
            }).toList(),
            if (otherLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('ค่าใช้จ่ายอื่นๆ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...otherLines.map((o) {
                final title = (o['charge_name'] ?? '').toString();
                final amt = _asDouble(o['charge_amount']);
                final desc = (o['charge_desc'] ?? '').toString();
                final label = desc.isNotEmpty ? '$title ($desc)' : title;
                return _moneyRow(label, amt);
              }).toList(),
            ],
            const Divider(height: 24),
            _moneyRow('ค่าปรับชำระล่าช้า', lateFeeAmount, emphasis: true),
            _moneyRow('ยอดรวม', totalAmount, bold: true),
            _moneyRow('ชำระแล้ว', paidAmount, color: Colors.green),
            _moneyRow('คงเหลือ', remaining,
                bold: true, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount,
      {bool bold = false, bool emphasis = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color ?? (emphasis ? Colors.black : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${amount.toStringAsFixed(2)} บาท', style: style),
        ],
      ),
    );
  }

  // รูปแบบรอบบิล: เดือนภาษาไทย + ปี พ.ศ.
  String _formatBillingCycle(String monthStr, String yearStr) {
    final m = int.tryParse(monthStr);
    final y = int.tryParse(yearStr);
    if (m == null || y == null || m < 1 || m > 12) {
      return '$monthStr/$yearStr';
    }
    return Formatmonthy.formatBillingCycleTh(month: m, year: y);
  }

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

  Widget _buildBottomBar() {
    if (_invoice == null) return const SizedBox.shrink();
    final inv = _asMap(_invoice);
    final status = (inv['invoice_status'] ?? '').toString();
    final total = _asDouble(inv['total_amount']);
    final paid = _asDouble(inv['paid_amount']);
    final remaining = (total - paid);
    final disabled = status == 'paid' ||
        status == 'cancelled' ||
        remaining <= 0 ||
        _pendingVerification;

    // ถ้าสถานะเป็น 'paid' แสดงเฉพาะปุ่มดาวน์โหลดสลิป
    if (status == 'paid') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                // ใช้ _latestSlip ที่โหลดไว้แล้ว หรือดึงใหม่ถ้าไม่มี
                if (_latestSlip != null) {
                  await ReceiptPrintService.printSlipFromSlipRow(_latestSlip!);
                } else {
                  // ถ้าไม่มี slip ให้แจ้งเตือน
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('ไม่พบข้อมูลสลิปสำหรับดาวน์โหลด')),
                  );
                }
              } catch (e) {
                print('ดาวน์โหลดสลิปไม่สำเร็จ: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ดาวน์โหลดสลิปไม่สำเร็จ')),
                );
              }
            },
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text(
              'ดาวน์โหลดสลิป',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      );
    }

    // ถ้าไม่ใช่ 'paid' แสดงปุ่มชำระเงินแบบเดิม
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: disabled
              ? null
              : () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TenantPayBillUi(invoiceId: widget.invoiceId),
                    ),
                  );
                  if (res == true) {
                    await _load();
                  }
                },
          label: Text(
            disabled
                ? (_pendingVerification ? 'กำลังตรวจสอบ' : 'ชำระแล้ว')
                : 'ชำระเงิน',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            side: BorderSide(color: Colors.grey[300]!),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
