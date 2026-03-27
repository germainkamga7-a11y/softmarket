import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/social_auth_service.dart';

/// Authentification par email + mot de passe.
///
/// Deux modes selon [isLogin] :
///  - Connexion  → email + mot de passe
///  - Inscription → nom + email + mot de passe + confirmation
///
/// Après inscription, un email de vérification est envoyé.
/// L'utilisateur doit cliquer sur le lien avant de pouvoir se connecter.
class EmailAuthScreen extends StatefulWidget {
  final bool isLogin;

  const EmailAuthScreen({super.key, this.isLogin = true});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  late bool _isLogin;
  bool _loading       = false;
  bool _obscurePass   = true;
  bool _obscureConf   = true;
  bool _emailSent     = false; // true après inscription réussie
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ─── Connexion ────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!cred.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _loading = false;
            _error   = 'Email non vérifié. Consultez votre boîte mail '
                       'et cliquez sur le lien de confirmation.';
          });
        }
        return;
      }
      AnalyticsService.logLogin('email');
      // go_router redirige automatiquement vers /home via AuthGate
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = _mapError(e.code); });
    }
  }

  // ─── Inscription ──────────────────────────────────────────────────────────

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final user = cred.user!;

      // Mettre à jour le displayName
      await user.updateDisplayName(_nameCtrl.text.trim());

      // Créer le profil Firestore
      await SocialAuthService.ensureProfileFromEmail(
        uid:      user.uid,
        username: _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
      );

      // Envoyer l'email de vérification
      await user.sendEmailVerification();

      // Déconnecter l'utilisateur tant qu'il n'a pas vérifié son email
      await FirebaseAuth.instance.signOut();

      AnalyticsService.logSignUp('email');
      if (mounted) setState(() { _loading = false; _emailSent = true; });
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = _mapError(e.code); });
    }
  }

  // ─── Renvoyer l'email de vérification ────────────────────────────────────

  Future<void> _resendVerification() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de vérification renvoyé.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Réinitialisation mot de passe ───────────────────────────────────────

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entrez votre email pour réinitialiser le mot de passe.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de réinitialisation envoyé à $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.code));
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé. Connectez-vous.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible (min 6 caractères).';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      default:
        return 'Erreur ($code). Veuillez réessayer.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _emailSent
            ? _buildEmailSentState(colorScheme, textTheme)
            : _buildForm(colorScheme, textTheme),
      ),
    );
  }

  // ─── Écran "email envoyé" ─────────────────────────────────────────────────

  Widget _buildEmailSentState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_unread_outlined,
                  color: cs.primary, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Vérifiez votre email',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Un lien de confirmation a été envoyé à\n'
              '${_emailCtrl.text.trim()}\n\n'
              'Cliquez sur ce lien pour activer votre compte, '
              'puis revenez vous connecter.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  _emailSent = false;
                  _isLogin   = true;
                }),
                icon: const Icon(Icons.login),
                label: const Text('Se connecter',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loading ? null : _resendVerification,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Renvoyer l\'email'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Formulaire ──────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Titre ──
            Row(
              children: [
                Icon(Icons.email_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  _isLogin ? 'Connexion' : 'Créer un compte',
                  style: tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isLogin
                  ? 'Connectez-vous avec votre email et mot de passe.'
                  : 'Remplissez le formulaire — vous recevrez un email de confirmation.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            // ── Nom (inscription seulement) ──
            if (!_isLogin) ...[
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  hintText: 'Prénom NOM',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Nom requis (min 2 caractères)'
                    : null,
              ),
              const SizedBox(height: 14),
            ],

            // ── Email ──
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Adresse email',
                hintText: 'exemple@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── Mot de passe ──
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                hintText: _isLogin ? '' : 'Min 6 caractères',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (!_isLogin && v.length < 6) {
                  return 'Min 6 caractères';
                }
                return null;
              },
            ),

            // ── Mot de passe oublié (connexion seulement) ──
            if (_isLogin) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text('Mot de passe oublié ?',
                      style: TextStyle(color: cs.primary, fontSize: 13)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              // ── Confirmer mot de passe ──
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConf,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConf
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureConf = !_obscureConf),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                validator: (v) => v != _passCtrl.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              const SizedBox(height: 8),
            ],

            // ── Erreur ──
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: cs.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: cs.onErrorContainer, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: cs.onErrorContainer, size: 16),
                      onPressed: () => setState(() => _error = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Bouton principal ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : (_isLogin ? _signIn : _signUp),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isLogin ? 'Se connecter' : 'Créer mon compte',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Basculer connexion / inscription ──
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isLogin = !_isLogin;
                  _error   = null;
                }),
                child: RichText(
                  text: TextSpan(
                    style: tt.bodyMedium,
                    children: [
                      TextSpan(
                        text: _isLogin
                            ? 'Pas encore de compte ? '
                            : 'Déjà un compte ? ',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      TextSpan(
                        text: _isLogin ? 'S\'inscrire' : 'Se connecter',
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
