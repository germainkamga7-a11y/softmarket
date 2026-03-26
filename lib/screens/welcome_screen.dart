import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../router/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                      Image.asset(
                        'assets/images/logo.png',
                        width: size.width * 0.55,
                        height: size.height * 0.25,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.appTagline,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFB300),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatBadge(icon: Icons.shopping_cart_outlined, label: l.buy),
                          const SizedBox(width: 24),
                          _StatBadge(icon: Icons.storefront, label: l.sell),
                          const SizedBox(width: 24),
                          _StatBadge(icon: Icons.local_shipping_outlined, label: l.deliver),
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
                          l.welcome,
                          style: textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.welcomeSubtitle,
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),

                        FilledButton.icon(
                          onPressed: () => context.push(Routes.register),
                          icon: const Icon(Icons.person_add_outlined),
                          label: Text(l.createAccount),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFCC0000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: () => context.push(Routes.login),
                          icon: const Icon(Icons.login),
                          label: Text(l.signIn),
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
                            l.securityNote,
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
