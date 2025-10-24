import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_rate_service.dart';
import '../services/branch_service.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';
import 'widgets/colors.dart';

class PaymentSettingsUi extends StatefulWidget {
  final String? branchId;
  const PaymentSettingsUi({Key? key, this.branchId}) : super(key: key);

  @override
  State<PaymentSettingsUi> createState() => _PaymentSettingsUiState();
}

class _PaymentSettingsUiState extends State<PaymentSettingsUi> {
  bool isLoading = true;
  String? selectedBranchId;
  List<Map<String, dynamic>> branches = [];
  UserModel? currentUser;

  // Late Fee Settings
  bool enableLateFee = false;
  String lateFeeType = 'fixed';
  final TextEditingController lateFeeAmountController = TextEditingController();
  final TextEditingController lateFeeStartDayController =
      TextEditingController();
  final TextEditingController lateFeeMaxAmountController =
      TextEditingController();

  // Discount Settings
  bool enableDiscount = false;
  final TextEditingController earlyPaymentDiscountController =
      TextEditingController();
  final TextEditingController earlyPaymentDaysController =
      TextEditingController();

  final TextEditingController settingDescController = TextEditingController();
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    // ถ้ามาจาก Workspace ของสาขา ให้ล็อกสาขาไว้
    selectedBranchId = widget.branchId ?? selectedBranchId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      currentUser = await AuthService.getCurrentUser();

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ข้อมูลผู้ใช้ไม่ถูกต้อง'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      List<Map<String, dynamic>> branchesData;

