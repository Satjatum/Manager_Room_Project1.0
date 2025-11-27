import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../services/utility_rate_service.dart';
import '../services/branch_service.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class UtilityRatesManagementUi extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const UtilityRatesManagementUi({Key? key, this.branchId, this.branchName})
      : super(key: key);

  @override
  State<UtilityRatesManagementUi> createState() =>
      _UtilityRatesManagementUiState();
}

class _UtilityRatesManagementUiState extends State<UtilityRatesManagementUi> {
  bool isLoading = true;
  List<Map<String, dynamic>> utilityRates = [];
  String? selectedBranchId;
  List<Map<String, dynamic>> branches = [];
  UserModel? currentUser;

  // ตรวจสอบว่ามีน้ำและไฟแบบมิเตอร์ครบทั้งสองแล้วหรือไม่
  bool _hasBothMetered() {
    bool hasWaterMetered = false;
    bool hasElectricMetered = false;

    for (final r in utilityRates) {
      if (r['is_metered'] == true) {
        final name = (r['rate_name'] ?? '').toString().toLowerCase();
        if (name.contains('น้ำ') || name.contains('water')) {
          hasWaterMetered = true;
        }
        if (name.contains('ไฟ') || name.contains('electric')) {
          hasElectricMetered = true;
        }
        if (hasWaterMetered && hasElectricMetered) {
          return true;
        }
      }
    }
    return false;
  }

  // ตรวจสอบว่าชื่อนี้มีแบบมิเตอร์แล้วหรือไม่
  bool _hasMeteredForType(String rateName) {
    final checkName = rateName.toLowerCase();
    for (final r in utilityRates) {
      if (r['is_metered'] == true) {
        final existingName = (r['rate_name'] ?? '').toString().toLowerCase();
        // เช็คว่าเป็นน้ำ
        if ((checkName.contains('น้ำ') || checkName.contains('water')) &&
            (existingName.contains('น้ำ') || existingName.contains('water'))) {
          return true;
        }
        // เช็คว่าเป็นไฟ
        if ((checkName.contains('ไฟ') || checkName.contains('electric')) &&
            (existingName.contains('ไฟ') ||
                existingName.contains('electric'))) {
          return true;
        }
      }
    }
    return false;
  }

