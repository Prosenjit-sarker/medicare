import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authChanges() => _auth.authStateChanges();

  Stream<AppUser?> watchUser(String uid) => _db.collection('users').doc(uid).snapshots().map(
        (s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null,
      );

  Future<User> register({required String name, required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // The role is always 'patient' here. Firestore rules reject any other value.
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'role': 'patient',
      'createdAt': FieldValue.serverTimestamp(),
      'consentAt': FieldValue.serverTimestamp(),
    });
    return cred.user!;
  }

  Future<User> login(String email, String password) async =>
      (await _auth.signInWithEmailAndPassword(email: email, password: password)).user!;

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
      case 'network-request-failed':
        return 'No internet connection.';
    }
    return e.message ?? 'Authentication failed.';
  }
  return 'Something went wrong. Please try again.';
}
