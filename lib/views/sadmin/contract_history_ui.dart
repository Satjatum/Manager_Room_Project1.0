import 'package:flutter/material.dart';
import '../../services/contract_service.dart';
import '../widgets/colors.dart';
import 'contractlist_detail_ui.dart';

class ContractHistoryUI extends StatefulWidget {
  final String tenantId;
  final String? tenantName;

  const ContractHistoryUI({
    Key? key,
    required this.tenantId,
    this.tenantName,
  }) : super(key: key);

  @override
  State<ContractHistoryUI> createState() => _ContractHistoryUIState();
}

class _ContractHistoryUIState extends State<ContractHistoryUI> {
  bool _loading = true;
  List<Map<String, dynamic>> _contracts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ContractService.getAllContracts(
        tenantId: widget.tenantId,
        limit: 500,
      );
      if (mounted) setState(() => _contracts = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('โหลดประวัติสัญญาไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year + 543}';
    } catch (_) {
      return d;
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.grey;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusText(String? s) {
    switch (s) {
      case 'active':
        return 'ใช้งานอยู่';
      case 'pending':
        return 'รออนุมัติ';
      case 'expired':
        return 'หมดอายุ';
      case 'terminated':
        return 'ยกเลิก';
      default:
        return s ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประวัติสัญญา',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.tenantName != null)
              Text(
                widget.tenantName!,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('กำลังโหลด...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: _contracts.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.description_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'ยังไม่มีประวัติสัญญา',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contracts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = _contracts[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContractDetailUI(
                                    contractId: c['contract_id'],
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusColor(c['contract_status'])
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusText(c['contract_status']),
                                      style: TextStyle(
                                        color:
                                            _statusColor(c['contract_status']),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'สัญญา: ${c['contract_num'] ?? '-'}  | ${c['roomcate_name']}เลขที่${c['room_number'] ?? '-'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ช่วงสัญญา: ${_formatDate(c['start_date'])} - ${_formatDate(c['end_date'])}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
