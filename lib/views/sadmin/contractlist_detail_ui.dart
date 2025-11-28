import 'package:flutter/material.dart';
// Services //
import '../../services/contract_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contract = await ContractService.getContractById(widget.contractId);

      if (mounted) {
        setState(() {
          _contract = contract;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
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
                                      _getStatusText(
                                          _contract!['contract_status']),
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
                              'รายละเอียดผู้เช่า',
                              Icons.person_outline,
                              [
                                _buildInfoRow(
                                    'ชื่อ-นามสกุล', _contract!['tenant_name']),
                                _buildInfoRow(
                                    'เบอร์โทร', _contract!['tenant_phone']),
                              ],
                            ),
                            SizedBox(height: 16),

                            // ข้อมูลห้อง
                            _buildInfoCard(
                              'รายละเอียดห้องพัก',
                              Icons.business_outlined,
                              [
                                _buildInfoRow(
                                    'ประเภท', _contract!['roomcate_name']),
                                _buildInfoRow(
                                    'หมายเลข', _contract!['room_number']),
                              ],
                            ),
                            SizedBox(height: 16),

                            // ระยะเวลาสัญญา
                            _buildInfoCard(
                              'รายละเอียดสัญญา',
                              Icons.description_outlined,
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
                                _contract!['contract_note']
                                    .toString()
                                    .isNotEmpty)
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
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
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
