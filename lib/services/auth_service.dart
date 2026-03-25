import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  /// Mise à jour du mot de passe — l'utilisateur doit être authentifié.
  static Future<String?> updatePassword(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utilisateur non connecté';

    try {
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] updatePassword error: ${e.code}');
      return _mapError(e.code);
    }
  }

  static String _mapError(String code) {
    switch (code) {
      case 'weak-password':
        return 'Mot de passe trop faible (minimum 6 caractères)';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter avant de changer le mot de passe.';
      case 'network-request-failed':
        return 'Pas de connexion internet';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      default:
        return 'Erreur : $code';
    }
  }
}
