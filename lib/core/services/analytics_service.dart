import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only non-sensitive events. Never log diagnosis, medicines, names or phone numbers.
class AnalyticsService {
  final _a = FirebaseAnalytics.instance;
  final _c = FirebaseCrashlytics.instance;

  Future<void> onLogin(String uid) async {
    await _a.setUserId(id: uid);
    if (!kIsWeb) await _c.setUserIdentifier(uid);
    await _a.logLogin(loginMethod: 'email');
  }

  Future<void> onSignUp() => _a.logSignUp(signUpMethod: 'email');
  Future<void> onLogout() async {
    await _a.setUserId(id: null);
    if (!kIsWeb) await _c.setUserIdentifier('');
  }

  Future<void> onAppointmentBooked() => _a.logEvent(name: 'appointment_booked');
  Future<void> onScreen(String name) => _a.logScreenView(screenName: name);
}

final analyticsProvider = Provider<AnalyticsService>((_) => AnalyticsService());
