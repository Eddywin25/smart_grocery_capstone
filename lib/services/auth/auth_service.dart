import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anonymous Firebase Auth. Every Cloud Function in `backend/functions`
/// rejects calls without a signed-in user, so call [ensureSignedIn] before
/// each one. That also recovers if the best-effort sign-in at app startup
/// failed (e.g. the phone was offline).
class AuthService {
  AuthService({this._auth});

  final FirebaseAuth? _auth;

  // Resolved lazily so tests that never sign in don't touch Firebase.
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  Future<void> ensureSignedIn() async {
    if (_firebaseAuth.currentUser != null) return;
    await _firebaseAuth.signInAnonymously();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
