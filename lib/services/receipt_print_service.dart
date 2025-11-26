import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'invoice_service.dart';
import 'room_service.dart';
import 'meter_service.dart';
import '../utils/formatMonthy.dart';

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
        'assets/fonts/thsarabunnew/THSarabunNew.ttf',
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
        'assets/fonts/THSarabunNew/THSarabunNew Bold.ttf',
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

    // 80mm width with auto height
    final pageFormat = PdfPageFormat(
        80 * PdfPageFormat.mm, PdfPageFormat.a4.height,
        marginAll: 5 * PdfPageFormat.mm);

    // Text styles
    final thaiHeader = pw.TextStyle(
        font: sarabunBold, fontSize: 18, height: 1.3, fontFallback: [notoThai]);
    final thaiTitle = pw.TextStyle(
        font: sarabunBold, fontSize: 14, height: 1.3, fontFallback: [notoThai]);
    final thai11 = pw.TextStyle(
        font: sarabun, fontSize: 11, height: 1.3, fontFallback: [notoThai]);
    final thaiBaht = pw.TextStyle(
        font: sarabunBold, fontSize: 11, height: 1.3, fontFallback: [notoThai]);
    final thai10 = pw.TextStyle(
        font: sarabun, fontSize: 10, height: 1.3, fontFallback: [notoThai]);
    final thai10b = pw.TextStyle(
        font: sarabunBold, fontSize: 10, height: 1.3, fontFallback: [notoThai]);
    final thai9 = pw.TextStyle(
        font: sarabun, fontSize: 9, height: 1.3, fontFallback: [notoThai]);
    final en9 = pw.TextStyle(font: kanit, fontSize: 9, height: 1.2);

    String _s(dynamic v) => (v ?? '').toString();
    double _d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0.0;

    // Extract data
    final branchName = _s(invoice['branch_name']);
    final branchPhone = _s(invoice['branch_phone']);
    final branchAddress = _s(invoice['branch_address']);
    final roomNumber = _s(invoice['room_number']);
    final tenantName = _s(invoice['tenant_name']);
    final invoiceNumber = _s(invoice['invoice_number']);
    final paymentMethod = _s(
        payment?['payment_method'].toString().isEmpty == true
            ? slipRow['payment_method']
            : payment?['payment_method']);

    final rentalAmount = _d(invoice['rental_amount']);
    final lateFeeAmount = _d(invoice['late_fee_amount']);

    // Safely cast utilities - handle both direct list and nested structure
    List<Map<String, dynamic>> utilities = [];
    final utilsRaw = invoice['utilities'];
    if (utilsRaw is List) {
      utilities = utilsRaw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Safely cast other charges - use other_charge_lines
    List<Map<String, dynamic>> otherCharges = [];
    final otherRaw = invoice['other_charge_lines'];
    if (otherRaw is List) {
      otherCharges = otherRaw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    final totalAmount = _d(invoice['total_amount']);

    // Load room details to get category name (ประเภท)
    String roomCategoryName = '';
    try {
      final roomId = _s(invoice['room_id']);
      if (roomId.isNotEmpty) {
        final room = await RoomService.getRoomById(roomId);
        roomCategoryName = _s(room?['room_category_name']);
      }
    } catch (_) {}

    // Try to fetch meter reading (for water/electric details)
    Map<String, dynamic>? reading;
    final readingId =
        _s((utilities.isNotEmpty ? utilities.first['reading_id'] : null));
    if (readingId.isNotEmpty) {
      try {
        reading = await MeterReadingService.getMeterReadingById(readingId);
      } catch (_) {}
    }

    // Billing period: รอบบิล (ภาษาไทย พ.ศ.)
    int im = DateTime.now().month;
    int iy = DateTime.now().year;

    final monthRaw = invoice['invoice_month'];
    if (monthRaw != null) {
      if (monthRaw is int) {
        im = monthRaw;
      } else if (monthRaw is String) {
        im = int.tryParse(monthRaw) ?? DateTime.now().month;
      }
    }

    final yearRaw = invoice['invoice_year'];
    if (yearRaw != null) {
      if (yearRaw is int) {
        iy = yearRaw;
      } else if (yearRaw is String) {
        iy = int.tryParse(yearRaw) ?? DateTime.now().year;
      }
    }

    final billingPeriod =
        Formatmonthy.formatBillingCycleTh(month: im, year: iy);

    // วันที่ชำระ (Thai format with BE year) - use paid_date first
    String paymentDate = '-';
    final paidDateRaw =
        payment?['paid_date'] ?? payment?['paid_at'] ?? slipRow['created_at'];
    if (paidDateRaw != null) {
      paymentDate =
          Formatmonthy.formatThaiDateStr(_s(paidDateRaw), shortMonth: true);
    }

    List<pw.Widget> _buildItems() {
      final rows = <pw.Widget>[];

      // ค่าเช่า
      if (rentalAmount > 0) {
        rows.add(_itemRow('ค่าเช่า', rentalAmount, thai11));
      }

      // ค่าน้ำค่าไฟ
      for (final u in utilities) {
        final name = _s(u['utility_name']);
        final qty = _d(u['usage_amount']);
        final unitPrice = _d(u['unit_price']);
        final line = _d(u['total_amount']);

        final isElectric = name.contains('ไฟ');
        final isWater = name.contains('น้ำ');
        final isMetered = (isElectric || isWater) && reading != null;

        rows.add(_itemRow(name, line, thai11));

        if (isMetered) {
          // Show calculation line: เลขก่อน - เลขหลัง = ยูนิต(ราคาต่อหน่วย)
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
            pw.Text(
              '${prev.toStringAsFixed(0)} - ${curr.toStringAsFixed(0)} = ${usage.toStringAsFixed(0)} (${unitPrice.toStringAsFixed(2)} บาท/หน่วย)',
              style: thai9,
            ),
          );
        }
      }

      return rows;
    }

    List<pw.Widget> _buildOtherCharges() {
      final rows = <pw.Widget>[];

      if (otherCharges.isEmpty) return rows;

      for (final oc in otherCharges) {
        final chargeName = _s(oc['charge_name']);
        final chargeAmount = _d(oc['charge_amount']);
        final chargeDesc = _s(oc['charge_desc']);

        // แสดงรูปแบบ: "ชื่อ (คำอธิบาย)" ถ้ามี description เหมือน invoicelist_detail_ui.dart
        String label = chargeName;
        if (chargeDesc.isNotEmpty) {
          label = '$chargeName ($chargeDesc)';
        }

        rows.add(_itemRow(label, chargeAmount, thai11));
      }

      return rows;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        maxPages: 3,
        build: (context) => [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. ชื่อ Branch อยู่กลางกระดาษ
                pw.Center(
                  child: pw.Text(
                    branchName.isEmpty ? 'สาขา' : branchName,
                    style: thaiHeader,
                  ),
                ),

                // 2. BranchPhone
                if (branchPhone.isNotEmpty) pw.SizedBox(height: 4),
                if (branchPhone.isNotEmpty)
                  pw.Center(
                    child: pw.Text('โทร: $branchPhone', style: thai10),
                  ),

                // Branch Address
                if (branchAddress.isNotEmpty) pw.SizedBox(height: 2),
                if (branchAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(branchAddress,
                        style: thai10, textAlign: pw.TextAlign.center),
                  ),

                pw.SizedBox(height: 8),

                // 3. ใบเสร็จค่าเช่า
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Center(
                    child: pw.Text('ใบเสร็จค่าเช่า', style: thaiTitle),
                  ),
                ),

                pw.SizedBox(height: 8),

                // 4. Invoice No
                _infoRow('Invoice No.', invoiceNumber, thai11),
                pw.SizedBox(height: 3),

                // 5. รอบบิล
                _infoRow('รอบบิล', billingPeriod, thai11),
                pw.SizedBox(height: 3),

                // 6. ชื่อผู้เช่า
                _infoRow('ชื่อผู้เช่า', tenantName, thai11),
                pw.SizedBox(height: 3),

                // 7. ประเภทเลขที่ห้อง
                if (roomCategoryName.isNotEmpty) ...[
                  _infoRow('ประเภท', roomCategoryName, thai11),
                  pw.SizedBox(height: 3),
                ],
                _infoRow('เลขที่ห้อง', roomNumber, thai11),
                pw.SizedBox(height: 3),

                // 8. การชำระเงิน
                _infoRow('การชำระเงิน',
                    paymentMethod.isEmpty ? 'โอนชำระ' : paymentMethod, thai11),

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // 9. รายการ จำนวนเงิน #หัวข้อ
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('รายการ', style: thaiBaht),
                    pw.Text('จำนวนเงิน', style: thaiBaht),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 2),

                // 10-12. ค่าเช่า, ค่าน้ำค่าไฟ
                ..._buildItems(),

                // 13. ค่าใช้จ่ายอื่นๆ - แสดงหัวข้อถ้ามีรายการ
                if (otherCharges.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('ค่าใช้จ่ายอื่นๆ', style: thaiBaht),
                  pw.SizedBox(height: 4),
                  ..._buildOtherCharges(),
                ],

                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),

                // ค่าปรับชำระล่าช้า - แสดงก่อนยอดรวม
                _itemRow('ค่าปรับชำระล่าช้า', lateFeeAmount, thai11),
                // 15. ยอดรวม
                _totalRow('ยอดรวม', totalAmount, thaiBaht),

                pw.SizedBox(height: 12),

                // 16. SIGNATURE SECTION
                pw.Row(
                  children: [
                    // ผู้รับเงิน
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            height: 15,
                          ),
                          pw.Container(
                            height: 0.5,
                            color: PdfColors.grey600,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text('ผู้รับเงิน', style: thai10),
                          pw.Text('วันที่ชำระ', style: thai10),
                          pw.Text(paymentDate, style: thai9),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // ขอบคุณที่ใช้บริการ Thank you
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
          width: 80,
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

  static String _money(double v) => '${v.toStringAsFixed(2)} บาท';
}
