import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authChanges() => _auth.userChanges();

  Stream<AppUser?> watchUser(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null);

  Future<User> register({required String name, required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = cred.user!;
    try {
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
    await _auth.signOut();
    return user;
  }

  Future<User> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    try {
      await _auth.currentUser!.reload();
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
    final user = _auth.currentUser!;
    if (!user.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'email-not-verified');
    }

    await user.getIdToken(true);
    final profile = _db.collection('users').doc(user.uid);
    if (!(await profile.get()).exists) {
      await profile.set({
        'name': user.displayName ?? 'Patient',
        'email': user.email,
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
        'consentAt': FieldValue.serverTimestamp(),
      });
    }
    return user;
  }

  Future<void> resendVerificationEmail({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    try {
      await _auth.currentUser!.reload();
      final user = _auth.currentUser!;
      if (user.emailVerified) {
        throw FirebaseAuthException(code: 'email-already-verified');
      }
      await user.sendEmailVerification();
    } finally {
      await _auth.signOut();
    }
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  Future<void> logout() => _auth.signOut();
}

String friendlyAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Use a password of at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-not-verified':
        return 'Verify your email before signing in. Check your inbox and spam folder.';
      case 'email-already-verified':
        return 'Your email is verified. Sign in to continue.';
      case 'too-many-requests':
        return 'Too many attempts from this device. Wait a while before trying again.';
      case 'network-request-failed':
        return 'No internet connection.';
    }
    return e.message ?? 'Authentication failed.';
  }
  return 'Something went wrong. Please try again.';
}

bool isValidEmailAddress(String? value) =>
    value != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