      if (currentUser!.userRole == UserRole.superAdmin) {
        branchesData = await BranchService.getAllBranches(isActive: true);
      } else if (currentUser!.userRole == UserRole.admin) {
        branchesData = await BranchService.getBranchesManagedByUser(
          currentUser!.userId,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่มีสิทธิ์เข้าถึงหน้านี้'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (branchesData.isEmpty) {
        if (mounted) {
          setState(() {
            branches = [];
            selectedBranchId = null;
            isLoading = false;
          });
        }
        return;
      }

      final branchId = widget.branchId ?? selectedBranchId ?? branchesData[0]['branch_id'];
      final settings =
          await PaymentSettingsService.getPaymentSettings(branchId);

      if (mounted) {
        setState(() {
          branches = branchesData;
          selectedBranchId = branchId;

          if (settings != null) {
            enableLateFee = settings['enable_late_fee'] ?? false;
            lateFeeType = settings['late_fee_type'] ?? 'fixed';
            lateFeeAmountController.text =
                settings['late_fee_amount']?.toString() ?? '0.00';
            lateFeeStartDayController.text =
                settings['late_fee_start_day']?.toString() ?? '1';
            lateFeeMaxAmountController.text =
                settings['late_fee_max_amount']?.toString() ?? '';

            enableDiscount = settings['enable_discount'] ?? false;
            earlyPaymentDiscountController.text =
                settings['early_payment_discount']?.toString() ?? '0.00';
            earlyPaymentDaysController.text =
                settings['early_payment_days']?.toString() ?? '0';

            settingDescController.text = settings['setting_desc'] ?? '';
            isActive = settings['is_active'] ?? true;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null || selectedBranchId == null) {
      _showError('ข้อมูลผู้ใช้ไม่ถูกต้อง');
      return;
    }

    if (enableLateFee) {
      if (lateFeeAmountController.text.isEmpty) {
        _showError('กรุณากรอกจำนวนค่าปรับ');
        return;
      }
      if (lateFeeStartDayController.text.isEmpty) {
        _showError('กรุณากรอกวันที่เริ่มคิดค่าปรับ');
        return;
      }

      final startDay = int.tryParse(lateFeeStartDayController.text) ?? 0;
      if (startDay < 1 || startDay > 31) {
        _showError('วันที่เริ่มคิดต้องอยู่ระหว่าง 1-31');
        return;
      }
    }

    if (enableDiscount) {
      if (earlyPaymentDiscountController.text.isEmpty) {
        _showError('กรุณากรอกเปอร์เซ็นต์ส่วนลด');
        return;
      }
      if (earlyPaymentDaysController.text.isEmpty) {
        _showError('กรุณากรอกจำนวนวันก่อนกำหนดชำระ');
        return;
      }

      final discount =
          double.tryParse(earlyPaymentDiscountController.text) ?? 0;
      if (discount <= 0 || discount > 100) {
        _showError('เปอร์เซ็นต์ส่วนลดต้องอยู่ระหว่าง 0-100');
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xff10B981)),
      ),
    );

    try {
      await PaymentSettingsService.savePaymentSettings(
        branchId: selectedBranchId!,
        enableLateFee: enableLateFee,
        lateFeeType: enableLateFee ? lateFeeType : null,
        lateFeeAmount: enableLateFee
            ? double.tryParse(lateFeeAmountController.text) ?? 0
            : null,
        lateFeeStartDay: enableLateFee
            ? int.tryParse(lateFeeStartDayController.text) ?? 1
            : null,
        lateFeeMaxAmount:
            enableLateFee && lateFeeMaxAmountController.text.isNotEmpty
                ? double.tryParse(lateFeeMaxAmountController.text)
                : null,
        enableDiscount: enableDiscount,
        earlyPaymentDiscount: enableDiscount
            ? double.tryParse(earlyPaymentDiscountController.text) ?? 0
            : null,
        earlyPaymentDays: enableDiscount
            ? int.tryParse(earlyPaymentDaysController.text) ?? 0
            : null,
        settingDesc: settingDescController.text.trim().isEmpty
            ? null
            : settingDescController.text.trim(),
        isActive: isActive,
        createdBy: currentUser!.userId,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('บันทึกการตั้งค่าเรียบร้อย');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _showError(String message) {
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
          'ตั้งค่าการบริการ',
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
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff10B981),
                  strokeWidth: 3,
                ),
              )
            : Column(
                children: [
                  // Branch Selector
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xff10B981),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: widget.branchId != null
                          ? const SizedBox()
                          : branches.isEmpty
                              ? const SizedBox()
                              : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedBranchId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'เลือกสาขา',
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.apartment_rounded,
                                    color: Color(0xff10B981),
                                    size: 22,
                                  ),
                                ),
                                items: branches.map((branch) {
                                  return DropdownMenuItem<String>(
                                    value: branch['branch_id'],
                                    child: Text(
                                      branch['branch_name'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedBranchId = value;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Late Fee Section
                          _buildLateFeeCard(),

                          const SizedBox(height: 16),

                          // Discount Section
                          _buildDiscountCard(),

                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _saveSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'บันทึก',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLateFeeCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ค่าปรับชำระล่าช้า',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Switch(
                  value: enableLateFee,
                  onChanged: (value) {
                    setState(() {
                      enableLateFee = value;
                    });
                  },
                  activeColor: const Color(0xff10B981),
                ),
              ],
            ),

            if (enableLateFee) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Late Fee Type
              _buildFormField(
                label: 'ประเภทค่าปรับ',
                child: DropdownButtonFormField<String>(
                  value: lateFeeType,
                  decoration: InputDecoration(
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
                      borderSide:
                          const BorderSide(color: Color(0xff10B981), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('คงที่')),
                    DropdownMenuItem(
                        value: 'percentage', child: Text('เปอร์เซ็นต์')),
                    DropdownMenuItem(value: 'daily', child: Text('รายวัน')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        lateFeeType = value;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Amount and Start Day
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: lateFeeType == 'percentage'
                          ? 'เปอร์เซ็นต์'
                          : 'จำนวนเงิน',
                      child: _buildTextField(
                        controller: lateFeeAmountController,
                        hint: '0.00',
                        icon: lateFeeType == 'percentage'
                            ? Icons.percent
                            : Icons.attach_money_rounded,
                        isNumeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormField(
                      label: 'เริ่มคิดค่าปรับ (วัน)',
                      child: _buildTextField(
                        controller: lateFeeStartDayController,
                        hint: '1',
                        icon: Icons.event,
                        isNumeric: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Max Amount
              _buildFormField(
                label: 'ค่าปรับสูงสุด (ถ้ามี)',
                child: _buildTextField(
                  controller: lateFeeMaxAmountController,
                  hint: 'ไม่กำหนด',
                  icon: Icons.money_off,
                  isNumeric: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.discount,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ส่วนลดชำระก่อนกำหนด',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Switch(
                  value: enableDiscount,
                  onChanged: (value) {
                    setState(() {
                      enableDiscount = value;
                    });
                  },
                  activeColor: const Color(0xff10B981),
                ),
              ],
            ),

            if (enableDiscount) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Discount Percentage and Days
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: 'เปอร์เซ็นต์ส่วนลด',
                      child: _buildTextField(
                        controller: earlyPaymentDiscountController,
                        hint: '0.00',
                        icon: Icons.percent,
                        isNumeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFormField(
                      label: 'ชำระก่อนกำหนด (วัน)',
                      child: _buildTextField(
                        controller: earlyPaymentDaysController,
                        hint: '0',
                        icon: Icons.event_available,
                        isNumeric: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
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
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xff10B981), size: 20),
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
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    lateFeeAmountController.dispose();
    lateFeeStartDayController.dispose();
    lateFeeMaxAmountController.dispose();
    earlyPaymentDiscountController.dispose();
    earlyPaymentDaysController.dispose();
    settingDescController.dispose();
    super.dispose();
  }
}
