import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _keyPin = 'user_pin';
  static const _keyPinSet = 'pin_configured';
  static const _keyEmail = 'user_email';
  static const _keyPhone = 'user_phone';
  static const _keyFirebaseLinked = 'pin_firebase_linked';

  /// Valeur spéciale retournée quand le credential Firebase n'existe pas
  /// → l'appelant doit rediriger vers l'OTP
  static const otpRequired = '__otp_required__';

  // Firebase exige un mot de passe ≥ 6 caractères — on encode le PIN en interne
  static String _toFirebasePassword(String pin) => 'CM_${pin}_$pin';

  // Email basé sur le numéro de téléphone pour compatibilité cross-appareil
  static String _emailFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'cm$digits@camermarket.app';
  }

  static Future<bool> hasPinSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPinSet) ?? false;
  }

  /// Sauvegarde le PIN et tente de lier un credential email/password à Firebase
  /// pour permettre la connexion sans OTP (compatible cross-appareil)
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser!;
    final phone = user.phoneNumber ?? '';

    final email = _emailFromPhone(phone);
    final firebasePassword = _toFirebasePassword(pin);

    // Tentative de lien Firebase — non bloquant
    bool firebaseLinked = false;
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: firebasePassword),
      );
      firebaseLinked = true;
      debugPrint('[PinService] Credential Firebase lié avec succès.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        // Déjà lié → on met à jour le mot de passe Firebase silencieusement
        try {
          await user.updatePassword(firebasePassword);
          firebaseLinked = true;
        } on FirebaseAuthException {
          // Nécessite re-auth récente → on tente quand même de se connecter
          firebaseLinked = true; // On suppose que le credential existe déjà
        }
      } else {
        // operation-not-allowed, network, captcha… → PIN local seulement
        debugPrint('[PinService] linkWithCredential ignoré : ${e.code}');
      }
    } catch (e) {
      debugPrint('[PinService] Erreur non-Firebase ignorée : $e');
    }

    // Sauvegarde locale (toujours effectuée)
    await prefs.setString(_keyPin, pin);
    await prefs.setBool(_keyPinSet, true);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPhone, phone);
    await prefs.setBool(_keyFirebaseLinked, firebaseLinked);
  }

  /// Connexion directe avec numéro de téléphone + PIN (sans OTP)
  /// Retourne null si succès, [otpRequired] si Firebase n'a pas le credential,
  /// ou un message d'erreur lisible sinon.
  static Future<String?> signInWithPhoneAndPin(String phone, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_keyPhone) ?? '';
    String email = prefs.getString(_keyEmail) ?? '';
    final cleanInput = phone.replaceAll(' ', '');

    if (email.isEmpty) {
      // Pas de données locales → dériver l'email du numéro (cross-appareil)
      email = _emailFromPhone(cleanInput);
    } else {
      // Données locales présentes → vérification locale
      final cleanStored = storedPhone.replaceAll(' ', '');
      if (cleanInput != cleanStored) {
        return 'PIN non configuré sur cet appareil';
      }
      final localOk = await verifyPin(pin);
      if (!localOk) return 'PIN incorrect';

      // PIN local OK — vérifier si le credential Firebase existe
      final firebaseLinked = prefs.getBool(_keyFirebaseLinked) ?? false;
      if (!firebaseLinked) {
        // Credential jamais lié → forcer reconnexion OTP pour le recréer
        debugPrint('[PinService] Credential Firebase manquant → OTP requis');
        await clearPin();
        return otpRequired;
      }
    }

    // Authentification Firebase
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _toFirebasePassword(pin),
      );

      // Sauvegarder localement après succès cross-appareil
      if (prefs.getString(_keyEmail) == null) {
        await prefs.setString(_keyPin, pin);
        await prefs.setBool(_keyPinSet, true);
        await prefs.setString(_keyEmail, email);
        await prefs.setString(_keyPhone, cleanInput);
        await prefs.setBool(_keyFirebaseLinked, true);
      }

      return null; // succès
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'PIN incorrect';
        case 'user-not-found':
          // Credential Firebase absent → effacer et forcer OTP
          await clearPin();
          return otpRequired;
        case 'operation-not-allowed':
          // Provider Email/Password non activé → forcer OTP
          await clearPin();
          return otpRequired;
        case 'network-request-failed':
          return 'Pas de connexion internet';
        default:
          return 'Erreur de connexion (${e.code})';
      }
    }
  }

  /// Retourne le numéro de téléphone stocké localement
  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyPin);

    // Vérification locale d'abord
    if (saved != null) return saved == pin;

    // Pas de PIN local → vérification Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final phone = user.phoneNumber ?? prefs.getString(_keyPhone) ?? '';
    if (phone.isEmpty) return false;
    final email = _emailFromPhone(phone);
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _toFirebasePassword(pin),
      );
      await user.reauthenticateWithCredential(credential);
      await prefs.setString(_keyPin, pin);
      await prefs.setBool(_keyPinSet, true);
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyPhone, phone);
      await prefs.setBool(_keyFirebaseLinked, true);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPin);
    await prefs.remove(_keyPinSet);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyFirebaseLinked);
  }
}
