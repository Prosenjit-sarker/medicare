import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_bd/core/utils/health_utils.dart';

void main() {
  test('bmi is weight / height squared', () {
    expect(bmi(70, 175)!.toStringAsFixed(1), '22.9');
    expect(bmi(null, 175), isNull);
    expect(bmi(70, 0), isNull);
  });

  test('genSlots builds equal slots inside the window', () {
    expect(genSlots('09:00', '10:30', 30), ['09:00', '09:30', '10:00']);
    expect(genSlots('09:00', '09:20', 30), isEmpty);
    expect(genSlots('09:00', '10:00', 0), isEmpty);
  });

  test('dateKey formats yyyy-MM-dd', () {
    expect(dateKey(DateTime(2026, 11, 1)), '2026-11-01');
  });
}
