class Formatmonthy {
  static const List<String> _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const List<String> _thaiMonthsShort = [
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
    'ธ.ค.',
  ];

  // ชื่อเดือนภาษาไทย (เลือกแบบย่อได้)
  static String monthName(int month, {bool short = false}) {
    final m = month.clamp(1, 12);
    return short ? _thaiMonthsShort[m - 1] : _thaiMonths[m - 1];
  }

  // รอบบิล: เดือนภาษาไทย + ปี พ.ศ.
  static String formatBillingCycleTh({required int month, required int year}) {
    final monthLabel = monthName(month);
    final thaiYear = year + 543;
    return '$monthLabel $thaiYear';
  }

  // วันที่แบบไทย (ตัวเต็ม/ตัวย่อ) จาก DateTime โดยคิดปี พ.ศ. และเวลาท้องถิ่น
  static String formatThaiDate(DateTime date, {bool shortMonth = false}) {
    final local = date.toLocal();
    final d = local.day;
    final m = local.month;
    final y = local.year + 543;
    final monthLabel = monthName(m, short: shortMonth);
    return '$d $monthLabel $y';
  }

  // รองรับ input เป็น string (เช่น 'YYYY-MM-DD' หรือ ISO), ถ้า parse ไม่ได้จะคืนค่าดั้งเดิม
  static String formatThaiDateStr(String dateStr, {bool shortMonth = false}) {
    if (dateStr.trim().isEmpty) return '-';
    // ตัดเวลาออกถ้ารูปแบบเป็น 'YYYY-MM-DD HH:mm:ss'
    final base = dateStr.split(' ').first;
    final dt = DateTime.tryParse(base);
    if (dt == null) return dateStr;
    return formatThaiDate(dt, shortMonth: shortMonth);
  }

  static String formatUtilitySubtext({
    required num previous,
    required num current,
    required num usage,
    required num unitPrice,
  }) {
    String f(num v) => v.toStringAsFixed(2);
    return '${f(previous)} - ${f(current)} = ${f(usage)} (${f(unitPrice)})';
  }

  static String formatOtherChargeLabel({
    required String name,
    required int quantity,
    required num unitPrice,
  }) {
    final qty = quantity <= 0 ? 1 : quantity;
    final unit = unitPrice.toStringAsFixed(2);
    return '$name x $qty ($unit)';
  }
}
