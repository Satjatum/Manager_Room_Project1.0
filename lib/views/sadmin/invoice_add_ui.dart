import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Services //
import '../../services/invoice_service.dart';
import '../../services/room_service.dart';
import '../../services/contract_service.dart';
import '../../services/utility_rate_service.dart';
import '../../services/meter_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_rate_service.dart';
// Models //
import '../../models/user_models.dart';
// Widgets //
import '../widgets/colors.dart';
// Utils //
import '../../utils/formatMonthy.dart';
import '../widgets/snack_message.dart';

class InvoiceAddPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const InvoiceAddPage({Key? key, this.initialData}) : super(key: key);

  @override
  State<InvoiceAddPage> createState() => _InvoiceAddPageState();
}

class _InvoiceAddPageState extends State<InvoiceAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _discountReasonController = TextEditingController();
  final _lateFeeAmountController = TextEditingController();
  final _lateFeeReasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _waterCurrentController = TextEditingController();
  final _electricCurrentController = TextEditingController();

  // Data
  UserModel? _currentUser;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _fixedRates = [];
  List<Map<String, dynamic>> _selectedFixedRates = [];
  Map<String, dynamic>? _paymentSettings;

  // Form data
  String? _selectedBranchId;
  String? _selectedRoomId;
  String? _selectedTenantId;
  String? _selectedContractId;
  String? _readingId;
  String? _waterRateId;
  String? _electricRateId;
  int _invoiceMonth = DateTime.now().month;
  int _invoiceYear = DateTime.now().year;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  // Financial data
  double _rentalAmount = 0.0;
  double _utilitiesAmount = 0.0;
  double _otherCharges = 0.0;
  double _lateFeeAmount = 0.0;

  // Water and Electric meter data
  double _waterPreviousReading = 0.0;
  double _waterCurrentReading = 0.0;
  double _waterUsage = 0.0;
  double _waterRate = 0.0;
  double _waterCost = 0.0;

  double _electricPreviousReading = 0.0;
  double _electricCurrentReading = 0.0;
  double _electricUsage = 0.0;
  double _electricRate = 0.0;
  double _electricCost = 0.0;

  // UI State
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isFromMeterReading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _discountReasonController.dispose();
    _lateFeeAmountController.dispose();
    _lateFeeReasonController.dispose();
    _notesController.dispose();
    _waterCurrentController.dispose();
    _electricCurrentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. โหลด user ก่อน
      _currentUser = await AuthService.getCurrentUser();

      if (_currentUser == null) {
        debugPrint('กรุณาเข้าสู่ระบบใหม่');
        SnackMessage.showError(context, 'กรุณาเข้าสู่ระบบใหม่');
        setState(() => _isLoading = false);
        return;
      }

      // 2. ตรวจสอบ initialData และ set ค่าพื้นฐาน
      if (widget.initialData != null) {
        _isFromMeterReading = widget.initialData!['reading_id'] != null;
        _selectedBranchId = widget.initialData!['branch_id'];
        _selectedRoomId = widget.initialData!['room_id'];
        _selectedTenantId = widget.initialData!['tenant_id'];
        _selectedContractId = widget.initialData!['contract_id'];
        _readingId = widget.initialData!['reading_id'];
        _invoiceMonth =
            widget.initialData!['invoice_month'] ?? DateTime.now().month;
        _invoiceYear =
            widget.initialData!['invoice_year'] ?? DateTime.now().year;

        debugPrint(
            'ข้อมูลเริ่มต้น: สาขา=$_selectedBranchId, ห้อง=$_selectedRoomId, มิเตอร์=$_readingId');
      }

      // 3. โหลด branches
      try {
        _branches = await RoomService.getBranchesForRoomFilter();
        debugPrint('โหลดสาขาแล้ว ${_branches.length} สาขา');
      } catch (e) {
        debugPrint('ไม่สามารถโหลดข้อมูลสาขาได้: $e');
        SnackMessage.showError(context, 'ไม่สามารถโหลดข้อมูลสาขาได้');
      }

      // 4. ถ้ามี branch_id ให้โหลดข้อมูลที่เกี่ยวข้อง
      if (_selectedBranchId != null) {
        await _loadDataForBranch();
      }

      setState(() {});
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันใหม่: โหลดข้อมูลเมื่อมี branch_id
  Future<void> _loadDataForBranch() async {
    try {
      final results = await Future.wait([
        RoomService.getAllRooms(branchId: _selectedBranchId),
        UtilityRatesService.getActiveRatesForBranch(_selectedBranchId!),
        PaymentSettingsService.getActivePaymentSettings(_selectedBranchId!),
        if (_readingId != null)
          MeterReadingService.getMeterReadingById(_readingId!),
      ]);

      _rooms = results[0] as List<Map<String, dynamic>>;
      final utilityRates = results[1] as List<Map<String, dynamic>>;
      _paymentSettings = results[2] as Map<String, dynamic>?;

      // แยกค่า rates ออกเป็น metered และ fixed
      _fixedRates =
          utilityRates.where((rate) => rate['is_fixed'] == true).toList();

      // ✅ เก็บ rate_id สำหรับน้ำและไฟ
      String? waterRateId;
      String? electricRateId;

      for (var rate in utilityRates) {
        if (rate['is_metered'] == true) {
          final rateName = rate['rate_name'].toString().toLowerCase();
          if (rateName.contains('น้ำ') || rateName.contains('water')) {
            _waterRate = (rate['rate_price'] ?? 0.0).toDouble();
            waterRateId = rate['rate_id'];
          }
          if (rateName.contains('ไฟ') || rateName.contains('electric')) {
            _electricRate = (rate['rate_price'] ?? 0.0).toDouble();
            electricRateId = rate['rate_id'];
          }
        }
      }

      // ✅ เก็บ rate_id เป็น instance variable
      _waterRateId = waterRateId;
      _electricRateId = electricRateId;

      // ✅ Apply meter reading data ถ้ามี
      if (_readingId != null && results.length > 3) {
        final reading = results[3] as Map<String, dynamic>?;
        if (reading != null) {
          _applyMeterReadingData(reading);
        }
      }

      // ✅ โหลด contracts สำหรับห้องที่เลือก
      if (_selectedRoomId != null) {
        await _loadContractsForRoom();
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      SnackMessage.showError(context, 'ข้อผิดพลาดในการโหลดข้อมูลสาขา');
    }
  }

  void _addFixedRate(Map<String, dynamic> rate) {
    setState(() {
      _selectedFixedRates.add({
        'rate_id': rate['rate_id'],
        'rate_name': rate['rate_name'],
        'fixed_amount': rate['fixed_amount'],
        'additional_charge': rate['additional_charge'] ?? 0.0,
        'quantity': 1,
      });
      _calculateOtherChargesTotal();
    });
  }

  void _removeFixedRate(int index) {
    setState(() {
      _selectedFixedRates.removeAt(index);
      _calculateOtherChargesTotal();
    });
  }

  void _calculateOtherChargesTotal() {
    double total = 0.0;
    for (var rate in _selectedFixedRates) {
      final unit = (rate['fixed_amount'] ?? 0.0).toDouble() +
          (rate['additional_charge'] ?? 0.0).toDouble();
      final qty = (rate['quantity'] ?? 1) as int;
      total += unit * (qty <= 0 ? 1 : qty);
    }
    _otherCharges = total;
  }

  // ฟังก์ชันใหม่: Apply ข้อมูลจาก meter reading
  void _applyMeterReadingData(Map<String, dynamic> reading) {
    _waterPreviousReading =
        (reading['water_previous_reading'] ?? 0.0).toDouble();
    _waterCurrentReading = (reading['water_current_reading'] ?? 0.0).toDouble();
    _waterUsage = (reading['water_usage'] ?? 0.0).toDouble();

    _electricPreviousReading =
        (reading['electric_previous_reading'] ?? 0.0).toDouble();
    _electricCurrentReading =
        (reading['electric_current_reading'] ?? 0.0).toDouble();
    _electricUsage = (reading['electric_usage'] ?? 0.0).toDouble();

    _waterCurrentController.text = _waterCurrentReading.toStringAsFixed(0);
    _electricCurrentController.text =
        _electricCurrentReading.toStringAsFixed(0);

    // คำนวณเฉพาะตามมิเตอร์ (ไม่รวมค่าบริการพื้นฐาน)
    _waterCost = (_waterUsage * _waterRate);
    _electricCost = (_electricUsage * _electricRate);

    _calculateUtilitiesTotal();
    debugPrint('ใช้ข้อมูลมิเตอร์: น้ำ=$_waterUsage, ไฟ=$_electricUsage');
  }

  // ⭐ ฟังก์ชันใหม่: โหลด contracts สำหรับห้อง พร้อมดึงค่าเช่า
  Future<void> _loadContractsForRoom() async {
    try {
      _contracts = await ContractService.getContractsByRoom(_selectedRoomId!);

      debugPrint('โหลดสัญญาเช่าแล้ว ${_contracts.length} สัญญา');
      if (_contracts.isNotEmpty) {
        if (_selectedContractId == null) {
          // เลือก contract ที่ active
          final activeContracts = _contracts
              .where((c) => c['contract_status'] == 'active')
              .toList();

          final selectedContract = activeContracts.isNotEmpty
              ? activeContracts.first
              : _contracts.first;

          _selectedContractId = selectedContract['contract_id'];
          _selectedTenantId = selectedContract['tenant_id'];

          // ⭐ ดึงค่าเช่าจาก contract
          _rentalAmount =
              (selectedContract['contract_price'] ?? 0.0).toDouble();
          debugPrint('เลือกสัญญา: $_selectedContractId, เช่า: $_rentalAmount');
        } else {
          // ⭐ ถ้ามี contract_id แล้ว ให้ดึงค่าเช่าจาก contract ที่เลือก
          final selectedContract = _contracts.firstWhere(
            (c) => c['contract_id'] == _selectedContractId,
            orElse: () => {},
          );
          if (selectedContract.isNotEmpty) {
            _rentalAmount =
                (selectedContract['contract_price'] ?? 0.0).toDouble();
            debugPrint('ค่าเช่าจากสัญญา: $_rentalAmount');
          }
        }
      }

      // ถ้าไม่ได้มาจาก meter reading ให้โหลด previous readings
      if (!_isFromMeterReading && _selectedRoomId != null) {
        final suggestions =
            await MeterReadingService.getSuggestedPreviousReadings(
                _selectedRoomId!);
        if (suggestions != null) {
          _waterPreviousReading = suggestions['water_previous'] ?? 0.0;
          _electricPreviousReading = suggestions['electric_previous'] ?? 0.0;
          debugPrint(
              ' ค่าก่อนหน้าที่แนะนำ: น้ำ=$_waterPreviousReading, ไฟ=$_electricPreviousReading');
        }
      }
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดสัญญา: $e');
    }
  }

  Future<void> _loadContractData() async {
    if (_selectedRoomId == null) return;

    try {
      _contracts = await ContractService.getContractsByRoom(_selectedRoomId!);

      if (_contracts.isNotEmpty && _selectedContractId == null) {
        final activeContracts =
            _contracts.where((c) => c['contract_status'] == 'active').toList();

        final selectedContract = activeContracts.isNotEmpty
            ? activeContracts.first
            : _contracts.first;

        _selectedContractId = selectedContract['contract_id'];
        _selectedTenantId = selectedContract['tenant_id'];

        // ⭐ ดึงค่าเช่า
        _rentalAmount = (selectedContract['contract_price'] ?? 0.0).toDouble();
      } else if (_selectedContractId != null) {
        final contract = _contracts.firstWhere(
          (c) => c['contract_id'] == _selectedContractId,
          orElse: () => {},
        );
        if (contract.isNotEmpty) {
          // ⭐ ดึงค่าเช่า
          _rentalAmount = (contract['contract_price'] ?? 0.0).toDouble();
        }
      }

      if (!_isFromMeterReading) {
        final suggestions =
            await MeterReadingService.getSuggestedPreviousReadings(
                _selectedRoomId!);
        if (suggestions != null) {
          _waterPreviousReading = suggestions['water_previous'] ?? 0.0;
          _electricPreviousReading = suggestions['electric_previous'] ?? 0.0;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('ข้อผิดพลาดในการโหลดข้อมูลสัญญา: $e');
    }
  }

  void _calculateUtilitiesTotal() {
    _utilitiesAmount = _waterCost + _electricCost;
  }

  double _calculateBaseTotal() {
    return _rentalAmount + _utilitiesAmount + _otherCharges;
  }

  // ⭐ ฟังก์ชันใหม่: คำนวดยอดรวมพร้อมใช้ payment settings
  double _calculateGrandTotal() {
    final baseTotal = _calculateBaseTotal();

    // ปิดการคิดค่าปรับล่าช้าอัตโนมัติระหว่างสร้างบิล
    _lateFeeAmount = 0.0;
    _lateFeeAmountController.text = '0.00';

    return baseTotal + _lateFeeAmount;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedBranchId == null) {
          debugPrint('กรุณาเลือกสาขา');
          SnackMessage.showError(context, 'กรุณาเลือกสาขา');

          return false;
        }
        if (_selectedRoomId == null) {
          debugPrint('กรุณาเลือกห้อง');
          SnackMessage.showError(context, 'กรุณาเลือกห้อง');

          return false;
        }
        if (_selectedContractId == null) {
          debugPrint('กรุณาเลือกสัญญาเช่า');
          SnackMessage.showError(context, 'กรุณาเลือกสัญญาเช่า');

          return false;
        }
        // ⭐ ตรวจสอบค่าเช่า
        if (_rentalAmount <= 0) {
          debugPrint('ไม่พบค่าเช่าจากสัญญา กรุณาตรวจสอบข้อมูล');
          SnackMessage.showError(
              context, 'ไม่พบค่าเช่าจากสัญญา กรุณาตรวจสอบข้อมูล');

          return false;
        }
        return true;
      case 1:
        if (_waterCurrentReading < _waterPreviousReading) {
          debugPrint('ค่ามิเตอร์น้ำปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');
          SnackMessage.showError(context,
              'ค่ามิเตอร์น้ำปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');

          return false;
        }
        if (_electricCurrentReading < _electricPreviousReading) {
          debugPrint('ค่ามิเตอร์ไฟปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');
          SnackMessage.showError(
              context, 'ค่ามิเตอร์ไฟปัจจุบันต้องมากกว่าหรือเท่ากับค่าก่อนหน้า');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final invoiceData = {
        'room_id': _selectedRoomId,
        'tenant_id': _selectedTenantId,
        'contract_id': _selectedContractId,
        'meter_reading_id': _readingId,
        'invoice_month': _invoiceMonth,
        'invoice_year': _invoiceYear,
        'invoice_date': DateTime.now()
            .toIso8601String()
            .split('T')[0], // ส่งไปเพื่อให้ service รู้
        'due_date': _dueDate.toIso8601String().split('T')[0],

        // ✅ ค่าเช่า
        'room_rent': _rentalAmount,

        // ✅ รายละเอียดค่าน้ำ
        'water_usage': _waterUsage,
        'water_rate': _waterRate,
        'water_cost': _waterCost,
        'water_rate_id': _waterRateId,
        // ✅ รายละเอียดค่าไฟ
        'electric_usage': _electricUsage,
        'electric_rate': _electricRate,
        'electric_cost': _electricCost,
        'electric_rate_id': _electricRateId,

        // ✅ ค่าใช้จ่ายอื่นๆ
        'other_expenses': _otherCharges,

        // ✅ รายการค่าบริการคงที่
        'fixed_rates': _selectedFixedRates,

        // ✅ หมายเหตุ
        'notes': _notesController.text,
      };

      final result = await InvoiceService.createInvoice(invoiceData);

      if (result['success']) {
        if (mounted) {
          debugPrint("สร้างใบแจ้งหนี้สำเร็จ");
          SnackMessage.showSuccess(context, 'สร้างใบแจ้งหนี้สำเร็จ');
          Navigator.pop(context, {'success': true});
        }
      } else {
        debugPrint("เกิดข้อผิดพลาด ${result['message']}");
        SnackMessage.showSuccess(
            context, result['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาด: $e');
      SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 24,
                      right: 24,
                      left: 24,
                    ),
                    child: Row(
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
                                'ออกบิลค่าเช่า',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'สำหรับออกบิลค่าเช่า',
                                style: const TextStyle(
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
                  const SizedBox(height: 16),
                  _buildProgressIndicator(),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildBasicInfoStep(),
                          _buildUtilitiesStep(),
                          _buildChargesDiscountsStep(),
                          _buildSummaryStep(),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
      ),
    );
  }

  Widget _buildOtherChargesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ค่าใช้จ่ายอื่นๆ (ค่าคงที่)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_fixedRates.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _showAddFixedRateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มค่าบริการ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // แสดงรายการค่าคงที่ที่เลือก
        if (_selectedFixedRates.isEmpty)
          // เมื่อยังไม่มีการเลือกค่าบริการ ให้แสดงกล่องพื้นหลังสีขาว
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  // ไอคอนใช้สีตามธีมหลัก
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _fixedRates.isEmpty
                        ? 'ไม่มีค่าบริการคงที่ในระบบ'
                        : 'ยังไม่มีการเลือกค่าบริการ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              ...List.generate(_selectedFixedRates.length, (index) {
                final rate = _selectedFixedRates[index];
                final fixedAmount = (rate['fixed_amount'] ?? 0.0).toDouble();
                final additionalCharge =
                    (rate['additional_charge'] ?? 0.0).toDouble();
                final unit = fixedAmount + additionalCharge;
                final qty = (rate['quantity'] ?? 1) as int;
                final lineTotal = unit * (qty <= 0 ? 1 : qty);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  // ปรับพื้นหลังของการ์ดเป็นสีขาว
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // ไอคอน
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconForRate(rate['rate_name']),
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ข้อมูล
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rate['rate_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'หน่วยละ: ${unit.toStringAsFixed(2)} บาท',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (additionalCharge > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${additionalCharge.toStringAsFixed(2)} เพิ่มเติม',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ตัวควบคุมจำนวน + ราคารวม
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'ลดจำนวน',
                                  onPressed: () {
                                    setState(() {
                                      final current =
                                          (rate['quantity'] ?? 1) as int;
                                      final next =
                                          (current - 1) < 1 ? 1 : (current - 1);
                                      rate['quantity'] = next;
                                      _calculateOtherChargesTotal();
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: AppTheme.primary,
                                ),
                                // จำนวน
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color:
                                            AppTheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'x $qty',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'เพิ่มจำนวน',
                                  onPressed: () {
                                    setState(() {
                                      final current =
                                          (rate['quantity'] ?? 1) as int;
                                      rate['quantity'] = current + 1;
                                      _calculateOtherChargesTotal();
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${unit.toStringAsFixed(2)} × $qty = ${lineTotal.toStringAsFixed(2)} บาท',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),

                        // ปุ่มลบ
                        IconButton(
                          onPressed: () => _removeFixedRate(index),
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.red,
                          tooltip: 'ลบ',
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),

              // แสดงยอดรวม
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'รวมค่าใช้จ่ายอื่นๆ:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_otherCharges.toStringAsFixed(2)} บาท',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _showAddFixedRateDialog() {
    // กรองค่าบริการที่ยังไม่ได้เลือก
    final availableRates = _fixedRates.where((rate) {
      return !_selectedFixedRates.any(
        (selected) => selected['rate_id'] == rate['rate_id'],
      );
    }).toList();

    if (availableRates.isEmpty) {
      debugPrint('เพิ่มค่าบริการครบแล้ว');
      SnackMessage.showError(context, 'เพิ่มค่าบริการครบแล้ว');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_circle_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เลือกค่าบริการ',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableRates.length,
            itemBuilder: (context, index) {
              final rate = availableRates[index];
              final fixedAmount = (rate['fixed_amount'] ?? 0.0).toDouble();
              final additionalCharge =
                  (rate['additional_charge'] ?? 0.0).toDouble();
              final total = fixedAmount + additionalCharge;

              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getIconForRate(rate['rate_name']),
                      color: AppTheme.primary,
                    ),
                  ),
                  title: Text(
                    rate['rate_name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('ค่าคงที่: ${fixedAmount.toStringAsFixed(2)} บาท'),
                      if (additionalCharge > 0)
                        Text(
                          'ค่าเพิ่มเติม: ${additionalCharge.toStringAsFixed(2)} บาท',
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Text(
                        'บาท',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _addFixedRate(rate);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
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
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForRate(String rateName) {
    final name = rateName.toLowerCase();
    if (name.contains('ไฟ') || name.contains('electric')) {
      return Icons.electric_bolt;
    }
    if (name.contains('น้ำ') || name.contains('water')) {
      return Icons.water_drop;
    }
    if (name.contains('ส่วนกลาง') || name.contains('common')) {
      return Icons.apartment;
    }
    if (name.contains('อินเทอร์เน็ต') ||
        name.contains('เน็ต') ||
        name.contains('internet') ||
        name.contains('wifi')) {
      return Icons.wifi;
    }
    if (name.contains('ขยะ') || name.contains('trash')) {
      return Icons.delete_outline;
    }
    if (name.contains('ที่จอดรถ') || name.contains('parking')) {
      return Icons.local_parking;
    }
    if (name.contains('รักษาความปลอดภัย') || name.contains('security')) {
      return Icons.security;
    }
    return Icons.receipt_long;
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive || isCompleted
                          ? AppTheme.primary
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(index),
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? Colors.black
                          : Colors.grey[600],
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'ข้อมูลพื้นฐาน';
      case 1:
        return 'ค่าบริการ';
      case 2:
        return 'ค่าใช้จ่าย';
      case 3:
        return 'สรุป';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลพื้นฐาน',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRoomId,
            decoration: InputDecoration(
              labelText: 'เลือกห้อง *',
              border: const OutlineInputBorder(),
              enabled: !_isFromMeterReading && _rooms.isNotEmpty,
            ),
            items: _rooms.map((room) {
              return DropdownMenuItem<String>(
                value: room['room_id'] as String,
                child: Text('ห้อง ${room['room_number']}'),
              );
            }).toList(),
            onChanged: _isFromMeterReading
                ? null
                : (value) {
                    setState(() {
                      _selectedRoomId = value;
                      _selectedContractId = null;
                      _selectedTenantId = null;
                      _contracts.clear();
                      _rentalAmount = 0.0;
                    });
                    _loadContractData();
                  },
            validator: (value) => value == null ? 'กรุณาเลือกห้อง' : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedContractId,
            decoration: InputDecoration(
              labelText: 'เลือกสัญญาเช่า *',
              border: const OutlineInputBorder(),
              enabled: !_isFromMeterReading && _contracts.isNotEmpty,
            ),
            isExpanded: true,
            isDense: false,
            menuMaxHeight: 300,
            items: _contracts.map((contract) {
              return DropdownMenuItem<String>(
                value: contract['contract_id'] as String,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${contract['contract_num']}'),
                    // Text(
                    //   '${contract['tenant_name']} - ${contract['contract_price']} บาท',
                    //   style: const TextStyle(fontSize: 12, color: Colors.grey),
                    // ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isFromMeterReading
                ? null
                : (value) {
                    setState(() {
                      _selectedContractId = value;
                      final contract = _contracts
                          .firstWhere((c) => c['contract_id'] == value);
                      _selectedTenantId = contract['tenant_id'];
                      // ⭐ อัปเดตค่าเช่า
                      _rentalAmount =
                          (contract['contract_price'] ?? 0.0).toDouble();

                      debugPrint(' อัปเดตค่าเช่า: $_rentalAmount');
                    });
                  },
            validator: (value) => value == null ? 'กรุณาเลือกสัญญาเช่า' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _invoiceMonth,
                  decoration: InputDecoration(
                    labelText: 'เดือน *',
                    border: const OutlineInputBorder(),
                    enabled: !_isFromMeterReading,
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem<int>(
                      value: month,
                      child: Text(Formatmonthy.monthName(month)),
                    );
                  }),
                  onChanged: _isFromMeterReading
                      ? null
                      : (value) {
                          setState(() => _invoiceMonth = value!);
                        },
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกเดือน' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _invoiceYear,
                  decoration: InputDecoration(
                    labelText: 'ปี *',
                    border: const OutlineInputBorder(),
                    enabled: !_isFromMeterReading,
                  ),
                  items: List.generate(5, (index) {
                    // ปรับให้แสดงปีเป็น พ.ศ. แต่ค่าที่ส่งกลับยังคงเป็นปี ค.ศ. เพื่อใช้ในระบบภายใน
                    final gregorianYear = DateTime.now().year - 2 + index;
                    final thaiYear = gregorianYear + 543;
                    return DropdownMenuItem<int>(
                      value: gregorianYear,
                      child: Text('$thaiYear'),
                    );
                  }),
                  onChanged: _isFromMeterReading
                      ? null
                      : (value) {
                          setState(() => _invoiceYear = value!);
                        },
                  validator: (value) => value == null ? 'กรุณาเลือกปี' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            decoration: InputDecoration(
              labelText: 'วันครบกำหนดชำระ',
              prefixIcon: const Icon(
                Icons.calendar_today,
              ),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xff10B981),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            readOnly: true,
            controller: TextEditingController(
                text: Formatmonthy.formatThaiDate(_dueDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                // ปรับธีมของ date picker ให้เป็นพื้นหลังสีขาวและใช้สีหลักของแอป
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppTheme.primary,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _dueDate = date);
              }
            },
          ),
          const SizedBox(height: 16),

          // ⭐ แสดงข้อมูลสรุปเมื่อเลือกสัญญาแล้ว
          if (_selectedRoomId != null && _selectedContractId != null)
            _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildUtilitiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ค่าบริการ (มิเตอร์)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isFromMeterReading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'จากมิเตอร์',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUtilitySection(
            title: 'ค่าน้ำ',
            icon: Icons.water_drop,
            color: Colors.blue,
            previousReading: _waterPreviousReading,
            currentReading: _waterCurrentReading,
            usage: _waterUsage,
            rate: _waterRate,
            baseCharge: 0.0,
            cost: _waterCost,
            controller: _waterCurrentController,
            isReadOnly: _isFromMeterReading,
            onCurrentReadingChanged: (value) {
              setState(() {
                _waterCurrentReading = double.tryParse(value) ?? 0.0;
                _waterUsage = _waterCurrentReading - _waterPreviousReading;
                _waterCost = (_waterUsage * _waterRate);
                _calculateUtilitiesTotal();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildUtilitySection(
            title: 'ค่าไฟ',
            icon: Icons.electric_bolt,
            color: Colors.orange,
            previousReading: _electricPreviousReading,
            currentReading: _electricCurrentReading,
            usage: _electricUsage,
            rate: _electricRate,
            baseCharge: 0.0,
            cost: _electricCost,
            controller: _electricCurrentController,
            isReadOnly: _isFromMeterReading,
            onCurrentReadingChanged: (value) {
              setState(() {
                _electricCurrentReading = double.tryParse(value) ?? 0.0;
                _electricUsage =
                    _electricCurrentReading - _electricPreviousReading;
                _electricCost = (_electricUsage * _electricRate);
                _calculateUtilitiesTotal();
              });
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รวมค่าบริการ:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_utilitiesAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilitySection({
    required String title,
    required IconData icon,
    required Color color,
    required double previousReading,
    required double currentReading,
    required double usage,
    required double rate,
    required double baseCharge,
    required double cost,
    required TextEditingController controller,
    required bool isReadOnly,
    required ValueChanged<String> onCurrentReadingChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${rate.toStringAsFixed(2)} บาท/หน่วย',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (baseCharge > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 32),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'รวมค่าบริการพื้นฐาน +${baseCharge.toStringAsFixed(2)} บาท',
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('มิเตอร์ก่อนหน้า',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        previousReading.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('มิเตอร์ปัจจุบัน',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        if (isReadOnly) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                        ],
                      ],
                    ),
                    TextFormField(
                      controller: controller,
                      readOnly: isReadOnly,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        filled: isReadOnly,
                        fillColor: isReadOnly ? Colors.grey[100] : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      onChanged: isReadOnly ? null : onCurrentReadingChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('จำนวนใช้งาน',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${usage.toStringAsFixed(0)} หน่วย',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ค่าใช้จ่าย:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700]),
                ),
                Text(
                  '${cost.toStringAsFixed(2)} บาท',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ Step 3: แสดงการตั้งค่าส่วนลดและค่าปรับ (ใช้ Payment Settings เท่านั้น)
  Widget _buildChargesDiscountsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ⭐ ใช้ widget ใหม่สำหรับค่าใช้จ่ายอื่นๆ
          _buildOtherChargesSection(),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // แสดงส่วนลดและค่าปรับที่คำนวดได้ (แบบ Read-only)
          const Text(
            'ค่าปรับ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ระบบจะคำนวดอัตโนมัติตามการตั้งค่าของสาขา',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          _buildLateFeeDisplay(),

          const SizedBox(height: 24),

          // หมายเหตุ
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'หมายเหตุเพิ่มเติม',
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary),
              ),
              prefixIcon: const Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // _buildDiscountDisplay() removed - Discount system disabled

  // ⭐ Widget แสดงค่าปรับที่คำนวดได้ (Read-only Display)
  Widget _buildLateFeeDisplay() {
    final hasPaymentSettings = _paymentSettings != null;
    final isLateFeeEnabled = hasPaymentSettings &&
        _paymentSettings!['is_active'] == true &&
        _paymentSettings!['enable_late_fee'] == true;
    final baseTotal = _calculateBaseTotal();

    if (!hasPaymentSettings || !isLateFeeEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blueGrey[700], size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('ค่าปรับล่าช้า: ปิดการใช้งาน',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    final lateFeeType = _paymentSettings?['late_fee_type'] ?? 'fixed';
    final lateFeeAmount =
        (_paymentSettings?['late_fee_amount'] ?? 0).toDouble();
    final lateFeeStartDay = _paymentSettings?['late_fee_start_day'] ?? 1;
    final lateFeeMaxAmount = _paymentSettings?['late_fee_max_amount'] != null
        ? (_paymentSettings?['late_fee_max_amount'] as num).toDouble()
        : null;

    // สรุปนโยบาย
    String policyLine;
    switch (lateFeeType) {
      case 'percentage':
        policyLine =
            'เกิน $lateFeeStartDay วัน ค่าปรับ $lateFeeAmount% ของยอดรวม'
            '${lateFeeMaxAmount != null ? ' (สูงสุด ${lateFeeMaxAmount.toStringAsFixed(2)} บาท)' : ''}';
        break;
      case 'daily':
        policyLine =
            'เกิน $lateFeeStartDay วัน คิด ${lateFeeAmount.toStringAsFixed(2)} บาท/วัน'
            '${lateFeeMaxAmount != null ? ' (สูงสุด ${lateFeeMaxAmount.toStringAsFixed(2)} บาท)' : ''}';
        break;
      default:
        policyLine =
            'เกิน $lateFeeStartDay วัน ค่าปรับ ${lateFeeAmount.toStringAsFixed(2)} บาท'
            '${lateFeeMaxAmount != null ? ' (สูงสุด ${lateFeeMaxAmount.toStringAsFixed(2)} บาท)' : ''}';
    }

    // ตัวอย่างคำนวณ (เพื่อแสดงข้อมูลเท่านั้น ไม่คิดตอนสร้างบิล)
    // ใช้วันที่ตัวอย่าง: ชำระช้า lateFeeStartDay + 2 วัน
    final sampleDaysLate = (lateFeeStartDay is int ? lateFeeStartDay : 1) + 2;
    double exampleLateFee;
    switch (lateFeeType) {
      case 'percentage':
        exampleLateFee = baseTotal * (lateFeeAmount / 100);
        break;
      case 'daily':
        final chargeDays = sampleDaysLate - lateFeeStartDay + 1;
        exampleLateFee = lateFeeAmount * (chargeDays <= 0 ? 0 : chargeDays);
        break;
      default:
        exampleLateFee = lateFeeAmount;
    }
    if (lateFeeMaxAmount != null && exampleLateFee > lateFeeMaxAmount) {
      exampleLateFee = lateFeeMaxAmount;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.rule, color: Colors.blueGrey[700], size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ค่าปรับล่าช้า',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blueGrey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        policyLine,
                        style: TextStyle(
                            fontSize: 12, color: Colors.blueGrey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.calculate,
                        size: 16, color: Colors.blueGrey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lateFeeType == 'percentage'
                            ? 'ตัวอย่าง: ยอดรวมปัจจุบัน ${baseTotal.toStringAsFixed(2)} × ${lateFeeAmount.toStringAsFixed(2)}% = ${exampleLateFee.toStringAsFixed(2)} บาท'
                            : lateFeeType == 'daily'
                                ? 'ตัวอย่าง: ชำระช้า ${sampleDaysLate} วัน → ค่าปรับประมาณ ${exampleLateFee.toStringAsFixed(2)} บาท'
                                : 'ตัวอย่าง: ค่าปรับคงที่ ${exampleLateFee.toStringAsFixed(2)} บาท',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blueGrey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final grandTotal = _calculateGrandTotal();

    // ดึงข้อมูลผู้เช่าและห้อง
    final contract = _contracts.firstWhere(
      (c) => c['contract_id'] == _selectedContractId,
      orElse: () => {},
    );
    final room = _rooms.firstWhere(
      (r) => r['room_id'] == _selectedRoomId,
      orElse: () => {},
    );
    final tenantName = contract['tenant_name'] ?? '-';
    final tenantPhone = contract['tenant_phone'] ?? '-';
    final roomNumber = room['room_number'] ?? '-';
    final issueDate = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปรายการ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // รายการค่าใช้จ่าย
          Card(
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
                  const Text('รายละเอียดบิล',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _kv(
                      'รอบบิลเดือน',
                      Formatmonthy.formatBillingCycleTh(
                          month: _invoiceMonth, year: _invoiceYear)),
                  _kv('ออกบิลวันที่', Formatmonthy.formatThaiDate(issueDate)),
                  _kv('ครบกำหนดชำระ', Formatmonthy.formatThaiDate(_dueDate)),
                  const SizedBox(height: 8),
                  _kv('ผู้เช่า', tenantName),
                  _kv('เบอร์', tenantPhone),
                  _kv('ห้อง', roomNumber),
                  const Divider(height: 24),
                  const Text('ค่าใช้จ่าย',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _moneyRow('ค่าเช่า', _rentalAmount),

                  // ค่าน้ำ
                  if (_waterCost > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _moneyRow('ค่าน้ำ', _waterCost),
                        if (_waterUsage > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              '${_waterPreviousReading.toStringAsFixed(0)} - ${_waterCurrentReading.toStringAsFixed(0)} = ${_waterUsage.toStringAsFixed(0)} (${_waterCost.toStringAsFixed(2)})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                              textAlign: TextAlign.right,
                            ),
                          ),
                      ],
                    ),

                  // ค่าไฟ
                  if (_electricCost > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _moneyRow('ค่าไฟ', _electricCost),
                        if (_electricUsage > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              '${_electricPreviousReading.toStringAsFixed(0)} - ${_electricCurrentReading.toStringAsFixed(0)} = ${_electricUsage.toStringAsFixed(0)} (${_electricCost.toStringAsFixed(2)})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                              textAlign: TextAlign.right,
                            ),
                          ),
                      ],
                    ),

                  // ค่าใช้จ่ายอื่นๆ
                  if (_selectedFixedRates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('ค่าใช้จ่ายอื่นๆ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...List.generate(_selectedFixedRates.length, (index) {
                      final rate = _selectedFixedRates[index];
                      final fixedAmount =
                          (rate['fixed_amount'] ?? 0.0).toDouble();
                      final additionalCharge =
                          (rate['additional_charge'] ?? 0.0).toDouble();
                      final unit = fixedAmount + additionalCharge;
                      final qty = (rate['quantity'] ?? 1) as int;
                      final lineTotal = unit * (qty <= 0 ? 1 : qty);
                      final title = rate['rate_name'];
                      final desc = (rate['description'] ?? '').toString();
                      final label = desc.isNotEmpty ? '$title ($desc)' : title;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _moneyRow(label, lineTotal),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              '$title x $qty (${lineTotal.toStringAsFixed(2)})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                  const Divider(height: 24),
                  // Discount functionality removed
                  if (_paymentSettings != null &&
                      _paymentSettings!['is_active'] == true &&
                      _paymentSettings!['enable_late_fee'] == true)
                    _moneyRow('ค่าปรับล่าช้า', _lateFeeAmount, emphasis: true),
                  _moneyRow('ยอดรวม', grandTotal, bold: true),
                ],
              ),
            ),
          ),

          if (_notesController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              // ปรับสีพื้นหลังของการ์ดหมายเหตุให้เป็นสีขาวและมีเส้นขอบ
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'หมายเหตุ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_notesController.text),
                  ],
                ),
              ),
            ),
          ],
        ],
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

  Widget _buildInfoCard() {
    final contract = _contracts.firstWhere(
      (c) => c['contract_id'] == _selectedContractId,
      orElse: () => {},
    );

    if (contract.isEmpty) return const SizedBox.shrink();

    return Card(
      // ปรับสีพื้นหลังของการ์ดข้อมูลสัญญาให้เป็นสีขาว ลบเงา และเพิ่มเส้นขอบ
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'ข้อมูลสัญญา',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow('ผู้เช่า', contract['tenant_name'] ?? '-'),
            _buildInfoRow('เบอร์โทร', contract['tenant_phone'] ?? '-'),
            // ⭐ แสดงค่าเช่า
            _buildInfoRow(
                'ค่าห้อง', '${_rentalAmount.toStringAsFixed(2)} บาท/เดือน'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                ),
                label: const Text('ย้อนกลับ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_currentStep < _totalSteps - 1
                      ? _nextStep
                      : _submitInvoice),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep < _totalSteps - 1 ? 'ถัดไป' : 'บันทึก',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
