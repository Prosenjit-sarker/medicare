import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/features/admin/admin_page.dart';
import 'package:medicare_bd/features/ambulance/ambulance_pages.dart';
import 'package:medicare_bd/features/appointments/booking_page.dart';
import 'package:medicare_bd/features/appointments/chat_page.dart';
import 'package:medicare_bd/features/articles/articles_page.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:medicare_bd/features/auth/presentation/login_page.dart';
import 'package:medicare_bd/features/auth/presentation/register_page.dart';
import 'package:medicare_bd/features/blood/blood_page.dart';
import 'package:medicare_bd/features/diagnostics/diagnostics_pages.dart';
import 'package:medicare_bd/features/doctors/doctor_dashboard.dart';
import 'package:medicare_bd/features/doctors/doctor_search_page.dart';
import 'package:medicare_bd/features/home/home_page.dart';
import 'package:medicare_bd/features/hospitals/hospitals_page.dart';
import 'package:medicare_bd/features/pharmacy/pharmacy_pages.dart';
import 'package:medicare_bd/features/prescriptions/prescription_write_page.dart';
import 'package:medicare_bd/features/prescriptions/prescriptions_page.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';
import 'package:medicare_bd/features/records/records_page.dart';
import 'package:medicare_bd/features/reminders/reminders_page.dart';
import 'package:medicare_bd/features/support/misc_pages.dart';
import 'package:medicare_bd/features/tracker/tracker_page.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

GoRoute _r(String path, Widget Function(GoRouterState) b) => GoRoute(path: path, name: path, builder: (_, s) => b(s));

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final loggedIn = auth.valueOrNull?.emailVerified ?? false;
      final onAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn) return onAuth ? null : '/login';
      return onAuth ? '/' : null;
    },
    routes: [
      _r('/', (_) => const HomePage()),
      _r('/login', (_) => const LoginPage()),
      _r('/register', (_) => const RegisterPage()),
      _r('/doctors', (_) => const DoctorSearchPage()),
      _r('/book/:id', (s) => BookingPage(doctorId: s.pathParameters['id']!)),
      _r('/chat/:id', (s) => ChatPage(appointmentId: s.pathParameters['id']!)),
      _r('/prescribe', (s) => PrescriptionWritePage(appt: s.extra! as Doc)),
      _r('/prescriptions', (_) => const PrescriptionsPage()),
      _r('/records', (_) => const RecordsPage()),
      _r('/reminders', (_) => const RemindersPage()),
      _r('/tracker', (_) => const TrackerPage()),
      _r('/hospitals', (_) => const HospitalsPage()),
      _r('/pharmacies', (_) => const PharmaciesPage()),
      _r('/diagnostics', (_) => const DiagnosticsPage()),
      _r('/blood', (_) => const BloodPage()),
      _r('/ambulance', (_) => const AmbulancePage()),
      _r('/articles', (_) => const ArticlesPage()),
      _r('/support', (_) => const SupportPage()),
      _r('/sos', (_) => const SosPage()),
      _r('/apply/:kind', (s) => ApplyPage(s.pathParameters['kind']!)),
      _r('/doctor', (_) => const DoctorDashboard()),
      _r('/hospital-dash', (_) => const HospitalDashboard()),
      _r('/pharmacy-dash', (_) => const PharmacyDashboard()),
      _r('/diagnostic-dash', (_) => const DiagnosticDashboard()),
      _r('/ambulance-dash', (_) => const AmbulanceDashboard()),
      _r('/admin', (_) => const AdminPage()),
    ],
  );
});
