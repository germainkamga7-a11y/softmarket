import 'package:flutter/material.dart';

import '../services/pin_service.dart';
import '../widgets/pin_pad.dart';

class PinSetupScreen extends StatefulWidget {
  final VoidCallback onSetupDone;
  /// Si true, l'utilisateur active un PIN existant sur ce navigateur/appareil
  final bool isActivation;
  const PinSetupScreen({
    super.key,
    required this.onSetupDone,
    this.isActivation = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  bool _error = false;
  String? _errorMessage;

  void _onDigit(String digit) {
    setState(() {
      _error = false;
      _errorMessage = null;
    });

    if (!_confirming) {
      if (_pin.length < 4) {
        setState(() => _pin += digit);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _confirming = true);
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += digit);
        if (_confirmPin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () => _validate());
        }
      }
    }
  }

  void _onBackspace() {
    setState(() {
      _error = false;
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _validate() async {
    if (_pin == _confirmPin) {
      try {
        await PinService.savePin(_pin);
        widget.onSetupDone();
      } catch (e) {
        setState(() {
          _error = true;
          _errorMessage = 'Erreur lors de la sauvegarde du PIN.\nVérifiez votre connexion.';
          _pin = '';
          _confirmPin = '';
          _confirming = false;
        });
      }
    } else {
      setState(() {
        _error = true;
        _errorMessage = null;
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentPin = _confirming ? _confirmPin : _pin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Icône
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline,
                    size: 36, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),

              // Titre
              Text(
                _confirming
                    ? 'Confirmez votre PIN'
                    : widget.isActivation
                        ? 'Activez votre PIN'
                        : 'Créez votre PIN',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _confirming
                    ? 'Saisissez à nouveau votre PIN'
                    : widget.isActivation
                        ? 'Entrez votre PIN pour l\'activer\nsur ce navigateur'
                        : 'Ce PIN remplacera le SMS\npour vos prochaines connexions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant),
              ),

              const SizedBox(height: 48),

              // Indicateurs dots
              PinDots(pin: currentPin, hasError: _error),

              if (_error) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Les PIN ne correspondent pas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colorScheme.error, fontWeight: FontWeight.w500),
                ),
              ],

              const Spacer(),

              // Pavé numérique
              PinPad(onDigit: _onDigit, onBackspace: _onBackspace),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
