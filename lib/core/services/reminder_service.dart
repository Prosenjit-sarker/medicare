import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Device-side medicine reminders. They keep firing without internet.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();
  final _p = FlutterLocalNotificationsPlugin();
  static const _slots = {'morning': 8, 'afternoon': 14, 'night': 21};

  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  /// Re-schedules every active reminder (daily, repeating). Ended reminders are skipped.
  Future<void> sync(List<Doc> reminders) async {
    if (kIsWeb) return;
    await _p.cancelAll();
    final today = todayKey();
    var n = 0;
    for (final r in reminders) {
      final end = r.s('endDate');
      if (end.isNotEmpty && end.compareTo(today) < 0) continue;
      for (final e in _slots.entries) {
        if (!r.b(e.key)) continue;
        final now = tz.TZDateTime.now(tz.local);
        var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, e.value);
        if (when.isBefore(now)) when = when.add(const Duration(days: 1));
        await _p.zonedSchedule(
          n++,
          'Medicine time (${e.key})',
          '${r.s('name')} ${r.s('dose')}',
          when,
          const NotificationDetails(
            android: AndroidNotificationDetails('meds', 'Medicine reminders', importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }
}

/// Watched by the home page: whenever reminders change, local notifications are re-synced.
final reminderSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;
  ref.listen(docsProvider(q('medicine_reminders', f1: 'userId', v1: uid, limit: 100)), (_, next) {
    next.whenData(ReminderService.instance.sync);
  }, fireImmediately: true);
});
