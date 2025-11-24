import 'package:flutter/material.dart';
import 'package:manager_room_project/middleware/auth_middleware.dart';
import 'package:manager_room_project/services/payment_service.dart';
import 'package:manager_room_project/views/widgets/colors.dart';

class TenantPayHistoryUi extends StatefulWidget {
  final String invoiceId;
  const TenantPayHistoryUi({super.key, required this.invoiceId});

  @override
  State<TenantPayHistoryUi> createState() => _TenantPayHistoryUiState();
}

class _TenantPayHistoryUiState extends State<TenantPayHistoryUi> {
  bool _loading = true;
  List<Map<String, dynamic>> _slipHistory = [];
  Map<String, dynamic>? _invoiceInfo;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _loadHistory() async {
    // Check if widget is still mounted before updating state
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final user = await AuthMiddleware.getCurrentUser();

      // Check mounted after async operation
      if (!mounted) return;

      if (user == null || user.tenantId == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // ดึงประวัติสลิปทั้งหมดของบิลนี้
      final allSlips = await PaymentService.listPaymentSlips(
        status: 'all',
        limit: 100,
      );

      // Check mounted after async operation
      if (!mounted) return;

      // กรองเฉพาะสลิปของบิลนี้และผู้เช่านี้
      final filteredSlips = allSlips
          .where((slip) =>
              slip['invoice_id']?.toString() == widget.invoiceId &&
              slip['tenant_id']?.toString() == user.tenantId)
          .toList();

      // ดึงข้อมูลไฟล์เพิ่มเติมสำหรับแต่ละสลิป
      for (var slip in filteredSlips) {
        // Check mounted in loop to prevent memory leak
        if (!mounted) return;

        try {
          final slipId = slip['slip_id']?.toString() ?? '';
          if (slipId.isNotEmpty) {
            final slipDetail = await PaymentService.getSlipById(slipId);

            // Check mounted after each async call
            if (!mounted) return;

            if (slipDetail != null) {
              slip['files'] = slipDetail['files'] ?? [];
            }
          }
        } catch (e) {
          // OWASP A09:2021 - Security Logging and Monitoring
          // Log with context but don't expose sensitive data
          print(
              '[SECURITY_LOG] Error loading slip files - SlipID: ${slip['slip_id']}, Error: ${e.runtimeType}');
          slip['files'] = [];
        }
      }

      // Check mounted before sorting (CPU intensive operation)
      if (!mounted) return;

      // เรียงจากใหม่ไปเก่า
      filteredSlips.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.now();
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.now();
        return dateB.compareTo(dateA);
      });

      // เก็บข้อมูลบิลจากสลิปแรก (ถ้ามี)
      Map<String, dynamic>? invoiceInfo;
      if (filteredSlips.isNotEmpty) {
        final firstSlip = filteredSlips.first;
        invoiceInfo = {
          'invoice_number': firstSlip['invoice_number'],
          'invoice_total': firstSlip['invoice_total'],
          'invoice_paid': firstSlip['invoice_paid'],
          'room_number': firstSlip['room_number'],
          'tenant_name': firstSlip['tenant_name'],
        };
      }

      // Final mounted check before setState
      if (!mounted) return;

