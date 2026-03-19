import 'package:firebase_auth/firebase_auth.dart';

/// Lance l'auth téléphone avec un reCAPTCHA invisible (pas de widget visible).
/// firebase_auth v5 crée automatiquement un RecaptchaVerifier invisible
/// en interne quand aucun verifier n'est fourni.
Future<ConfirmationResult> signInWithPhoneInvisible(
  FirebaseAuth auth,
  String phoneNumber,
) async {
  return await auth.signInWithPhoneNumber(phoneNumber);
}
