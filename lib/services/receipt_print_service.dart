import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'invoice_service.dart';
import 'room_service.dart';
import 'meter_service.dart';
import 'utility_rate_service.dart';

class ReceiptPrintService {
  /// Generate and open system print dialog for an 80mm receipt.
  ///
  /// Expects a slip row from PaymentService.listPaymentSlips (contains invoice_id, etc.)
  static Future<void> printSlipFromSlipRow(Map<String, dynamic> slipRow) async {
    final invoiceId = (slipRow['invoice_id'] ?? '').toString();
    if (invoiceId.isEmpty) return;

    final invoice = await InvoiceService.getInvoiceById(invoiceId);
    if (invoice == null) return;

    // Find related payment (prefer the one linked to this slip)
    final payments =
        (invoice['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    Map<String, dynamic>? payment;
    final slipPaymentId = slipRow['payment_id'];
    if (slipPaymentId != null) {
      payment = payments.firstWhere(
        (p) => (p['payment_id']?.toString() ?? '') == slipPaymentId.toString(),
        orElse: () =>
            payments.isNotEmpty ? payments.first : <String, dynamic>{},
      );
    } else if (payments.isNotEmpty) {
      payment = payments.first;
    }

    // Prefer local TH Sarabun New (assets) if available; fallback to Google Sarabun
    Future<pw.Font> _loadThaiRegular() async {
      const candidates = [
        'assets/fonts/THSarabunNew/THSarabunNew.ttf',
        'assets/fonts/THSarabunNew/THSarabunNew-Regular.ttf',
        'assets/fonts/thsarabunnew/THSarabunNew.ttf',
        'assets/fonts/thsarabunnew/THSarabunNew-Regular.ttf',
      ];
      for (final p in candidates) {
        try {
          final data = await rootBundle.load(p);
          return pw.Font.ttf(data);
        } catch (_) {}
      }
      return await PdfGoogleFonts.sarabunRegular();
    }

    Future<pw.Font> _loadThaiBold() async {
      const candidates = [
        'assets/fonts/THSarabunNew/THSarabunNew-Bold.ttf',
        'assets/fonts/THSarabunNew/THSarabunNew Bold.ttf',
        'assets/fonts/thsarabunnew/THSarabunNew-Bold.ttf',
        'assets/fonts/thsarabunnew/THSarabunNew Bold.ttf',
      ];
      for (final p in candidates) {
        try {
          final data = await rootBundle.load(p);
          return pw.Font.ttf(data);
        } catch (_) {}
      }
      return await PdfGoogleFonts.sarabunBold();
    }

    final sarabun = await _loadThaiRegular();
    final sarabunBold = await _loadThaiBold();
    final notoThai = await PdfGoogleFonts.notoSansThaiRegular();
    final kanit = await PdfGoogleFonts.kanitRegular();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: sarabun,
        bold: sarabunBold,
      ),
    );

    final pageFormat = PdfPageFormat(
        80 * PdfPageFormat.mm, PdfPageFormat.a4.height,
        marginAll: 5 * PdfPageFormat.mm);

    // ปรับปรุง text styles - เพิ่มขนาดและ spacing
    final thaiHeader = pw.TextStyle(
        font: sarabunBold, fontSize: 16, height: 1.3, fontFallback: [notoThai]);
    final thaiTitle = pw.TextStyle(
        font: sarabunBold, fontSize: 12, height: 1.3, fontFallback: [notoThai]);
    final thai10 = pw.TextStyle(
        font: sarabun, fontSize: 10, height: 1.3, fontFallback: [notoThai]);
    final thai10b = pw.TextStyle(
        font: sarabunBold, fontSize: 10, height: 1.3, fontFallback: [notoThai]);
    final thai11 = pw.TextStyle(
        font: sarabun, fontSize: 11, height: 1.3, fontFallback: [notoThai]);
    final thai11b = pw.TextStyle(
        font: sarabunBold, fontSize: 11, height: 1.3, fontFallback: [notoThai]);
    final thai9 = pw.TextStyle(
        font: sarabun, fontSize: 9, height: 1.3, fontFallback: [notoThai]);
    final en9 = pw.TextStyle(font: kanit, fontSize: 9, height: 1.2);

    String _s(dynamic v) => (v ?? '').toString();
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0.0;

    final branchName = _s(invoice['branch_name']);
    final branchAddress = _s(invoice['branch_address']);
    final branchPhone = _s(invoice['branch_phone']);
    final roomNumber = _s(invoice['room_number']);
    final tenantName = _s(invoice['tenant_name']);
    final invoiceNumber = _s(invoice['invoice_number']);
    final paymentNumber = _s(payment?['payment_number']);
    final paymentMethod = _s(
        payment?['payment_method'].toString().isEmpty == true
            ? slipRow['payment_method']
            : payment?['payment_method']);

    final rentalAmount = _d(invoice['rental_amount']);
    final discountAmount = _d(invoice['discount_amount']);
    final utilities =
        (invoice['utilities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final otherCharges =
        (invoice['other_charges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalAmount = _d(invoice['total_amount']);
    final paidAmount = _d(payment?['payment_amount'] ?? slipRow['paid_amount']);

    // Load room details to get category name (if available)
    String roomCategoryName = '';
    try {
      final roomId = _s(invoice['room_id']);
      if (roomId.isNotEmpty) {
        final room = await RoomService.getRoomById(roomId);
        roomCategoryName = _s(room?['room_category_name']);
      }
    } catch (_) {}

    // Try to fetch meter reading (for water/electric details) if present
    Map<String, dynamic>? reading;
    final readingId =
        _s((utilities.isNotEmpty ? utilities.first['reading_id'] : null));
    if (readingId.isNotEmpty) {
      try {
        reading = await MeterReadingService.getMeterReadingById(readingId);
      } catch (_) {}
    }

    // Billing period: first day of next month - last day of next month (English)
    final int im = (invoice['invoice_month'] ?? DateTime.now().month) as int;
    final int iy = (invoice['invoice_year'] ?? DateTime.now().year) as int;
    final period = _nextMonthPeriod(im, iy);
    final billingPeriod = '${_fmtDateEn(period.$1)} - ${_fmtDateEn(period.$2)}';

    // Preload unit labels for utilities by rate_id
    final Map<String, String> rateUnits = {};
    for (final u in utilities) {
      final rid = _s(u['rate_id']);
      if (rid.isNotEmpty) {
        try {
          final rate = await UtilityRatesService.getUtilityRateById(rid);
          final label = _s(rate?['rate_unit']);
          if (label.isNotEmpty) rateUnits[rid] = label;
        } catch (_) {}
      }
    }

    List<pw.Widget> _buildItems() {
      final rows = <pw.Widget>[];
      if (rentalAmount > 0) {
        rows.add(_itemRow('ค่าเช่า', rentalAmount, thai11));
      }
      for (final u in utilities) {
        final name = _s(u['utility_name']);
        final qty = _d(u['usage_amount']);
        final unitPrice = _d(u['unit_price']);
        final line = _d(u['total_amount']);
        // Determine metered vs fixed
        final isElectric = name.contains('ไฟ');
        final isWater = name.contains('น้ำ');
        final isMetered = (isElectric || isWater) && reading != null;

        // Build label as: name (unit price)
        String unitLabel = '';
        if (isElectric || isWater) {
          unitLabel = '${unitPrice.toStringAsFixed(2)} บาท/หน่วย';
        }

        final String label = unitLabel.isNotEmpty ? '$name ($unitLabel)' : name;

        rows.add(_itemRow(label, line, thai11));

        if (isMetered) {
          // Show calculation line under the item
          double prev = 0, curr = 0, usage = qty;
          if (isElectric) {
            prev = _d(reading['electric_previous_reading']);
            curr = _d(reading['electric_current_reading']);
            usage = _d(reading['electric_usage']);
          } else if (isWater) {
            prev = _d(reading['water_previous_reading']);
            curr = _d(reading['water_current_reading']);
            usage = _d(reading['water_usage']);
          }
          rows.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 3, top: 1),
              child: pw.Text(
                '(${prev.toStringAsFixed(0)} - ${curr.toStringAsFixed(0)} = ${usage.toStringAsFixed(0)} หน่วย)',
                style: thai9,
              ),
            ),
          );
        }
      }
      for (final oc in otherCharges) {
        rows.add(
            _itemRow(_s(oc['charge_name']), _d(oc['charge_amount']), thai11));
      }
      if (discountAmount > 0) {
        rows.add(_itemRow('ส่วนลด', -discountAmount, thai11));
      }
      return rows;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        maxPages: 2,
        build: (context) => [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // === HEADER SECTION ===
                pw.Center(
                  child: pw.Text(
                    branchName.isEmpty ? 'สาขา' : branchName,
                    style: thaiHeader,
                  ),
                ),
                if (branchAddress.isNotEmpty) pw.SizedBox(height: 2),
                if (branchAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(branchAddress,
                        style: thai10, textAlign: pw.TextAlign.center),
                  ),
                if (branchPhone.isNotEmpty) pw.SizedBox(height: 2),
                if (branchPhone.isNotEmpty)
                  pw.Center(
                    child: pw.Text('ติดต่อ: $branchPhone', style: thai10),
                  ),

                pw.SizedBox(height: 8),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Center(
                    child: pw.Text('ใบเสร็จรับเงิน', style: thaiTitle),
                  ),
                ),

                pw.SizedBox(height: 6),

                // === RECEIPT INFO SECTION ===
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Column(
                    children: [
                      _infoRow('Receipt No.',
                          paymentNumber.isEmpty ? '-' : paymentNumber, thai10),
                      pw.SizedBox(height: 2),
                      _infoRow('Invoice No.', invoiceNumber, thai10),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),

                // === CUSTOMER INFO SECTION ===
                _infoRow('รอบบิล', billingPeriod, thai10),
                pw.SizedBox(height: 3),
                _infoRow('ชื่อ', tenantName, thai10),
                pw.SizedBox(height: 3),
                if (roomCategoryName.isNotEmpty) ...[
                  _infoRow('ประเภท', roomCategoryName, thai10),
                  pw.SizedBox(height: 3),
                ],
                _infoRow('เลขที่', roomNumber, thai10),
                pw.SizedBox(height: 3),
                _infoRow('การชำระเงิน',
                    paymentMethod.isEmpty ? 'โอนชำระ' : paymentMethod, thai10),

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // === ITEMS SECTION ===
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('รายการ', style: thai11b),
                    pw.Text('จำนวนเงิน', style: thai11b),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 2),

                ..._buildItems(),

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // === TOTAL SECTION ===
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Column(
                    children: [
                      _totalRow('ยอดรวม', totalAmount, thai11b),
                      pw.SizedBox(height: 4),
                      _totalRow('จ่ายแล้ว', paidAmount, thai11b),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // === SIGNATURE SECTION ===
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            height: 30,
                          ),
                          pw.Container(
                            height: 0.5,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text('ผู้รับเงิน', style: thai10),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            height: 30,
                          ),
                          pw.Container(
                            height: 0.5,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text('วันที่', style: thai10),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text('ขอบคุณที่ใช้บริการ', style: thai10b),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text('Thank you', style: en9),
                ),
              ])
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  static pw.Widget _itemRow(String label, double amount, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(label, style: style),
          ),
          pw.SizedBox(width: 8),
          pw.Text(_money(amount), style: style),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.TextStyle style) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(label, style: style),
        ),
        pw.Text(': ', style: style),
        pw.Expanded(
          child: pw.Text(value, style: style),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, double amount, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_money(amount), style: style),
      ],
    );
  }

  static String _money(double v) => '${v.toStringAsFixed(2)} ฿';

  // Helpers for English date formatting and next month period
  static const List<String> _enMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  static String _fmtDateEn(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final m = _enMonths[d.month - 1];
    final y = d.year.toString();
    return '$dd $m $y';
  }

  // Returns (firstDayNextMonth, lastDayNextMonth) using Dart records
  static (DateTime, DateTime) _nextMonthPeriod(int month, int year) {
    final base = DateTime(year, month, 1);
    final next = DateTime(base.year, base.month + 1, 1);
    final first = DateTime(next.year, next.month, 1);
    final last = DateTime(next.year, next.month + 1, 0);
    return (first, last);
  }
}
