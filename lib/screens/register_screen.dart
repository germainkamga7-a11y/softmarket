import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import 'camer_market_screen.dart';
import 'cgu_screen.dart';
import 'login_screen.dart';
import 'phone_auth_screen.dart';
import 'privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Étapes : otp → password → profile
  _Step _step = _Step.otp;

  // Mot de passe
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _pwFormKey = GlobalKey<FormState>();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _savingPassword = false;
  String? _passwordError;

  // Profil
  final _nomCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  bool _savingProfile = false;
  DateTime? _dateNaissance;

  final List<String> _villes = [
    'Yaoundé', 'Douala', 'Bafoussam', 'Garoua',
    'Maroua', 'Ngaoundéré', 'Bertoua', 'Ebolowa',
    'Kribi', 'Limbe', 'Autre',
  ];
  String _villeSelected = 'Yaoundé';

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nomCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  // ─── Callback post-OTP : vérifier si compte existant ─────────────────────

  Future<void> _onOtpVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    final alreadyRegistered =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;

    if (!alreadyRegistered || !mounted) {
      setState(() => _step = _Step.password);
      return;
    }

    // Compte existant → dialog puis redirection vers LoginScreen
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte déjà existant'),
        content: const Text(
          'Ce numéro est déjà associé à un compte.\n'
          'Veuillez vous connecter avec votre mot de passe.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─── Password logic ────────────────────────────────────────────────────────

  Future<void> _savePassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });

    final error = await AuthService.linkPassword(_passwordCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _savingPassword = false;
        _passwordError = error;
      });
      return;
    }

    setState(() {
      _savingPassword = false;
      _step = _Step.profile;
    });
  }

  // ─── Profil logic ─────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 10),
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  Future<void> _saveProfile() async {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre nom d\'utilisateur')),
      );
      return;
    }
    if (_dateNaissance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre date de naissance')),
      );
      return;
    }

    setState(() => _savingProfile = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'username': _nomCtrl.text.trim(),
            'ville': _villeSelected,
            'phone': user.phoneNumber ?? '',
            'date_naissance': Timestamp.fromDate(_dateNaissance!),
            'created_at': Timestamp.now(),
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('timeout'),
          );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CamerMarketScreen()),
          (route) => false,
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _savingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réseau lent. Vérifiez votre connexion et réessayez.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_step) {
          _Step.otp => PhoneAuthScreen(
              key: const ValueKey('otp'),
              isLogin: false,
              onVerified: _onOtpVerified,
            ),
          _Step.password => _buildPasswordStep(),
          _Step.profile => _buildProfileStep(),
        },
      ),
    );
  }

  // ─── Étape Mot de passe ────────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const ValueKey('password'),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _pwFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const _StepIndicator(currentStep: 2, totalSteps: 3),
                const SizedBox(height: 24),

                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_outline, size: 36, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Créez votre mot de passe',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Il remplacera le SMS pour\nvos prochaines connexions',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

                if (_passwordError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _passwordError!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure1,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    hintText: 'Minimum 6 caractères',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Les mots de passe ne correspondent pas';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _savingPassword ? null : _savePassword,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _savingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Continuer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Étape Profil ──────────────────────────────────────────────────────────

  Widget _buildProfileStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const ValueKey('profile'),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const _StepIndicator(currentStep: 3, totalSteps: 3),
              const SizedBox(height: 24),

              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline, size: 36, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Votre profil',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Ces informations seront visibles\npar les autres utilisateurs',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 36),

              TextField(
                controller: _nomCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  hintText: 'Ex: jeankamga',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _villeSelected,
                decoration: InputDecoration(
                  labelText: 'Ville',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _villes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _villeSelected = v!),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _dateNaissance != null
                        ? DateFormat('dd/MM/yyyy').format(_dateNaissance!)
                        : 'Sélectionner une date',
                    style: TextStyle(
                      color: _dateNaissance != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Texte consentement CGU (requis Play Store)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(
                          text: 'En terminant votre inscription, vous acceptez nos '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CguScreen()),
                          ),
                          child: Text(
                            "Conditions d'utilisation",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' et notre '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen()),
                          ),
                          child: Text(
                            'Politique de confidentialité',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              FilledButton(
                onPressed: _savingProfile ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _savingProfile
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        "Terminer l'inscription",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Step { otp, password, profile }

// ─── Indicateur d'étapes ──────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: (i ~/ 2) < currentStep - 1
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        }
        final step = i ~/ 2 + 1;
        final done = step < currentStep;
        final active = step == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? colorScheme.primary : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: done || active ? colorScheme.primary : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
