class InvoiceFormat {
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

  static String formatBillingCycleTh({required int month, required int year}) {
    final mIdx = month.clamp(1, 12) - 1;
    final monthName = _thaiMonths[mIdx];
    final thaiYear = year + 543;
    return '$monthName $thaiYear';
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
