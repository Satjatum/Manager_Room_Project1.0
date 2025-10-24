import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/branch_service.dart';
import '../services/branch_payment_qr_service.dart';
import '../services/image_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('โหลดบัญชี/QR ล้มเหลว: $e')));
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'ตั้งค่าบัญชี/QR รับชำระ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xff10B981),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: widget.branchId != null
                          ? const SizedBox()
                          : _branches.isEmpty
                              ? const SizedBox()
                              : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'เลือกสาขา',
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.store,
                                    color: Color(0xFF1ABC9C),
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
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(16),
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
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _qrs.length,
                                itemBuilder: (ctx, i) {
                                  final q = _qrs[i];
                                  final isActive =
                                      (q['is_active'] ?? true) == true;
                                  final isPrimary =
                                      (q['is_primary'] ?? false) == true;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () => _openEditor(record: q),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (q['qr_code_image'] !=
                                                        null &&
                                                    q['qr_code_image']
                                                        .toString()
                                                        .isNotEmpty)
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Image.network(
                                                      q['qr_code_image'],
                                                      width: 64,
                                                      height: 64,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: 64,
                                                    height: 64,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF1ABC9C)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.qr_code_rounded,
                                                      size: 32,
                                                      color: Color(0xFF1ABC9C),
                                                    ),
                                                  ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        q['bank_name'] ?? '-',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        q['account_name'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey.shade700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        q['account_number'] ??
                                                            '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  icon: Icon(
                                                    Icons.more_vert_rounded,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: const [
                                                          Icon(
                                                              Icons
                                                                  .edit_rounded,
                                                              color: Color(
                                                                  0xFF1ABC9C),
                                                              size: 18),
                                                          SizedBox(width: 8),
                                                          Text('แก้ไข'),
                                                        ],
                                                      ),
                                                    ),
                                                    if (!isPrimary)
                                                      PopupMenuItem(
                                                        value: 'primary',
                                                        child: Row(
                                                          children: const [
                                                            Icon(
                                                                Icons
                                                                    .star_rounded,
                                                                color: Colors
                                                                    .orange,
                                                                size: 18),
                                                            SizedBox(width: 8),
                                                            Text(
                                                                'ตั้งเป็นบัญชีหลัก'),
                                                          ],
                                                        ),
                                                      ),
                                                    PopupMenuItem(
                                                      value: 'toggle',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            isActive
                                                                ? Icons
                                                                    .visibility_off_rounded
                                                                : Icons
                                                                    .visibility_rounded,
                                                            color: Colors.blue,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(isActive
                                                              ? 'ปิดใช้งาน'
                                                              : 'เปิดใช้งาน'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: const [
                                                          Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color: Colors.red,
                                                              size: 18),
                                                          SizedBox(width: 8),
                                                          Text('ลบ',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  onSelected: (val) async {
                                                    if (val == 'edit') {
                                                      _openEditor(record: q);
                                                    } else if (val ==
                                                        'primary') {
                                                      final res =
                                                          await BranchPaymentQrService
                                                              .setPrimary(
                                                        qrId: q['qr_id']
                                                            .toString(),
                                                        branchId:
                                                            _selectedBranchId!,
                                                      );
                                                      if (mounted) {
                                                        if (res['success'] ==
                                                            true) {
                                                          _showSuccessSnackBar(
                                                              'ตั้งเป็นบัญชีหลักแล้ว');
                                                        } else {
                                                          _showErrorSnackBar(res[
                                                                  'message'] ??
                                                              'ทำรายการไม่สำเร็จ');
                                                        }
                                                        await _loadQrs();
                                                      }
                                                    } else if (val ==
                                                        'toggle') {
                                                      final res =
                                                          await BranchPaymentQrService
                                                              .toggleActive(
                                                        q['qr_id'].toString(),
                                                        !isActive,
                                                      );
                                                      if (mounted) {
                                                        if (res['success'] ==
                                                            true) {
                                                          _showSuccessSnackBar(isActive
                                                              ? 'ปิดใช้งานแล้ว'
                                                              : 'เปิดใช้งานแล้ว');
                                                        } else {
                                                          _showErrorSnackBar(res[
                                                                  'message'] ??
                                                              'ทำรายการไม่สำเร็จ');
                                                        }
                                                        await _loadQrs();
                                                      }
                                                    } else if (val ==
                                                        'delete') {
                                                      final ok =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            Dialog(
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16)),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(24),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .red
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                  ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .delete_forever_rounded,
                                                                    color: Colors
                                                                        .red
                                                                        .shade700,
                                                                    size: 28,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 16),
                                                                const Text(
                                                                  'ยืนยันการลบ',
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontSize:
                                                                          16),
                                                                ),
                                                                const SizedBox(
                                                                    height: 8),
                                                                const Text(
                                                                  'คุณต้องการลบบัญชี/QR นี้หรือไม่?',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13),
                                                                ),
                                                                const SizedBox(
                                                                    height: 24),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          OutlinedButton(
                                                                        onPressed: () => Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                        style: OutlinedButton
                                                                            .styleFrom(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              vertical: 12),
                                                                          shape:
                                                                              RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(10),
                                                                          ),
                                                                        ),
                                                                        child: const Text(
                                                                            'ยกเลิก'),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          ElevatedButton(
                                                                        onPressed: () => Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                        style: ElevatedButton
                                                                            .styleFrom(
                                                                          backgroundColor:
                                                                              Colors.red,
                                                                          foregroundColor:
                                                                              Colors.white,
                                                                          elevation:
                                                                              0,
                                                                          shape:
                                                                              RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(10),
                                                                          ),
                                                                        ),
                                                                        child: const Text(
                                                                            'ลบ'),
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
                                                                .delete(q[
                                                                        'qr_id']
                                                                    .toString());
                                                        if (mounted) {
                                                          if (res['success'] ==
                                                              true) {
                                                            _showSuccessSnackBar(
                                                                'ลบสำเร็จ');
                                                          } else {
                                                            _showErrorSnackBar(
                                                                res['message'] ??
                                                                    'ลบไม่สำเร็จ');
                                                          }
                                                          await _loadQrs();
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? const Color(
                                                            0xFFD1FAE5)
                                                        : const Color(
                                                            0xFFF3F4F6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: isActive
                                                          ? const Color(
                                                              0xFF10B981)
                                                          : Colors
                                                              .grey.shade300,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isActive
                                                            ? Icons
                                                                .check_circle_rounded
                                                            : Icons
                                                                .cancel_rounded,
                                                        size: 14,
                                                        color: isActive
                                                            ? const Color(
                                                                0xFF065F46)
                                                            : const Color(
                                                                0xFF6B7280),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        isActive
                                                            ? 'เปิดใช้งาน'
                                                            : 'ปิดใช้งาน',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF065F46)
                                                              : const Color(
                                                                  0xFF6B7280),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isPrimary)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: Colors
                                                              .orange.shade200),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.star_rounded,
                                                            size: 14,
                                                            color: Colors.orange
                                                                .shade700),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          'บัญชีหลัก',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.orange
                                                                .shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
  final _orderCtrl = TextEditingController();
  bool _isActive = true;
  bool _isPrimary = false;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _bankCtrl.text = (r['bank_name'] ?? '').toString();
      _accNameCtrl.text = (r['account_name'] ?? '').toString();
      _accNumCtrl.text = (r['account_number'] ?? '').toString();
      _orderCtrl.text = (r['display_order'] ?? '').toString();
      _isActive = (r['is_active'] ?? true) == true;
      _isPrimary = (r['is_primary'] ?? false) == true;
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? imageUrl = widget.record?['qr_code_image'];
      if (_image != null) {
        Map<String, dynamic> upload;
        if (kIsWeb) {
          final bytes = await _image!.readAsBytes();
          upload = await ImageService.uploadImageFromBytes(
            bytes,
            _image!.name,
            'branch-payment-qr',
            folder: widget.branchId,
            prefix: 'qr',
            context: 'branch_${widget.branchId}',
          );
        } else {
          upload = await ImageService.uploadImage(
            File(_image!.path),
            'branch-payment-qr',
            folder: widget.branchId,
            prefix: 'qr',
            context: 'branch_${widget.branchId}',
          );
        }

        if (upload['success'] != true) {
          throw upload['message'] ?? 'อัปโหลดรูป QR ไม่สำเร็จ';
        }
        imageUrl = upload['url'];
      }

      final payload = {
        'branch_id': widget.branchId,
        'bank_name': _bankCtrl.text.trim(),
        'account_name': _accNameCtrl.text.trim(),
        'account_number': _accNumCtrl.text.trim(),
        'qr_code_image': imageUrl,
        'is_active': _isActive,
        'is_primary': _isPrimary,
        'display_order': int.tryParse(_orderCtrl.text.trim()),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                res['success'] == true
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(res['success'] == true
                    ? 'บันทึกสำเร็จ'
                    : (res['message'] ?? 'บันทึกไม่สำเร็จ')),
              ),
            ],
          ),
          backgroundColor: res['success'] == true
              ? Colors.green.shade600
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (res['success'] == true) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
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
            prefixIcon: Icon(icon, color: const Color(0xFF1ABC9C), size: 20),
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
              borderSide: const BorderSide(color: Color(0xFF1ABC9C), width: 2),
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
                          color: const Color(0xFF1ABC9C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.add_circle_rounded,
                          color: const Color(0xFF1ABC9C),
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
                                color: Color(0xFF1ABC9C),
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
                    label: 'ธนาคาร *',
                    hint: 'เช่น ธนาคารกสิกรไทย',
                    controller: _bankCtrl,
                    icon: Icons.account_balance_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกธนาคาร' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildFormField(
                    label: 'ชื่อบัญชี *',
                    hint: 'ชื่อเจ้าของบัญชี',
                    controller: _accNameCtrl,
                    icon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรอกชื่อบัญชี'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildFormField(
                    label: 'เลขบัญชี *',
                    hint: 'เลขที่บัญชี',
                    controller: _accNumCtrl,
                    icon: Icons.numbers_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกเลขบัญชี' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildFormField(
                    label: 'ลำดับแสดง',
                    hint: '0',
                    controller: _orderCtrl,
                    icon: Icons.sort_rounded,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.image_rounded,
                            color: Colors.blue.shade700, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'รูปภาพ QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF86EFAC),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_image != null ||
                              widget.record?['qr_code_image'] != null)
                            Container(
                              height: 120,
                              width: 120,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _image != null
                                    ? (kIsWeb
                                        ? FutureBuilder<Uint8List>(
                                            future: _image!.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(_image!.path),
                                            fit: BoxFit.cover,
                                          ))
                                    : Image.network(
                                        widget.record!['qr_code_image'],
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.file_upload_outlined,
                                size: 48,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _image != null ||
                                    widget.record?['qr_code_image'] != null
                                ? 'แตะเพื่อเปลี่ยนรูปภาพ'
                                : 'เลือกไฟล์รูปภาพ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'แตะหรือลากไฟล์รูปภาพมาวางที่นี่',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'รองรับ JPG, PNG, WebP (สูงสุด 5MB)',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF065F46),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          activeColor: const Color(0xFF1ABC9C),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isPrimary
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPrimary
                            ? Colors.orange.shade200
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isPrimary ? Colors.orange : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isPrimary
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
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
                                'บัญชีหลัก',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isPrimary
                                    ? 'ตั้งเป็นบัญชีหลักของสาขา'
                                    : 'ไม่ได้ตั้งเป็นบัญชีหลัก',
                                style: TextStyle(
                                  color: _isPrimary
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPrimary,
                          onChanged: (value) {
                            setState(() => _isPrimary = value);
                          },
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
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
                            backgroundColor: const Color(0xFF1ABC9C),
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
                                  isEdit ? 'บันทึก' : 'เพิ่ม',
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
