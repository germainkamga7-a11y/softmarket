import 'package:flutter/material.dart';

import '../services/social_auth_service.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loadingGoogle = false;
  bool _loadingAnon   = false;

  // ─── Google ──────────────────────────────────────────────────────────────────

  Future<void> _signInGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final result = await SocialAuthService.signInWithGoogle();
      if (!mounted) return;
      if (result == SocialAuthResult.error) {
        _showError('Connexion Google échouée. Réessayez.');
      }
      // Si success → AuthGate détecte le changement et navigue automatiquement
    } catch (e) {
      if (mounted) _showError('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  // ─── Anonyme ─────────────────────────────────────────────────────────────────

  Future<void> _signInAnonymous() async {
    setState(() => _loadingAnon = true);
    try {
      await SocialAuthService.signInAnonymously();
    } catch (e) {
      if (mounted) _showError('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loadingAnon = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final size        = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond dégradé rouge ─────────────────────────────────────────────
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
                // ── Logo + tagline ─────────────────────────────────────────
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

                // ── Section boutons ────────────────────────────────────────
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
                      const SizedBox(height: 24),

                      // ── Téléphone (principal) ──────────────────────────
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
                                fontSize: 15, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Google ─────────────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _loadingGoogle ? null : _signInGoogle,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: colorScheme.outlineVariant, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loadingGoogle
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _GoogleLogo(),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Continuer avec Google',
                                      style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Séparateur ─────────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: Divider(color: colorScheme.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                          ),
                          Expanded(child: Divider(color: colorScheme.outlineVariant)),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Anonyme ────────────────────────────────────────
                      SizedBox(
                        height: 48,
                        child: TextButton.icon(
                          onPressed: _loadingAnon ? null : _signInAnonymous,
                          icon: _loadingAnon
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.visibility_off_outlined,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant),
                          label: Text(
                            'Continuer sans compte',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
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

// ─── Logo Google en SVG inline ────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;

    // Fond blanc
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.white);

    // Arcs colorés Google
    const strokeW = 3.5;
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.72);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
          arcRect, start, sweep, false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round);
    }

    // Bleu — haut
    arc(const Color(0xFF4285F4), -1.57, 1.1);
    // Rouge — bas gauche
    arc(const Color(0xFFEA4335), 3.14, 0.85);
    // Jaune — bas
    arc(const Color(0xFFFBBC05), 3.99, 0.85);
    // Vert — haut droite
    arc(const Color(0xFF34A853), -0.47, 1.0);

    // Trait horizontal (partie droite du G)
    final paint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.72, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
