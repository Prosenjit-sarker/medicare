import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authRepositoryProvider).authChanges());

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(user.uid);
});

/// Handles login / register / reset / logout. UI only watches its AsyncValue.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final u = await ref.read(authRepositoryProvider).login(email, password);
      await ref.read(analyticsProvider).onLogin(u.uid);
    });
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final u = await ref.read(authRepositoryProvider).register(name: name, email: email, password: password);
      await ref.read(analyticsProvider).onSignUp();
      await ref.read(analyticsProvider).onLogin(u.uid);
    });
  }

  Future<void> reset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).resetPassword(email));
  }

  Future<void> logout() async {
    await ref.read(analyticsProvider).onLogout();
    await ref.read(authRepositoryProvider).logout();
  }
}

final authControllerProvider = AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);
