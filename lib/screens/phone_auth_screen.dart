import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'camer_market_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool isLogin;
  final VoidCallback? onVerified;
  final String? initialPhone;

  const PhoneAuthScreen({
    super.key,
    this.isLogin = false,
    this.onVerified,
    this.initialPhone,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

// Web + desktop utilisent signInWithPhoneNumber (reCAPTCHA / même SDK)
bool get _useWebAuth =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _auth = FirebaseAuth.instance;
  late final _phoneController = TextEditingController(
      text: widget.initialPhone ?? '+237');
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _verificationId;
  ConfirmationResult? _confirmationResult; // Pour Flutter Web
  bool _codeSent = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ─── Envoi du code SMS ─────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.replaceAll(' ', '').trim();

    try {
      if (_useWebAuth) {
        _confirmationResult = await _auth.signInWithPhoneNumber(phone);

        setState(() {
          _codeSent = true;
          _loading = false;
        });
        _showSnack('Code envoyé au $phone');
      } else {
        // Mobile (Android / iOS)
        await _auth.verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-vérification Android : signer silencieusement
            // L'_AuthGate détectera le changement d'état et naviguera
            try {
              await _auth.signInWithCredential(credential);
            } on FirebaseAuthException catch (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _errorMessage = e.message ?? 'Erreur auto-vérification';
                });
              }
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _errorMessage = e.message ?? 'Erreur de vérification';
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _loading = false;
            });
            _showSnack('Code envoyé au $phone');
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message ?? 'Erreur lors de l\'envoi du code';
      });
    }
  }

  // ─── Vérification du code OTP ──────────────────────────────────────────────

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (_useWebAuth) {
        if (_confirmationResult == null) return;
        await _confirmationResult!.confirm(_otpController.text.trim());
      } else {
        if (_verificationId == null) return;
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _otpController.text.trim(),
        );
        await _auth.signInWithCredential(credential);
      }
      if (widget.onVerified != null) {
        widget.onVerified!();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CamerMarketScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message ?? 'Code incorrect';
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.isLogin
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: widget.isLogin ? 16 : 48),

                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.isLogin ? Icons.login : Icons.person_add_outlined,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  widget.isLogin ? 'Connexion' : 'Créer un compte',
                  style: textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Entrez le code reçu par SMS'
                      : widget.isLogin
                          ? 'Entrez votre numéro pour recevoir un code SMS'
                          : 'Entrez votre numéro pour créer votre compte',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.onErrorContainer, size: 18),
                          onPressed: () => setState(() => _errorMessage = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_codeSent) ...[
                  // Champ numéro de téléphone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: '+237 6XX XXX XXX',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 12) {
                        return 'Entrez un numéro valide (ex: +237 6XXXXXXXX)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _sendCode,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_loading
                        ? 'Envoi en cours...'
                        : widget.isLogin
                            ? 'Recevoir le code de connexion'
                            : 'Recevoir le code d\'inscription'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ] else ...[
                  // Champ code OTP
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall
                        ?.copyWith(letterSpacing: 12),
                    decoration: const InputDecoration(
                      labelText: 'Code à 6 chiffres',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.length != 6) {
                        return 'Le code doit contenir 6 chiffres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _verifyCode,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_loading ? 'Vérification...' : 'Confirmer'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _codeSent = false;
                      _otpController.clear();
                    }),
                    child: const Text('Changer de numéro'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
