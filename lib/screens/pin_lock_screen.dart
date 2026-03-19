import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/pin_service.dart';
import '../widgets/pin_pad.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  int _attempts = 0;
  bool _error = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _verify);
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _error = false;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _verify() async {
    final ok = await PinService.verifyPin(_pin);
    if (ok) {
      widget.onUnlocked();
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() {
        _error = true;
        _pin = '';
        _attempts++;
      });

      // Trop de tentatives → effacer le PIN et retourner à l'OTP
      if (_attempts >= 5) {
        await PinService.clearPin();
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  Future<void> _forgotPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oublié votre PIN ?'),
        content: const Text(
            'Vous allez être redirigé vers la vérification par SMS pour réinitialiser votre PIN.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer')),
        ],
      ),
    );
    if (confirm == true) {
      await PinService.clearPin();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person,
                    size: 44, color: colorScheme.onPrimary),
              ),
              const SizedBox(height: 16),

              // Numéro masqué
              Text(
                _maskPhone(phone),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez votre PIN pour continuer',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant),
              ),

              const SizedBox(height: 48),

              // Dots avec animation shake
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    _error
                        ? 12 * (0.5 - _shakeAnim.value).abs() * 2 *
                            ((_shakeAnim.value * 10).round().isEven ? 1 : -1)
                        : 0,
                    0,
                  ),
                  child: child,
                ),
                child: PinDots(pin: _pin, hasError: _error),
              ),

              if (_error) ...[
                const SizedBox(height: 16),
                Text(
                  _attempts >= 4
                      ? 'Dernière tentative avant réinitialisation'
                      : 'PIN incorrect · $_attempts/5 tentative${_attempts > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: _attempts >= 4
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: _attempts >= 4
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],

              const Spacer(),

              // Pavé numérique
              PinPad(onDigit: _onDigit, onBackspace: _onBackspace),

              const SizedBox(height: 16),

              // Oublié PIN
              TextButton(
                onPressed: _forgotPin,
                child: Text(
                  'PIN oublié ?',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 5)}****${phone.substring(phone.length - 2)}';
  }
}
