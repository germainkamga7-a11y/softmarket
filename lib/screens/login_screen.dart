import 'package:flutter/material.dart';

import 'phone_auth_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond dégradé rouge ────────────────────────────────────────────
          Container(
            height: size.height * 0.50,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [
                  Color(0xFFCC0000),
                  Color(0xFF6B0000),
                  Color(0xFF1A0000),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Section haute (logo + tagline) ────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: size.width * 0.55,
                        height: size.height * 0.22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'LE MARCHÉ DIGITAL DU CAMEROUN',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFB300),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Section basse (boutons) ───────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bienvenue !',
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Achetez, vendez et échangez avec des\ncommerçants vérifiés près de chez vous.',
                        style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),

                      // ── Bouton téléphone (principal) ──────────────────
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PhoneAuthScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Continuer avec un numéro'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFCC0000),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Transactions sécurisées · Commerçants géolocalisés',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
