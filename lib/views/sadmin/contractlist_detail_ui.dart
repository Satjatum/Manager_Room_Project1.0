import 'package:flutter/material.dart';
import '../../services/contract_service.dart';
import '../../middleware/auth_middleware.dart';
import '../../models/user_models.dart';
import 'contract_edit_ui.dart';
import '../widgets/colors.dart';

class ContractDetailUI extends StatefulWidget {
  final String contractId;

  const ContractDetailUI({
    Key? key,
    required this.contractId,
  }) : super(key: key);

  @override
  State<ContractDetailUI> createState() => _ContractDetailUIState();
}

class _ContractDetailUIState extends State<ContractDetailUI> {
  Map<String, dynamic>? _contract;
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await AuthMiddleware.getCurrentUser();
      final contract = await ContractService.getContractById(widget.contractId);

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _contract = contract;
          _isLoading = false;
        });
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
                Expanded(
                  child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
                ),
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

  // จัดการการเปิดใช้งานสัญญา
  Future<void> _activateContract() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการเปิดใช้งานสัญญา',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text('คุณต้องการเปิดใช้งานสัญญานี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF10B981)),
                SizedBox(height: 16),
                Text('กำลังดำเนินการ...'),
              ],
            ),
          ),
        ),
      );

      final result = await ContractService.activateContract(widget.contractId);
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            backgroundColor:
                result['success'] ? Colors.green.shade600 : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (result['success']) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // จัดการการยกเลิกสัญญา
  Future<void> _terminateContract() async {
    final categoryName = (_contract?['roomcate_name'] ?? '').toString();
    final roomNumber = (_contract?['room_number'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'ยืนยันการยกเลิกสัญญา',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.meeting_room, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${categoryName.isNotEmpty ? categoryName : 'ห้อง'}เลขที่ $roomNumber',
                        style: TextStyle(
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
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'การดำเนินการนี้จะยกเลิกสัญญาและปล่อยห้องว่าง',
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
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ยืนยัน',
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
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
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
                          Icons.cancel_rounded,
                          color: Colors.red.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'ยกเลิก${categoryName.isNotEmpty ? categoryName : 'ห้อง'}เลขที่ $roomNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await ContractService.terminateContract(
          widget.contractId,
          '',
        );

        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor:
                  result['success'] ? Colors.green : Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          if (result['success']) {
            await _loadData();
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('ข้อยกเว้น: ', '')),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // จัดการการต่อสัญญา
  Future<void> _renewContract() async {
    DateTime? newEndDate;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ต่ออายุสัญญา',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เลือกวันที่สิ้นสุดใหม่'),
              SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(_contract!['end_date'])
                        .add(Duration(days: 365)),
                    firstDate: DateTime.parse(_contract!['end_date']),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDialogState(() => newEndDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'วันที่สิ้นสุดใหม่',
                    prefixIcon: Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        newEndDate == null
                            ? 'เลือกวันที่'
                            : '${newEndDate!.day}/${newEndDate!.month}/${newEndDate!.year + 543}',
                      ),
                      Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: newEndDate == null
                  ? null
                  : () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || newEndDate == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF10B981)),
                SizedBox(height: 16),
                Text('กำลังดำเนินการ...'),
              ],
            ),
          ),
        ),
      );

      final result = await ContractService.renewContract(
        widget.contractId,
        newEndDate!,
      );
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            backgroundColor:
                result['success'] ? Colors.green.shade600 : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (result['success']) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year + 543}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'ใช้งานอยู่';
      case 'pending':
        return 'รอดำเนินการ';
      case 'terminated':
        return 'ยกเลิกแล้ว';
      case 'expired':
        return 'หมดอายุ';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _contract?['contract_status']?.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(status),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _contract == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ไม่พบข้อมูลสัญญา',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primary,
                        child: ListView(
                          padding: EdgeInsets.all(16),
                          children: [
                      // สถานะสัญญา - ธีมใหม่
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                        _contract!['contract_status'])
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.description_rounded,
                                size: 48,
                                color: _getStatusColor(
                                    _contract!['contract_status']),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _contract!['contract_num'] ?? 'ไม่ระบุ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                        _contract!['contract_status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(
                                          _contract!['contract_status'])
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getStatusText(_contract!['contract_status']),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(
                                      _contract!['contract_status']),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      // ข้อมูลผู้เช่า
                      _buildInfoCard(
                        'ข้อมูลผู้เช่า',
                        Icons.person_outline,
                        [
                          _buildInfoRow(
                              'ชื่อ-นามสกุล', _contract!['tenant_name']),
                          _buildInfoRow('เบอร์โทร', _contract!['tenant_phone']),
                        ],
                      ),
                      SizedBox(height: 16),

                      // ข้อมูลห้อง
                      _buildInfoCard(
                        'ข้อมูลห้อง',
                        Icons.home_outlined,
                        [
                          _buildInfoRow('ประเภท', _contract!['roomcate_name']),
                          _buildInfoRow('หมายเลข', _contract!['room_number']),
                          _buildInfoRow('สาขา', _contract!['branch_name']),
                        ],
                      ),
                      SizedBox(height: 16),

                      // ระยะเวลาสัญญา
                      _buildInfoCard(
                        'ระยะเวลาสัญญา',
                        Icons.calendar_today_outlined,
                        [
                          _buildInfoRow('วันที่เริ่มสัญญา',
                              _formatDate(_contract!['start_date'])),
                          _buildInfoRow('วันที่สิ้นสุดสัญญา',
                              _formatDate(_contract!['end_date'])),
                          _buildInfoRow(
                              'วันชำระเงินประจำเดือน',
                              _contract!['payment_day'] != null
                                  ? 'วันที่ ${_contract!['payment_day']}'
                                  : '-'),
                        ],
                      ),
                      SizedBox(height: 16),

                      // รายละเอียดการเงิน
                      _buildInfoCard(
                        'รายละเอียดการเงิน',
                        Icons.payments_outlined,
                        [
                          _buildInfoRow('ค่าเช่าต่อเดือน',
                              '฿${_contract!['contract_price']?.toStringAsFixed(0) ?? '0'}'),
                          _buildInfoRow('ค่าประกัน',
                              '฿${_contract!['contract_deposit']?.toStringAsFixed(0) ?? '0'}'),
                          _buildInfoRow(
                            'สถานะชำระค่าประกัน',
                            _contract!['contract_paid'] == true
                                ? 'ชำระแล้ว'
                                : 'ยังไม่ชำระ',
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // หมายเหตุ
                      if (_contract!['contract_note'] != null &&
                          _contract!['contract_note'].toString().isNotEmpty)
                        _buildInfoCard(
                          'หมายเหตุ',
                          Icons.note_outlined,
                          [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _contract!['contract_note'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 80),
                    ],
                  ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String status) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
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
                      'รายละเอียดสัญญา',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'สำหรับดูรายละเอียดสัญญา',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading && _contract != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ContractEditUI(contractId: widget.contractId),
                          ),
                        );
                        if (result == true) _loadData();
                        break;
                      case 'activate':
                        _activateContract();
                        break;
                      case 'renew':
                        _renewContract();
                        break;
                      case 'terminate':
                        _terminateContract();
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined,
                                size: 20, color: Color(0xFF14B8A6)),
                            SizedBox(width: 12),
                            Text('แก้ไข'),
                          ],
                        ),
                      ),
                      if (status == 'active')
                        PopupMenuItem(
                          value: 'renew',
                          child: Row(
                            children: const [
                              Icon(Icons.refresh,
                                  size: 20, color: Color(0xFF14B8A6)),
                              SizedBox(width: 12),
                              Text('ต่อสัญญา'),
                            ],
                          ),
                        ),
                      if (status == 'active' || status == 'pending')
                        PopupMenuItem(
                          value: 'terminate',
                          child: Row(
                            children: const [
                              Icon(Icons.cancel, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'ยกเลิกสัญญา',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(20),
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
              Icon(icon, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
