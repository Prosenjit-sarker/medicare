import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_bd/core/data/firestore_service.dart';
import 'package:medicare_bd/core/utils/health_utils.dart';
import 'package:medicare_bd/features/auth/data/auth_repository.dart';
import 'package:medicare_bd/features/doctors/doctor_schedule.dart';

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

  test('doctor schedule shows the selected weekday hours', () {
    final doctor = Doc('doctor-1', {
      'weeklySchedule': {
        'Sat': {'startTime': '09:00', 'endTime': '13:00'},
        'Mon': {'startTime': '14:00', 'endTime': '18:00'},
      },
    });

    expect(doctorScheduleLabel(doctor, selectedDay: 'Mon'), 'Mon · 2:00 PM–6:00 PM');
    expect(doctorScheduleLabel(doctor, selectedDay: 'Tue'), 'Tue · Not available');
    final today = doctorWeekday(DateTime.now());
    expect(doctorScheduleLabel(doctor), doctorScheduleLabel(doctor, selectedDay: today));
  });

  test('doctor schedule falls back to legacy working days and hours', () {
    final doctor = Doc('doctor-1', {
      'days': ['Sun'],
      'startTime': '10:00',
      'endTime': '15:00',
    });

    expect(doctorScheduleLabel(doctor, selectedDay: 'Sun'), 'Sun · 10:00 AM–3:00 PM');
    expect(doctorScheduleLabel(doctor, selectedDay: 'Mon'), 'Mon · Not available');
  });

  test('dateKey formats yyyy-MM-dd', () {
    expect(dateKey(DateTime(2026, 11, 1)), '2026-11-01');
  });

  test('email validation accepts real-looking addresses and rejects malformed ones', () {
    expect(isValidEmailAddress('patient@gmail.com'), isTrue);
    expect(isValidEmailAddress('patient@example.org'), isTrue);
    expect(isValidEmailAddress('not-an-email'), isFalse);
    expect(isValidEmailAddress('patient@'), isFalse);
    expect(isValidEmailAddress(null), isFalse);
  });

  test('auth rate limits have a clear retry message', () {
    expect(friendlyAuthError(FirebaseAuthException(code: 'too-many-requests')), contains('Wait a while'));
  });
}
