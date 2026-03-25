import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool isLogin;
  final VoidCallback? onVerified;

  const PhoneAuthScreen({
    super.key,
    this.isLogin = true,
    this.onVerified,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

bool get _useWebAuth =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  String _dialCode = '+237';
  String? _verificationId;
  ConfirmationResult? _confirmationResult;
  bool _codeSent = false;
  bool _loading = false;
  String? _errorMessage;
  int? _resendToken;

  static const _countries = [
    (flag: '🇨🇲', name: 'Cameroun', code: '+237'),
    (flag: '🇳🇬', name: 'Nigeria', code: '+234'),
    (flag: '🇨🇮', name: "Côte d'Ivoire", code: '+225'),
    (flag: '🇬🇭', name: 'Ghana', code: '+233'),
    (flag: '🇧🇫', name: 'Burkina Faso', code: '+226'),
    (flag: '🇸🇳', name: 'Sénégal', code: '+221'),
    (flag: '🇲🇱', name: 'Mali', code: '+223'),
    (flag: '🇬🇳', name: 'Guinée', code: '+224'),
    (flag: '🇬🇦', name: 'Gabon', code: '+241'),
    (flag: '🇫🇷', name: 'France', code: '+33'),
    (flag: '🇧🇪', name: 'Belgique', code: '+32'),
    (flag: '🇨🇭', name: 'Suisse', code: '+41'),
  ];

  String get _fullPhone => '$_dialCode${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_useWebAuth) {
        _confirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber(_fullPhone);
        setState(() {
          _codeSent = true;
          _loading = false;
        });
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: _fullPhone,
          forceResendingToken: _resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential cred) async {
            // Auto-vérification Android — _ProfileCheck gère la navigation
            try {
              await FirebaseAuth.instance.signInWithCredential(cred);
            } on FirebaseAuthException catch (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _errorMessage = _mapError(e.code);
                });
              }
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _errorMessage = _mapError(e.code);
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            _resendToken = resendToken;
            setState(() {
              _codeSent = true;
              _loading = false;
            });
            if (mounted) _otpFocus.requestFocus();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = _mapError(e.code);
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) return;
    setState(() => _loading = true);

    try {
      if (_useWebAuth) {
        if (_confirmationResult == null) return;
        await _confirmationResult!.confirm(code);
      } else {
        if (_verificationId == null) return;
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (!mounted) return;
      if (widget.onVerified != null) {
        widget.onVerified!();
        return;
      }
      // _AuthGate détecte le changement et navigue via _ProfileCheck
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = _mapError(e.code);
      });
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'invalid-verification-code':
        return 'Code incorrect. Vérifiez le SMS reçu.';
      case 'session-expired':
        return 'Code expiré. Renvoyez le code.';
      case 'quota-exceeded':
        return 'Quota SMS dépassé. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      default:
        return 'Erreur ($code). Veuillez réessayer.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Titre animé ──────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _codeSent
                    ? _StepHeader(
                        key: const ValueKey('otp'),
                        icon: Icons.sms_outlined,
                        title: 'Code envoyé',
                        subtitle:
                            'Entrez le code reçu par SMS sur $_fullPhone',
                        color: colorScheme.primary,
                      )
                    : _StepHeader(
                        key: const ValueKey('phone'),
                        icon: Icons.phone_outlined,
                        title: widget.isLogin ? 'Connexion' : 'Créer un compte',
                        subtitle:
                            'Nous vous enverrons un code de vérification',
                        color: colorScheme.primary,
                      ),
              ),

              const SizedBox(height: 32),

              // ── Étape 1 : numéro ─────────────────────────────────────────
              if (!_codeSent) ...[
                _CountrySelector(
                  countries: _countries,
                  selected: _dialCode,
                  onChanged: (code) => setState(() => _dialCode = code),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: 'Numéro sans indicatif',
                    hintText: 'Ex : 699123456',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],

              // ── Étape 2 : OTP ────────────────────────────────────────────
              if (_codeSent) ...[
                TextFormField(
                  controller: _otpController,
                  focusNode: _otpFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: textTheme.headlineMedium?.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      letterSpacing: 12,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _otpController.clear();
                            }),
                    child: Text(
                      'Modifier le numéro',
                      style:
                          TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],

              // ── Erreur ───────────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: colorScheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: colorScheme.onErrorContainer,
                              fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: colorScheme.onErrorContainer, size: 16),
                        onPressed: () =>
                            setState(() => _errorMessage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Bouton principal ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      _loading ? null : (_codeSent ? _verifyCode : _sendCode),
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
                          _codeSent ? 'Vérifier le code' : 'Envoyer le code',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              // ── Renvoyer le code ─────────────────────────────────────────
              if (_codeSent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _sendCode,
                    child: Text(
                      'Renvoyer le code',
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _StepHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final List<({String flag, String name, String code})> countries;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CountrySelector({
    required this.countries,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = countries.firstWhere(
      (c) => c.code == selected,
      orElse: () => countries.first,
    );

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Text(current.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              '${current.name} (${current.code})',
              style:
                  TextStyle(color: colorScheme.onSurface, fontSize: 15),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        shrinkWrap: true,
        itemCount: countries.length,
        itemBuilder: (_, i) {
          final c = countries[i];
          return ListTile(
            leading:
                Text(c.flag, style: const TextStyle(fontSize: 22)),
            title: Text(c.name),
            trailing: Text(
              c.code,
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            selected: c.code == selected,
            selectedColor: Theme.of(context).colorScheme.primary,
            onTap: () {
              onChanged(c.code);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
