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

/// Developer-facing explanation of an anonymous sign-in failure, for debug
/// logs. The two config codes mean the Firebase project is blocking
/// sign-up, not that the phone is offline.
String explainSignInError(String code) => switch (code) {
  'admin-restricted-operation' =>
    'Firebase is blocking new accounts. In the Firebase Console -> '
        'Authentication, check Sign-in method -> Anonymous is Enabled AND '
        'Settings -> User actions -> "Enable create (sign-up)" is checked.',
  'operation-not-allowed' =>
    'The Anonymous sign-in provider is disabled. Enable it in the Firebase '
        'Console -> Authentication -> Sign-in method.',
  'network-request-failed' => 'No network connection to Firebase Auth.',
  'too-many-requests' =>
    'Firebase Auth is rate-limiting this device; wait and try again.',
  _ => 'Unexpected Firebase Auth error ($code).',
};

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
