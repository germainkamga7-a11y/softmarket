import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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

      UserCredential credential;
      if (kIsWeb) {
        // firebase_auth_web n'implémente pas signInWithProvider (throws UnimplementedError).
        // On utilise signInWithPopup (implémenté) ; si Safari bloque la popup,
        // on bascule sur signInWithRedirect (reload de page).
        try {
          credential = await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (popupErr) {
          if (popupErr.code == 'popup-blocked' ||
              popupErr.code == 'popup-closed-by-user' ||
              popupErr.code == 'cancelled-popup-request' ||
              popupErr.code == 'web-context-cancelled') {
            // Safari bloque la popup → redirect (la page recharge)
            await _auth.signInWithRedirect(provider);
            return SocialAuthResult.cancelled; // jamais atteint
          }
          rethrow;
        }
      } else {
        // Mobile : signInWithProvider ouvre une Activity Android / SFSafariViewController iOS
        credential = await _auth.signInWithProvider(provider);
      }

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
          e.code == 'web-context-cancelled' ||
          e.code == 'popup-blocked') {
        return SocialAuthResult.cancelled;
      }
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  /// Crée le profil Firestore pour une inscription email/password.
  /// Appelé depuis EmailAuthScreen juste après createUserWithEmailAndPassword.
  static Future<void> ensureProfileFromEmail({
    required String uid,
    required String username,
    required String email,
  }) =>
      _ensureProfile(uid: uid, username: username, phone: '', email: email);

  /// À appeler au démarrage sur web pour récupérer le résultat du redirect Google.
  /// Retourne `true` si un utilisateur vient de se connecter via redirect.
  static Future<bool> handleRedirectResult() async {
    if (!kIsWeb) return false;
    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;
      if (user == null) return false;

      await _ensureProfile(
        uid:      user.uid,
        username: user.displayName ?? 'Utilisateur Google',
        phone:    user.phoneNumber ?? '',
        email:    user.email ?? '',
      );
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
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

  // ─── Guard : compte requis ───────────────────────────────────────────────────

  /// Retourne `true` si l'utilisateur a un compte réel.
  /// Affiche un bottom sheet et retourne `false` si c'est un compte anonyme.
  static bool requireAccount(BuildContext context) {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) return true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFFCC0000)),
            const SizedBox(height: 16),
            const Text(
              'Compte requis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Créez un compte pour accéder à cette fonctionnalité et profiter de toutes les options de CamerMarket.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Déconnecte le visiteur et renvoie à l'écran de connexion
                  _auth.signOut();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Créer un compte / Se connecter'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continuer en mode visiteur'),
            ),
          ],
        ),
      ),
    );
    return false;
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