      setState(() {
        _slipHistory = filteredSlips;
        _invoiceInfo = invoiceInfo;
        _loading = false;
      });
    } catch (e, stackTrace) {
      // OWASP A09:2021 - Comprehensive error logging
      print(
          '[SECURITY_LOG] Failed to load payment history - InvoiceID: ${widget.invoiceId}, Error: ${e.runtimeType}');
      print('[DEBUG] Stack trace: $stackTrace');

      // Check mounted before setState in catch block
      if (!mounted) return;

      setState(() => _loading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โหลดประวัติไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ประวัติการแจ้งชำระ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _invoiceInfo != null
                              ? 'บิล #${_invoiceInfo!['invoice_number'] ?? '-'}'
                              : 'ประวัติการส่งสลิปทั้งหมด',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bill Summary (ถ้ามีข้อมูล)
            if (_invoiceInfo != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildBillSummary(),
              ),
              const SizedBox(height: 16),
            ],

            // History List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: _buildHistoryList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary() {
    if (_invoiceInfo == null) return const SizedBox.shrink();

    final total = _asDouble(_invoiceInfo!['invoice_total']);
    final paid = _asDouble(_invoiceInfo!['invoice_paid']);
    final remaining = (total - paid).clamp(0.0, double.infinity);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_invoiceInfo!['tenant_name'] ?? '-'} - ห้อง ${_invoiceInfo!['room_number'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryItem('ยอดรวม', '${_formatMoney(total)} บาท'),
                ),
                Expanded(
                  child: _summaryItem('ชำระแล้ว', '${_formatMoney(paid)} บาท',
                      color: Colors.green),
                ),
                Expanded(
                  child: _summaryItem(
                      'คงเหลือ', '${_formatMoney(remaining)} บาท',
                      color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_slipHistory.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('ยังไม่มีประวัติการส่งสลิป'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _slipHistory.length,
      itemBuilder: (context, index) =>
          _buildSlipCard(_slipHistory[index], index),
    );
  }

  Widget _buildSlipCard(Map<String, dynamic> slip, int index) {
    final paidAmount = _asDouble(slip['paid_amount']);
    final paymentDate = slip['payment_date']?.toString() ?? '';
    final paymentTime = slip['payment_time']?.toString() ?? '';
    final createdAt = slip['created_at']?.toString() ?? '';
    final tenantNotes = slip['tenant_notes']?.toString() ?? '';
    final rejectionReason = slip['rejection_reason']?.toString() ?? '';
    final slipImage = slip['slip_image']?.toString() ?? '';
    final isVerified =
        slip['payment_id'] != null && slip['payment_id'].toString().isNotEmpty;
    final isRejected = !isVerified &&
        (slip['rejection_reason'] != null ||
            (slip['verified_at'] != null &&
                slip['verified_at'].toString().isNotEmpty));

    // กำหนดสีและสถานะ
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isVerified) {
      statusColor = const Color(0xFF22C55E);
      statusText = 'อนุมัติแล้ว';
      statusIcon = Icons.check_circle;
    } else if (isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusText = 'ถูกปฏิเสธ';
      statusIcon = Icons.cancel;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'รอตรวจสอบ';
      statusIcon = Icons.schedule;
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: สถานะ + วันที่
            Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Text(
                  'ครั้งที่ ${_slipHistory.length - index}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // จำนวนเงินที่ส่ง
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  const Text(
                    'จำนวนเงินที่ส่ง: ',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Expanded(
                    child: Text(
                      '${_formatMoney(paidAmount)} บาท',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // วันที่และเวลาที่ส่ง
            _infoRow(
                'วันที่ส่งสลิป', _formatSlipDate(paymentDate, paymentTime)),
            if (createdAt.isNotEmpty)
              _infoRow('บันทึกเมื่อ', _formatCreatedDate(createdAt)),

            // หมายเหตุผู้เช่า
            if (tenantNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0EA5E9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_outlined,
                        size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tenantNotes,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0C4A6E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // เหตุผลปฏิเสธ
            if (isRejected && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'เหตุผลปฏิเสธ: $rejectionReason',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // รูปสลิป (รองรับหลายรูป)
            _buildSlipImages(slip),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipImages(Map<String, dynamic> slip) {
    final slipImage = slip['slip_image']?.toString() ?? '';
    final files = slip['files'] as List<dynamic>? ?? [];

    // รวมรูปจาก slip_image และ files
    final List<String> imageUrls = [];

    // เพิ่มรูปหลักจาก slip_image
    if (slipImage.isNotEmpty) {
      imageUrls.add(slipImage);
    }

    // เพิ่มรูปเพิ่มเติมจาก files
    for (var file in files) {
      final fileUrl = file['file_url']?.toString() ?? '';
      if (fileUrl.isNotEmpty && !imageUrls.contains(fileUrl)) {
        imageUrls.add(fileUrl);
      }
    }

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.image, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              'สลิป (${imageUrls.length} รูป)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              return Container(
                width: 100,
                margin: EdgeInsets.only(
                    right: index < imageUrls.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => _showSlipImageGallery(imageUrls, index),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 24, color: Colors.grey),
                              ),
                            ),
                          ),
                          if (imageUrls.length > 1)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'แตะเพื่อดูรูปขนาดใหญ่',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  void _showSlipImageGallery(List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _ImageGalleryDialog(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }

  String _formatSlipDate(String date, String time) {
    if (date.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(date);
      if (dt == null) return date;

      const thMonths = [
        '',
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.'
      ];
      final y = dt.year + 543;
      final m = thMonths[dt.month];
      final d = dt.day.toString();

      final dateStr = '$d $m $y';
      return time.isNotEmpty
          ? '$dateStr เวลา ${time.substring(0, 5)} น.'
          : dateStr;
    } catch (e) {
      return date;
    }
  }

  String _formatCreatedDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;

      const thMonths = [
        '',
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.'
      ];
      final y = dt.year + 543;
      final m = thMonths[dt.month];
      final d = dt.day.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return '$d $m $y เวลา $hour:$minute น.';
    } catch (e) {
      return iso;
    }
  }

  String _formatMoney(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      buf.write(intPart[i]);
      final left = intPart.length - i - 1;
      if (left > 0 && left % 3 == 0) buf.write(',');
    }
    return buf.toString() + '.' + dec;
  }
}

class _ImageGalleryDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _ImageGalleryDialog({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Stack(
          children: [
            // Image PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    maxScale: 3.0,
                    child: Image.network(
                      widget.imageUrls[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.white),
                            SizedBox(height: 16),
                            Text('ไม่สามารถโหลดรูปได้',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),

            // Image counter (if multiple images)
            if (widget.imageUrls.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

            // Navigation hints (if multiple images)
            if (widget.imageUrls.length > 1) ...[
              // Previous button
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
              // Next button
              if (_currentIndex < widget.imageUrls.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],

            // Instructions text at bottom
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.imageUrls.length > 1
                      ? 'เลื่อนซ้าย-ขวาเพื่อดูรูปอื่น • หยิกเพื่อซูม'
                      : 'หยิกเพื่อซูม',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
