import 'package:flutter/material.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../../services/contract_service.dart';

class ContractEditUI extends StatefulWidget {
  final String contractId;

  const ContractEditUI({
    Key? key,
    required this.contractId,
  }) : super(key: key);

  @override
  State<ContractEditUI> createState() => _ContractEditUIState();
}

class _ContractEditUIState extends State<ContractEditUI> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _contract;
  DateTime? _startDate;
  DateTime? _endDate;
  int _paymentDay = 1;
  bool _contractPaid = false;

  final _contractPriceController = TextEditingController();
  final _contractDepositController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contractPriceController.dispose();
    _contractDepositController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contract = await ContractService.getContractById(widget.contractId);

      if (contract != null && mounted) {
        setState(() {
          _contract = contract;
          if (contract['start_date'] != null) {
            _startDate = DateTime.parse(contract['start_date']);
          }
          if (contract['end_date'] != null) {
            _endDate = DateTime.parse(contract['end_date']);
          }
          _paymentDay = (contract['payment_day'] is int)
              ? contract['payment_day'] as int
              : int.tryParse(contract['payment_day']?.toString() ?? '') ?? 1;
          _contractPaid = contract['contract_paid'] ?? false;
          _contractPriceController.text =
              contract['contract_price']?.toString() ?? '';
          _contractDepositController.text =
              contract['contract_deposit']?.toString() ?? '';
          _noteController.text = contract['contract_note'] ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      // Allow historical dates for start date; end date cannot be before start date
      firstDate: isStartDate ? DateTime(2000) : (_startDate ?? DateTime(2000)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: Localizations.localeOf(context),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary, // สีของ header และวันที่เลือก
              onPrimary: Colors.white, // สีของตัวอักษรใน header
              onSurface: Colors.black, // สีของวันที่ในปฏิทิน
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black, // สีของปุ่ม Cancel และ OK
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate == null) {
            _endDate = picked.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _updateContract() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('กรุณาเลือกวันที่เริ่มและสิ้นสุดสัญญา')),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'contract_price': double.tryParse(_contractPriceController.text) ?? 0,
        'contract_deposit':
            double.tryParse(_contractDepositController.text) ?? 0,
        'payment_day': _paymentDay,
        'contract_paid': _contractPaid,
        'contract_note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      };

      final result =
          await ContractService.updateContract(widget.contractId, data);

      if (mounted) {
        setState(() => _isSaving = false);

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text(result['message'])),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text(result['message'])),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
          // Header moved from AppBar to body
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Padding(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'แก้ไขสัญญา',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับแก้ไขข้อมูลสัญญา',
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
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF10B981),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.all(20),
                      children: [
                        // _buildContractInfoCard(),
                        // SizedBox(height: 16),
                        _buildContractEditSection(),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'ข้อมูลสัญญาปัจจุบัน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.assignment,
            label: 'เลขที่สัญญา',
            value: _contract?['contract_num']?.toString() ?? '-',
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.home,
            label: _contract?['roomcate_name']?.toString() ?? 'ประเภทห้อง',
            value: _contract?['room_number']?.toString() ?? '-',
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContractEditSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'รายละเอียดสัญญา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.assignment,
            label: 'เลขที่สัญญา',
            value: '${_contract?['contract_num'] ?? '-'}',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.home,
            label: 'ปรเภท${_contract?['roomcate_name'] ?? '-'}',
            value: 'เลขที่ ${_contract?['room_number'] ?? '-'}',
          ),
          const SizedBox(height: 24),
          // วันที่เริ่มสัญญา
          InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่เริ่มสัญญา',
                prefixIcon: const Icon(Icons.date_range),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xff10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _startDate != null
                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year + 543}'
                    : 'เลือกวันที่',
                style: TextStyle(
                  color: _startDate != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // วันที่สิ้นสุดสัญญา
          InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'วันที่สิ้นสุดสัญญา',
                prefixIcon: const Icon(Icons.event_busy),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xff10B981), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              child: Text(
                _endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year + 543}'
                    : 'เลือกวันที่',
                style: TextStyle(
                  color: _endDate != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ค่าเช่า
          TextFormField(
            controller: _contractPriceController,
            decoration: InputDecoration(
              labelText: 'ค่าเช่า',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกค่าเช่า';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'กรุณากรอกตัวเลขเท่านั้น';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ค่าประกัน
          TextFormField(
            controller: _contractDepositController,
            decoration: InputDecoration(
              labelText: 'ค่าประกัน',
              prefixIcon: const Icon(Icons.security),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกค่าประกัน';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'กรุณากรอกตัวเลขเท่านั้น';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // วันที่ชำระประจำเดือน
          DropdownButtonFormField<int>(
            dropdownColor: Colors.white,
            value: _paymentDay,
            decoration: InputDecoration(
              labelText: 'วันที่ชำระประจำเดือน',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: List.generate(31, (index) => index + 1)
                .map((day) => DropdownMenuItem(
                      value: day,
                      child: Text('วันที่ $day'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _paymentDay = value ?? 1;
              });
            },
          ),
          const SizedBox(height: 16),

          // ชำระค่าประกันแล้ว
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SwitchListTile(
              title: const Text('ชำระค่าประกันแล้ว'),
              subtitle: Text(
                _contractPaid
                    ? 'ผู้เช่าชำระค่าประกันเรียบร้อยแล้ว'
                    : 'ผู้เช่ายังไม่ได้ชำระค่าประกัน',
                style: TextStyle(
                  fontSize: 12,
                  color: _contractPaid
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
              value: _contractPaid,
              onChanged: (value) {
                setState(() {
                  _contractPaid = value;
                });
              },
              activeColor: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // หมายเหตุ
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม',
              prefixIcon: const Icon(Icons.note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff10B981), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool canSave = !_isSaving && !_isLoading;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSave ? _updateContract : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isSaving ? 'กำลังบันทึกการแก้ไข...' : 'บันทึกการแก้ไข',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? AppTheme.primary : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: canSave ? 2 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
