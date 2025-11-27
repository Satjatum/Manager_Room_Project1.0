import 'package:flutter/material.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/branch_service.dart';
import '../services/branch_payment_qr_service.dart';
import 'widgets/snack_message.dart';

class PaymentQrManagementUi extends StatefulWidget {
  final String? branchId;
  const PaymentQrManagementUi({super.key, this.branchId});

  @override
  State<PaymentQrManagementUi> createState() => _PaymentQrManagementUiState();
}

class _PaymentQrManagementUiState extends State<PaymentQrManagementUi> {
  UserModel? _user;
  bool _loading = true;
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _qrs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _user = await AuthService.getCurrentUser();
      if (widget.branchId != null) {
        _selectedBranchId = widget.branchId;
        _branches = [];
        await _loadQrs();
      } else {
        _branches = await BranchService.getBranchesByUser();
        if (_branches.isNotEmpty) {
          _selectedBranchId = _branches.first['branch_id'];
          await _loadQrs();
        }
      }
    } catch (e) {
      if (mounted) {
        SnackMessage.showError(context, 'โหลดข้อมูลล้มเหลว: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQrs() async {
    if (_selectedBranchId == null) return;
    setState(() => _busy = true);
    try {
      _qrs = await BranchPaymentQrService.getByBranch(_selectedBranchId!);
      // ตัด PromptPay ออกทั้งหมดจากรายการแสดงผล
      _qrs = _qrs
          .where((q) => (q['promptpay_id'] == null ||
              q['promptpay_id'].toString().isEmpty))
          .toList();
    } catch (e) {
      if (mounted) {
        SnackMessage.showError(context, 'โหลดบัญชี/QR ล้มเหลว: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? record}) async {
    if (_selectedBranchId == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _QrEditorDialog(
        branchId: _selectedBranchId!,
        record: record,
      ),
    );
    if (result == true) {
      await _loadQrs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _selectedBranchId != null
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: const Color(0xff10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff10B981),
                  strokeWidth: 3,
                ),
              )
            : Column(
                children: [
                  // Header (unified style)
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
                                'ตั้งค่าบัญชี',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'จัดการบัญชีธนาคารสำหรับรับการโอนเงิน',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.branchId == null && _branches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedBranchId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'เลือกสาขา',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.store,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                          items: _branches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['branch_id'],
                              child: Text(
                                '${b['branch_name']} (${b['branch_code'] ?? '-'})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) async {
                            setState(() => _selectedBranchId = v);
                            await _loadQrs();
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: _busy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xff10B981),
                              strokeWidth: 3,
                            ),
                          )
                        : _qrs.isEmpty
                            ? RefreshIndicator(
                                backgroundColor: Colors.white,
                                onRefresh: _loadQrs,
                                color: const Color(0xff10B981),
                                child: Center(
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.qr_code_rounded,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'ยังไม่มีบัญชี/QR',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'แตะ "เพิ่ม" เพื่อสร้างรายการแรก',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                backgroundColor: Colors.white,
                                onRefresh: _loadQrs,
                                color: const Color(0xff10B981),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _qrs.length,
                                  itemBuilder: (ctx, i) {
                                    final q = _qrs[i];
                                    final isActive =
                                        (q['is_active'] ?? true) == true;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: InkWell(
                                        onTap: () => _openEditor(record: q),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.08),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .account_balance_rounded,
                                                      size: 28,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 4,
                                                    top: 4,
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? const Color(
                                                                0xFF10B981)
                                                            : Colors
                                                                .grey.shade400,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      q['bank_name'] ?? '-',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      q['account_number'] ??
                                                          '-',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors
                                                            .grey.shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      q['account_name'] ?? '-',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                color: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  color: Colors.grey.shade600,
                                                ),
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: ListTile(
                                                      dense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      leading: Icon(
                                                          Icons.edit_outlined,
                                                          size: 20,
                                                          color: Color(
                                                              0xFF14B8A6)),
                                                      title: Text('แก้ไข'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'toggle',
                                                    child: ListTile(
                                                      dense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      leading: Icon(
                                                        isActive
                                                            ? Icons
                                                                .visibility_off_outlined
                                                            : Icons
                                                                .visibility_outlined,
                                                        size: 20,
                                                        color: isActive
                                                            ? Colors.orange
                                                            : Colors.green,
                                                      ),
                                                      title: Text(
                                                        isActive
                                                            ? 'ปิดใช้งาน'
                                                            : 'เปิดใช้งาน',
                                                        style: TextStyle(
                                                            color: isActive
                                                                ? Colors.orange
                                                                : Colors.green),
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: ListTile(
                                                      dense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      leading: Icon(
                                                          Icons.delete_outline,
                                                          size: 20,
                                                          color: Colors.red),
                                                      title: Text('ลบ',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red)),
                                                    ),
                                                  ),
                                                ],
                                                onSelected: (val) async {
                                                  if (val == 'edit') {
                                                    _openEditor(record: q);
                                                  } else if (val == 'toggle') {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          Dialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(24),
                                                          constraints:
                                                              const BoxConstraints(
                                                                  maxWidth:
                                                                      400),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // Icon Header
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        16),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isActive
                                                                      ? Colors
                                                                          .orange
                                                                          .shade50
                                                                      : Colors
                                                                          .green
                                                                          .shade50,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: Icon(
                                                                  isActive
                                                                      ? Icons
                                                                          .visibility_off_rounded
                                                                      : Icons
                                                                          .visibility_rounded,
                                                                  color: isActive
                                                                      ? Colors
                                                                          .orange
                                                                          .shade600
                                                                      : Colors
                                                                          .green
                                                                          .shade600,
                                                                  size: 40,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 20),

                                                              // Title
                                                              Text(
                                                                isActive
                                                                    ? 'ปิดใช้งานบัญชีนี้หรือไม่?'
                                                                    : 'เปิดใช้งานบัญชีนี้หรือไม่?',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 12),

                                                              // Account Info
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 10,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                          .grey[
                                                                      100],
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                              .grey[
                                                                          300]!),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .account_balance_rounded,
                                                                        size:
                                                                            18,
                                                                        color: Colors
                                                                            .grey[700]),
                                                                    const SizedBox(
                                                                        width:
                                                                            8),
                                                                    Flexible(
                                                                      child:
                                                                          Text(
                                                                        '${q['bank_name'] ?? '-'} (${q['account_number'] ?? '-'})',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.black87,
                                                                        ),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        maxLines:
                                                                            2,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),

                                                              // Warning/Info Box
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        14),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: isActive
                                                                      ? Colors
                                                                          .orange
                                                                          .shade50
                                                                      : Colors
                                                                          .green
                                                                          .shade50,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  border: Border
                                                                      .all(
                                                                    color: isActive
                                                                        ? Colors
                                                                            .orange
                                                                            .shade100
                                                                        : Colors
                                                                            .green
                                                                            .shade100,
                                                                    width: 1.5,
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      isActive
                                                                          ? Icons
                                                                              .warning_rounded
                                                                          : Icons
                                                                              .info_rounded,
                                                                      color: isActive
                                                                          ? Colors
                                                                              .orange
                                                                              .shade600
                                                                          : Colors
                                                                              .green
                                                                              .shade600,
                                                                      size: 22,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        isActive
                                                                            ? 'บัญชีนี้จะไม่แสดงในรายการชำระเงิน'
                                                                            : 'บัญชีนี้จะแสดงในรายการชำระเงิน',
                                                                        style:
                                                                            TextStyle(
                                                                          color: isActive
                                                                              ? Colors.orange.shade800
                                                                              : Colors.green.shade800,
                                                                          fontSize:
                                                                              13,
                                                                          height:
                                                                              1.4,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 24),

                                                              // Action Buttons
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        OutlinedButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          false),
                                                                      style: OutlinedButton
                                                                          .styleFrom(
                                                                        foregroundColor:
                                                                            Colors.grey[700],
                                                                        side:
                                                                            BorderSide(
                                                                          color:
                                                                              Colors.grey[300]!,
                                                                          width:
                                                                              1.5,
                                                                        ),
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                14),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(10),
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          const Text(
                                                                        'ยกเลิก',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child:
                                                                        ElevatedButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          true),
                                                                      style: ElevatedButton
                                                                          .styleFrom(
                                                                        backgroundColor: isActive
                                                                            ? Colors.orange.shade600
                                                                            : Colors.green.shade600,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                14),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(10),
                                                                        ),
                                                                        elevation:
                                                                            0,
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        isActive
                                                                            ? 'ปิดใช้งาน'
                                                                            : 'เปิดใช้งาน',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );

                                                    if (confirm == true) {
                                                      final res =
                                                          await BranchPaymentQrService
                                                              .toggleActive(
                                                        q['qr_id'].toString(),
                                                        !isActive,
                                                      );
                                                      if (mounted) {
                                                        if (res['success'] ==
                                                            true) {
                                                          SnackMessage
                                                              .showSuccess(
                                                            context,
                                                            isActive
                                                                ? 'ปิดใช้งานแล้ว'
                                                                : 'เปิดใช้งานแล้ว',
                                                          );
                                                        } else {
                                                          SnackMessage
                                                              .showError(
                                                            context,
                                                            res['message'] ??
                                                                'ทำรายการไม่สำเร็จ',
                                                          );
                                                        }
                                                        await _loadQrs();
                                                      }
                                                    }
                                                  } else if (val == 'delete') {
                                                    final ok =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          Dialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                        ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(24),
                                                          constraints:
                                                              const BoxConstraints(
                                                                  maxWidth:
                                                                      400),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // Icon Header
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        16),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .red
                                                                      .shade50,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: Icon(
                                                                  Icons
                                                                      .delete_outline,
                                                                  color: Colors
                                                                      .red
                                                                      .shade600,
                                                                  size: 40,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 20),

                                                              // Title
                                                              const Text(
                                                                'ลบบัญชีนี้หรือไม่?',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 12),

                                                              // Account Info
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 10,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                          .grey[
                                                                      100],
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                              .grey[
                                                                          300]!),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .account_balance_rounded,
                                                                        size:
                                                                            18,
                                                                        color: Colors
                                                                            .grey[700]),
                                                                    const SizedBox(
                                                                        width:
                                                                            8),
                                                                    Flexible(
                                                                      child:
                                                                          Text(
                                                                        '${q['bank_name'] ?? '-'} (${q['account_number'] ?? '-'})',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.black87,
                                                                        ),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        maxLines:
                                                                            2,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),

                                                              // Warning Box
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        14),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .red
                                                                      .shade50,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  border: Border
                                                                      .all(
                                                                    color: Colors
                                                                        .red
                                                                        .shade100,
                                                                    width: 1.5,
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .warning,
                                                                      color: Colors
                                                                          .red
                                                                          .shade600,
                                                                      size: 22,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        'ข้อมูลทั้งหมดจะถูกลบอย่างถาวร',
                                                                        style:
                                                                            TextStyle(
                                                                          color: Colors
                                                                              .red
                                                                              .shade800,
                                                                          fontSize:
                                                                              13,
                                                                          height:
                                                                              1.4,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 24),

                                                              // Action Buttons
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        OutlinedButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          false),
                                                                      style: OutlinedButton
                                                                          .styleFrom(
                                                                        foregroundColor:
                                                                            Colors.grey[700],
                                                                        side:
                                                                            BorderSide(
                                                                          color:
                                                                              Colors.grey[300]!,
                                                                          width:
                                                                              1.5,
                                                                        ),
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                14),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(10),
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          const Text(
                                                                        'ยกเลิก',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child:
                                                                        ElevatedButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          true),
                                                                      style: ElevatedButton
                                                                          .styleFrom(
                                                                        backgroundColor: Colors
                                                                            .red
                                                                            .shade600,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                14),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(10),
                                                                        ),
                                                                        elevation:
                                                                            0,
                                                                      ),
                                                                      child:
                                                                          const Text(
                                                                        'ลบ',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                    if (ok == true) {
                                                      final res =
                                                          await BranchPaymentQrService
                                                              .delete(q['qr_id']
                                                                  .toString());
                                                      if (mounted) {
                                                        if (res['success'] ==
                                                            true) {
                                                          SnackMessage
                                                              .showSuccess(
                                                            context,
                                                            'ลบสำเร็จ',
                                                          );
                                                        } else {
                                                          SnackMessage
                                                              .showError(
                                                            context,
                                                            res['message'] ??
                                                                'ลบไม่สำเร็จ',
                                                          );
                                                        }
                                                        await _loadQrs();
                                                      }
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _QrEditorDialog extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic>? record;
  const _QrEditorDialog({required this.branchId, this.record});

  @override
  State<_QrEditorDialog> createState() => _QrEditorDialogState();
}

class _QrEditorDialogState extends State<_QrEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _bankCtrl.text = (r['bank_name'] ?? '').toString();
      _accNameCtrl.text = (r['account_name'] ?? '').toString();
      _accNumCtrl.text = (r['account_number'] ?? '').toString();
      _isActive = (r['is_active'] ?? true) == true;
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> payload = {
        'branch_id': widget.branchId,
        'bank_name': _bankCtrl.text.trim(),
        'account_name': _accNameCtrl.text.trim(),
        'account_number': _accNumCtrl.text.trim(),
        'promptpay_type': null,
        'promptpay_id': null,
        'qr_code_image': '',
        'is_active': _isActive,
      };

      Map<String, dynamic> res;
      if (widget.record == null) {
        res = await BranchPaymentQrService.create(payload);
      } else {
        res = await BranchPaymentQrService.update(
          widget.record!['qr_id'].toString(),
          payload,
        );
      }

      if (!mounted) return;
      if (res['success'] == true) {
        SnackMessage.showSuccess(context, 'บันทึกสำเร็จ');
        Navigator.pop(context, true);
      } else {
        SnackMessage.showError(
          context,
          res['message'] ?? 'บันทึกไม่สำเร็จ',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackMessage.showError(context, 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.record != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.add_circle_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'แก้ไขบัญชี/QR' : 'เพิ่มบัญชี/QR ใหม่',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEdit
                                  ? 'อัปเดตรายละเอียด'
                                  : 'สร้างบัญชี/QR ใหม่',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFormField(
                    label: 'ธนาคาร',
                    hint: 'เช่น ธนาคารกสิกรไทย',
                    controller: _bankCtrl,
                    icon: Icons.account_balance_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกธนาคาร' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildFormField(
                    label: 'ชื่อบัญชี ',
                    hint: 'ชื่อเจ้าของบัญชี',
                    controller: _accNameCtrl,
                    icon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรอกชื่อบัญชี'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildFormField(
                    label: 'เลขบัญชี',
                    hint: 'เลขที่บัญชี',
                    controller: _accNumCtrl,
                    icon: Icons.numbers_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกเลขบัญชี' : null,
                  ),
                  // ลบส่วนอัปโหลดรูป QR ตามข้อกำหนดใหม่
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isActive
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isActive ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isActive
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'สถานะการใช้งาน',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isActive
                                    ? 'บัญชีนี้กำลังใช้งาน'
                                    : 'บัญชีนี้ปิดการใช้งาน',
                                style: TextStyle(
                                  color: _isActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                          },
                          activeColor: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                  // ลบส่วนตั้งบัญชีหลัก เนื่องจากไม่มี is_primary แล้ว
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'ยกเลิก',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEdit ? 'แก้ไข' : 'บันทึก',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