  // ตรวจสอบว่าชื่อซ้ำหรือไม่ (ยกเว้นตัวเองถ้าเป็นการแก้ไข)
  bool _isDuplicateName(String rateName, {String? excludeRateId}) {
    final checkName = rateName.trim().toLowerCase();
    for (final r in utilityRates) {
      if (excludeRateId != null && r['rate_id'] == excludeRateId) {
        continue;
      }
      final existingName =
          (r['rate_name'] ?? '').toString().trim().toLowerCase();
      if (existingName == checkName) {
        return true;
      }
    }
    return false;
  }

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
            utilityRates = [];
            selectedBranchId = null;
            isLoading = false;
          });
        }
        return;
      }

      final branchId =
          widget.branchId ?? selectedBranchId ?? branchesData[0]['branch_id'];
      final ratesData = await UtilityRatesService.getUtilityRates(
        branchId: branchId,
      );

      if (mounted) {
        setState(() {
          branches = branchesData;
          utilityRates = ratesData;
          selectedBranchId = branchId;
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

  void _showAddEditDialog({Map<String, dynamic>? rate}) {
    final isEdit = rate != null;
    final nameController =
        TextEditingController(text: rate?['rate_name'] ?? '');
    final priceController =
        TextEditingController(text: rate?['rate_price']?.toString() ?? '0');
    final unitController =
        TextEditingController(text: rate?['rate_unit'] ?? '');
    final fixedController =
        TextEditingController(text: rate?['fixed_amount']?.toString() ?? '0');
    final additionalController = TextEditingController(
        text: rate?['additional_charge']?.toString() ?? '0');

    // ตรวจสอบว่ามีน้ำและไฟแบบมิเตอร์ครบแล้วหรือไม่ (เฉพาะตอนเพิ่มใหม่)
    final hasBothMetered = !isEdit && _hasBothMetered();

    // ถ้ามีน้ำ+ไฟมิเตอร์ครบแล้ว ให้เริ่มต้นด้วยค่าคงที่
    bool isMetered = hasBothMetered ? false : (rate?['is_metered'] ?? true);
    bool isFixed = rate?['is_fixed'] ?? !isMetered;
    bool isActive = rate?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                                isEdit
                                    ? 'แก้ไขอัตราค่าบริการ'
                                    : 'เพิ่มอัตราค่าบริการใหม่',
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
                                    : 'สร้างอัตราค่าบริการใหม่',
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
                      label: 'ชื่ออัตราค่าบริการ *',
                      hint: 'เช่น ค่าไฟฟ้า, ค่าน้ำ',
                      controller: nameController,
                      icon: Icons.label_rounded,
                    ),
                    const SizedBox(height: 20),
                    // แสดงส่วนเลือกประเภทเฉพาะตอนเพิ่มใหม่
                    if (!isEdit) ...[
                      _buildRateTypeSection(
                        isMetered: isMetered,
                        isFixed: isFixed,
                        showMeteredOption: !hasBothMetered,
                        onMeteredChanged: () {
                          setDialogState(() {
                            isMetered = true;
                            isFixed = false;
                          });
                        },
                        onFixedChanged: () {
                          setDialogState(() {
                            isMetered = false;
                            isFixed = true;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (isMetered) ...[
                      _buildFormField(
                        label: 'ราคา/หน่วย *',
                        hint: '0.00',
                        controller: priceController,
                        icon: Icons.attach_money_rounded,
                        isNumeric: true,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        label: 'หน่วย *',
                        hint: 'เช่น kwh, ลบ.ม.',
                        controller: unitController,
                        icon: Icons.straighten_rounded,
                      ),
                    ],
                    if (isFixed) ...[
                      _buildFormField(
                        label: 'จำนวนเงินคงที่ *',
                        hint: '0.00',
                        controller: fixedController,
                        icon: Icons.attach_money_rounded,
                        isNumeric: true,
                      ),
                      const SizedBox(height: 16),
                      _buildFormField(
                        label: 'หน่วย',
                        hint: 'เช่น ต่อเดือน',
                        controller: unitController,
                        icon: Icons.calendar_month_rounded,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
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
                              color: isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isActive
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
                                  isActive
                                      ? 'อัตราค่านี้กำลังใช้งาน'
                                      : 'อัตราค่านี้ปิดการใช้งาน',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (value) {
                              setDialogState(() => isActive = value);
                            },
                            activeColor: AppTheme.primary,
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
                            onPressed: () async {
                              final rateName = nameController.text.trim();

                              if (rateName.isEmpty) {
                                _showErrorSnackBar(
                                    'กรุณากรอกชื่ออัตราค่าบริการ');
                                return;
                              }

                              // ตรวจสอบชื่อซ้ำ
                              if (_isDuplicateName(rateName,
                                  excludeRateId:
                                      isEdit ? rate['rate_id'] : null)) {
                                _showErrorSnackBar(
                                    'ชื่ออัตราค่าบริการนี้มีอยู่แล้ว กรุณาใช้ชื่ออื่น');
                                return;
                              }

                              // ตรวจสอบว่าประเภทนี้มีแบบมิเตอร์แล้วหรือไม่
                              if (isMetered &&
                                  !isEdit &&
                                  _hasMeteredForType(rateName)) {
                                final typeName = rateName
                                            .toLowerCase()
                                            .contains('น้ำ') ||
                                        rateName.toLowerCase().contains('water')
                                    ? 'น้ำ'
                                    : 'ไฟ';
                                _showErrorSnackBar(
                                    'มีค่า$typeNameแบบมิเตอร์อยู่แล้ว ไม่สามารถเพิ่มซ้ำได้');
                                return;
                              }

                              if (isMetered &&
                                  (priceController.text.isEmpty ||
                                      unitController.text.isEmpty)) {
                                _showErrorSnackBar(
                                    'กรุณากรอกราคาและหน่วยสำหรับค่าบริการแบบมิเตอร์');
                                return;
                              }

                              if (isFixed && fixedController.text.isEmpty) {
                                _showErrorSnackBar('กรุณากรอกจำนวนเงินคงที่');
                                return;
                              }

                              try {
                                if (isEdit) {
                                  await UtilityRatesService.updateUtilityRate(
                                    rateId: rate['rate_id'],
                                    rateName: nameController.text,
                                    ratePrice:
                                        double.tryParse(priceController.text) ??
                                            0,
                                    rateUnit: unitController.text,
                                    isMetered: isMetered,
                                    isFixed: isFixed,
                                    fixedAmount:
                                        double.tryParse(fixedController.text) ??
                                            0,
                                    additionalCharge: double.tryParse(
                                            additionalController.text) ??
                                        0,
                                    isActive: isActive,
                                  );
                                } else {
                                  await UtilityRatesService.createUtilityRate(
                                    branchId: selectedBranchId!,
                                    rateName: nameController.text,
                                    ratePrice:
                                        double.tryParse(priceController.text) ??
                                            0,
                                    rateUnit: unitController.text,
                                    isMetered: isMetered,
                                    isFixed: isFixed,
                                    fixedAmount:
                                        double.tryParse(fixedController.text) ??
                                            0,
                                    additionalCharge: double.tryParse(
                                            additionalController.text) ??
                                        0,
                                    isActive: isActive,
                                  );
                                }

                                Navigator.pop(context);
                                _showSuccessSnackBar(isEdit
                                    ? 'แก้ไขอัตราค่าบริการเรียบร้อย'
                                    : 'เพิ่มอัตราค่าบริการเรียบร้อย');
                                _loadData();
                              } catch (e) {
                                _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
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
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isNumeric = false,
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
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : [],
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateTypeSection({
    required bool isMetered,
    required bool isFixed,
    required VoidCallback onMeteredChanged,
    required VoidCallback onFixedChanged,
    bool showMeteredOption = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_rounded,
                  color: Colors.blue.shade700, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'ประเภทอัตราค่าบริการ *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showMeteredOption) ...[
          _buildRateTypeOption(
            title: 'คิดตามมิเตอร์ (Metered)',
            subtitle: 'คิดตามจำนวนที่ใช้จริง',
            isSelected: isMetered,
            onTap: onMeteredChanged,
          ),
          const SizedBox(height: 10),
        ],
        _buildRateTypeOption(
          title: 'ค่าคงที่ (Fixed)',
          subtitle: 'คิดเป็นจำนวนเงินคงที่ทุกเดือน',
          isSelected: isFixed,
          onTap: onFixedChanged,
        ),
      ],
    );
  }

  Widget _buildRateTypeOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isSelected ? AppTheme.primary : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRate(Map<String, dynamic> rate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'ลบอัตราค่าบริการนี้หรือไม่?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Rate Name
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${rate['rate_name']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Warning Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ข้อมูลทั้งหมดจะถูกลบอย่างถาวร และจะส่งผลต่อการคำนวณบิลในอนาคต',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 8),
                          Text(
                            'ลบ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: Colors.red.shade600,
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Loading Text
                  const Text(
                    'กำลังลบอัตราค่าบริการ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await UtilityRatesService.deleteUtilityRate(rate['rate_id']);
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          _showSuccessSnackBar('ลบอัตราค่าบริการเรียบร้อย');
          _loadData();
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
        }
      }
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
      backgroundColor: Colors.white,
      floatingActionButton: selectedBranchId != null
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              backgroundColor: const Color(0xff10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff10B981),
                  strokeWidth: 3,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                'ตั้งค่าค่าบริการ',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'สำหรับจัดการค่าบริการ',
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
                  ),
                  Expanded(
                    child: utilityRates.isEmpty
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
                                    Icons.receipt_long_rounded,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ยังไม่มีอัตราค่าบริการ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'แตะ "เพิ่มอัตรา" เพื่อสร้างรายการแรก',
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
                            itemCount: utilityRates.length,
                            itemBuilder: (context, index) {
                              final item = utilityRates[index];
                              final name = item['rate_name'] ?? '-';
                              final unit = item['rate_unit'] ?? '';
                              final price = item['rate_price'] ?? 0;
                              final fixedAmount = item['fixed_amount'] ?? 0;
                              final isMetered = item['is_metered'] ?? true;

                              final utilityIcon = _getUtilityIcon(item);
                              final utilityColor = _getUtilityColor(item);

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
                                  onTap: () => _showAddEditDialog(rate: item),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // ไอคอนด้านซ้าย
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color:
                                                utilityColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            utilityIcon,
                                            color: utilityColor,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // ข้อมูลตรงกลาง
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // ชื่อและสถานะ
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // ราคา
                                              Text(
                                                isMetered
                                                    ? '${price.toStringAsFixed(2)} บาท/$unit'
                                                    : '${fixedAmount.toStringAsFixed(2)} บาท',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: utilityColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // สถานะการใช้งาน
                                            ],
                                          ),
                                        ),
                                        // เมนูจัดการ
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
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_rounded,
                                                      color: AppTheme.primary,
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  const Text('แก้ไข'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'ลบ',
                                                    style: TextStyle(
                                                        color: Colors.red),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showAddEditDialog(rate: item);
                                            } else if (value == 'delete') {
                                              _deleteRate(item);
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
                ],
              ),
      ),
    );
  }

  // ฟังก์ชันสำหรับเลือกไอคอนตามประเภท utility
  IconData _getUtilityIcon(Map<String, dynamic> item) {
    final name = (item['rate_name'] ?? '').toString().toLowerCase();
    final isFixed = item['is_fixed'] ?? false;

    // ถ้าเป็นค่าคงที่ ให้ใช้ไอคอนเงิน
    if (isFixed) {
      return Icons.attach_money_rounded;
    }

    // ตรวจสอบจากชื่อ
    if (name.contains('น้ำ') || name.contains('water')) {
      return Icons.water_drop_rounded;
    } else if (name.contains('ไฟ') || name.contains('electric')) {
      return Icons.bolt_rounded;
    }

    // default
    return Icons.receipt_long_rounded;
  }

  // ฟังก์ชันสำหรับเลือกสีตามประเภท utility
  Color _getUtilityColor(Map<String, dynamic> item) {
    final name = (item['rate_name'] ?? '').toString().toLowerCase();
    final isFixed = item['is_fixed'] ?? false;

    // ถ้าเป็นค่าคงที่ ให้ใช้สีม่วง
    if (isFixed) {
      return Colors.purple;
    }

    // ตรวจสอบจากชื่อ
    if (name.contains('น้ำ') || name.contains('water')) {
      return Colors.blue;
    } else if (name.contains('ไฟ') || name.contains('electric')) {
      return Colors.orange;
    }

    // default
    return Colors.grey;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
