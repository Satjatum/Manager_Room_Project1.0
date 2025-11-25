import 'package:flutter_test/flutter_test.dart';
import 'package:manager_room_project/utils/formatMonthy.dart';

void main() {
  group('Formatmonthy', () {
    test('formatBillingCycleTh uses BE year (+543)', () {
      // 2025 -> 2568
      final s = Formatmonthy.formatBillingCycleTh(month: 1, year: 2025);
      expect(s.contains('2568'), true,
          reason: 'ควรแสดงปี พ.ศ. (+543) ตามมาตรฐานไทย');
    });

    test('formatThaiDateStr handles empty/invalid input safely', () {
      expect(Formatmonthy.formatThaiDateStr(''), '-');
      // invalid -> return original (OWASP: fail-safe defaults, ไม่พังเมื่อข้อมูลผิดรูปแบบ)
      const invalid = 'not-a-date';
      expect(Formatmonthy.formatThaiDateStr(invalid), invalid);
    });

    test('month short name is compact', () {
      expect(Formatmonthy.monthName(1, short: true), 'ม.ค.');
    });
  });
}
