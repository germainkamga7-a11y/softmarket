import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Résultat d'une connexion sociale
enum SocialAuthResult { success, cancelled, error }

class SocialAuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  // ─── Google ─────────────────────────────────────────────────────────────────

  static Future<SocialAuthResult> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      // signInWithProvider fonctionne sur web (popup) et mobile (Activity)
      final credential = await _auth.signInWithProvider(provider);

      final user = credential.user;
      if (user == null) return SocialAuthResult.error;

      await _ensureProfile(
        uid:      user.uid,
        username: user.displayName ?? 'Utilisateur Google',
        phone:    user.phoneNumber ?? '',
        email:    user.email ?? '',
      );

      return SocialAuthResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'web-context-cancelled') {
        return SocialAuthResult.cancelled;
      }
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  // ─── Anonyme ─────────────────────────────────────────────────────────────────

  static Future<SocialAuthResult> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) return SocialAuthResult.error;

    await _ensureProfile(
      uid:      user.uid,
      username: 'Visiteur',
      phone:    '',
    );

    return SocialAuthResult.success;
  }

  // ─── Création profil Firestore (si absent) ───────────────────────────────────

  static Future<void> _ensureProfile({
    required String uid,
    required String username,
    required String phone,
    String email = '',
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return; // Profil déjà créé

    await ref.set({
      'username':    username,
      'phone':       phone,
      'email':       email,
      'city':        '',
      'created_at':  Timestamp.now(),
      'is_anonymous': phone.isEmpty && email.isEmpty,
    }).timeout(const Duration(seconds: 12));
  }
}
