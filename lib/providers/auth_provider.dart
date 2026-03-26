import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Provider global pour l'état d'authentification.
/// Écoute authStateChanges() et expose les propriétés utiles
/// à toute l'arbre de widgets via context.read/watch<AuthProvider>().
class AppAuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  late final StreamSubscription<User?> _sub;

  User? _user;

  AppAuthProvider() {
    // Valeur synchrone immédiate (évite un premier frame null inutile)
    _user = _auth.currentUser;
    _sub = _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // ─── Accesseurs ─────────────────────────────────────────────────────────────

  /// Utilisateur Firebase courant (null = non connecté)
  User? get user => _user;

  /// UID de l'utilisateur courant
  String? get uid => _user?.uid;

  /// true si un utilisateur est connecté (même anonyme)
  bool get isLoggedIn => _user != null;

  /// true si l'utilisateur est en mode visiteur (compte anonyme)
  bool get isAnonymous => _user?.isAnonymous ?? true;

  /// true si l'utilisateur a un compte réel (non anonyme)
  bool get hasAccount => _user != null && !(_user!.isAnonymous);

  /// Nom d'affichage — numéro de téléphone par défaut si pas de displayName
  String get displayName =>
      _user?.displayName ??
      _user?.phoneNumber ??
      (_user?.isAnonymous == true ? 'Visiteur' : 'Utilisateur');

  /// URL photo de profil Firebase (Google ou null)
  String? get photoUrl => _user?.photoURL;

  /// Email si disponible (connexion Google)
  String? get email => _user?.email;

  // ─── Actions ────────────────────────────────────────────────────────────────

  /// Déconnecte l'utilisateur courant
  Future<void> signOut() => _auth.signOut();
}
