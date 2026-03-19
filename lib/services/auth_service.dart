import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static String emailFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'cm$digits@camermarket.app';
  }

  /// Lie un mot de passe email/password à l'utilisateur Phone Auth actuel.
  /// Appelé juste après OTP lors de l'inscription.
  static Future<String?> linkPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utilisateur non connecté';
    final phone = user.phoneNumber ?? '';
    if (phone.isEmpty) return 'Numéro de téléphone non disponible';
    final email = emailFromPhone(phone);
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      debugPrint('[AuthService] Credential lié avec succès.');
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        // Un compte existe déjà pour ce numéro — ne pas écraser le mot de passe
        return 'Ce numéro est déjà associé à un compte. Connectez-vous avec votre mot de passe.';
      }
      return _mapError(e.code);
    }
  }

  /// Connexion directe numéro + mot de passe (sans OTP).
  static Future<String?> signInWithPhone(String phone, String password) async {
    final email = emailFromPhone(phone.replaceAll(' ', ''));
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  /// Mise à jour du mot de passe — l'utilisateur doit être authentifié (ex: après OTP).
  static Future<String?> updatePassword(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utilisateur non connecté';

    final hasEmail = user.providerData.any((p) => p.providerId == 'password');

    if (!hasEmail) {
      // Pas encore de credential email/password → le créer via linkWithCredential
      final phone = user.phoneNumber ?? '';
      if (phone.isEmpty) return 'Numéro de téléphone non disponible';
      final email = emailFromPhone(phone);
      try {
        await user.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: newPassword),
        );
        return null;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked' ||
            e.code == 'email-already-in-use' ||
            e.code == 'credential-already-in-use') {
          // Credential déjà lié mais pas détecté dans providerData → update direct
          try {
            await user.updatePassword(newPassword);
            return null;
          } on FirebaseAuthException catch (e2) {
            return _mapError(e2.code);
          }
        }
        return _mapError(e.code);
      }
    }

    try {
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  static String _mapError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect';
      case 'user-not-found':
        return 'Aucun compte trouvé pour ce numéro.\nInscrivez-vous d\'abord.';
      case 'operation-not-allowed':
        return 'Connexion par mot de passe non activée (contacter le support)';
      case 'weak-password':
        return 'Mot de passe trop faible (minimum 6 caractères)';
      case 'network-request-failed':
        return 'Pas de connexion internet';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      default:
        return 'Erreur : $code';
    }
  }
}
