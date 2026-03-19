import 'package:firebase_auth/firebase_auth.dart';

/// Stub mobile — ne devrait jamais être appelé (le flow web est kIsWeb-guardé).
Future<ConfirmationResult> signInWithPhoneInvisible(
  FirebaseAuth auth,
  String phoneNumber,
) {
  throw UnsupportedError('signInWithPhoneInvisible est web-only');
}
