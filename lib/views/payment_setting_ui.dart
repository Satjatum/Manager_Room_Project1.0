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
  String discountType = 'percentage';
  final TextEditingController earlyPaymentDiscountController =
      TextEditingController();
  final TextEditingController earlyPaymentDaysController =
      TextEditingController();
  final TextEditingController earlyPaymentAmountController =
      TextEditingController();

  final TextEditingController settingDescController = TextEditingController();
  bool isActive = true;
  // PromptPay Test Mode flag (global via branches.branch_desc)
  bool enablePromptPayTestMode = false;

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

      // Load PromptPay test mode from branch JSON (global effect)
      final initBranchId = widget.branchId ?? selectedBranchId;
      if (initBranchId != null) {
        enablePromptPayTestMode = await BranchService.getPromptPayTestMode(initBranchId);
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
            discountType = settings['early_payment_type'] ?? 'percentage';
            earlyPaymentDiscountController.text =
                settings['early_payment_discount']?.toString() ?? '0.00';
            earlyPaymentDaysController.text =
                settings['early_payment_days']?.toString() ?? '0';
            earlyPaymentAmountController.text =
                settings['early_payment_amount']?.toString() ?? '0.00';

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
      if (earlyPaymentDaysController.text.isEmpty) {
        _showError('กรุณากรอกจำนวนวันก่อนกำหนดชำระ');
        return;
      }
      final days = int.tryParse(earlyPaymentDaysController.text) ?? 0;
      if (days <= 0) {
        _showError('จำนวนวันต้องมากกว่า 0');
        return;
      }
      if (discountType == 'percentage') {
        if (earlyPaymentDiscountController.text.isEmpty) {
          _showError('กรุณากรอกเปอร์เซ็นต์ส่วนลด');
          return;
        }
        final discount =
            double.tryParse(earlyPaymentDiscountController.text) ?? 0;
        if (discount <= 0 || discount > 100) {
          _showError('เปอร์เซ็นต์ส่วนลดต้องอยู่ระหว่าง 0-100');
          return;
        }
      } else {
        if (earlyPaymentAmountController.text.isEmpty) {
          _showError('กรุณากรอกจำนวนเงินส่วนลด');
          return;
        }
        final amt = double.tryParse(earlyPaymentAmountController.text) ?? 0;
        if (amt <= 0) {
          _showError('จำนวนเงินส่วนลดต้องมากกว่า 0');
          return;
        }
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
        earlyPaymentType: enableDiscount ? discountType : null,
        earlyPaymentAmount: enableDiscount
            ? double.tryParse(earlyPaymentAmountController.text) ?? 0
            : null,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff10B981),
                  strokeWidth: 3,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header Section (white header like sample)
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
                            children: const [
                              Text(
                                'ตั้งค่าการชำระเงิน',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'กำหนดนโยบายค่าปรับล่าช้าและส่วนลดตามสาขา',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status row removed per request

                    // Branch Selector (if not fixed by route)
                    if (widget.branchId == null && branches.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
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

                    const SizedBox(height: 16),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLateFeeCard(),
                            const SizedBox(height: 16),
                            _buildDiscountCard(),
                            const SizedBox(height: 16),
                            // Toggle visible for Admin & SuperAdmin
                            if (currentUser != null && (currentUser!.userRole == UserRole.admin || currentUser!.userRole == UserRole.superAdmin))
                              _buildPromptPayTestModeCard(),
                            const SizedBox(height: 24),
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
      ),
    );
  }

  Widget _buildPromptPayTestModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_rounded, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'โหมดทดสอบ PromptPay',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Switch(
                  value: enablePromptPayTestMode,
                  onChanged: (v) async {
                    if (selectedBranchId == null) return;
                    final res = await BranchService.setPromptPayTestMode(
                      branchId: selectedBranchId!,
                      enabled: v,
                    );
                    if (!mounted) return;
                    if (res['success'] == true) {
                      setState(() => enablePromptPayTestMode = v);
                      _showSuccessSnackBar(res['message'] ?? 'อัปเดตโหมดทดสอบเรียบร้อย');
                    } else {
                      _showError(res['message'] ?? 'ไม่สามารถอัปเดตโหมดทดสอบได้');
                    }
                  },
                  activeColor: const Color(0xff10B981),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'สำหรับผู้ดูแลเท่านั้น • จะมีปุ่ม "ทดสอบโอนสำเร็จ" บนหน้าชำระด้วย PromptPay เพื่อจำลองการชำระเงินและตัดบิลทันที',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700, size: 22),
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
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 16),

              // Late Fee Type
              _buildFormField(
                label: 'ประเภทค่าปรับ',
                child: DropdownButtonFormField<String>(
                  value: lateFeeType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xff10B981), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                        onChanged: (_) => setState(() {}),
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
                        onChanged: (_) => setState(() {}),
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
              const SizedBox(height: 16),
              _buildLateFeeExampleBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.discount, color: Colors.green.shade700, size: 22),
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
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 16),

              // Discount Type
              _buildFormField(
                label: 'ประเภทส่วนลด',
                child: DropdownButtonFormField<String>(
                  value: discountType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xff10B981), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('เปอร์เซ็นต์')),
                    DropdownMenuItem(value: 'fixed', child: Text('จำนวนเงิน')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      discountType = v;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Discount Amount/Percent and Days
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: discountType == 'fixed' ? 'จำนวนเงินส่วนลด' : 'เปอร์เซ็นต์ส่วนลด',
                      child: _buildTextField(
                        controller: discountType == 'fixed'
                            ? earlyPaymentAmountController
                            : earlyPaymentDiscountController,
                        hint: '0.00',
                        icon: discountType == 'fixed' ? Icons.attach_money : Icons.percent,
                        isNumeric: true,
                        onChanged: (_) => setState(() {}),
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
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildDiscountExampleBox(),
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
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [],
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade700, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // Status row removed per request

  Widget _buildLateFeeExampleBox() {
    final examples = PaymentSettingsService.generateExample(
      enableLateFee: enableLateFee,
      lateFeeType: lateFeeType,
      lateFeeAmount: double.tryParse(lateFeeAmountController.text),
      lateFeeStartDay: int.tryParse(lateFeeStartDayController.text),
      enableDiscount: false,
    );
    final text = examples['late_fee'];
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountExampleBox() {
    final examples = PaymentSettingsService.generateExample(
      enableLateFee: false,
      enableDiscount: enableDiscount,
      earlyPaymentType: discountType,
      earlyPaymentAmount:
          double.tryParse(earlyPaymentAmountController.text),
      earlyPaymentDiscount:
          double.tryParse(earlyPaymentDiscountController.text),
      earlyPaymentDays: int.tryParse(earlyPaymentDaysController.text),
    );
    final text = examples['discount'];
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
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
    earlyPaymentAmountController.dispose();
    settingDescController.dispose();
    super.dispose();
  }
}
