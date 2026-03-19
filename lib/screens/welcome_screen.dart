import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Fond dégradé rouge ──────────────────────────────────────────
          Container(
            height: size.height * 0.55,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [Color(0xFFCC0000), Color(0xFF6B0000), Color(0xFF1A0000)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ─── Section haute (logo + titre) ────────────────────────
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo CamerMarket
                      Image.asset(
                        'assets/images/logo.png',
                        width: size.width * 0.55,
                        height: size.height * 0.25,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'LE MARCHÉ DIGITAL DU CAMEROUN',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFB300),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Stats
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatBadge(icon: Icons.shopping_cart_outlined, label: 'Acheter'),
                          SizedBox(width: 24),
                          _StatBadge(icon: Icons.storefront, label: 'Vendre'),
                          SizedBox(width: 24),
                          _StatBadge(icon: Icons.local_shipping_outlined, label: 'Livrer'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Section basse (boutons) ──────────────────────────────
                Expanded(
                  child: Container(
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
                        )
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bienvenue !',
                          style: textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Achetez, vendez et échangez avec des\ncommerçants vérifiés près de chez vous.',
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),

                        // Bouton S'inscrire
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Créer un compte'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFCC0000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bouton Se connecter
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text('Se connecter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCC0000),
                            side: const BorderSide(color: Color(0xFFCC0000), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),

                        const Spacer(),
                        Center(
                          child: Text(
                            'Transactions sécurisées · Commerçants géolocalisés',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
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

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
