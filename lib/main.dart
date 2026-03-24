import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/camer_market_screen.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    if (kDebugMode) print('[Firebase] App déjà initialisée, on continue.');
  }

  // setLanguageCode peut bloquer sur web (requête réseau) → on ne bloque pas runApp
  FirebaseAuth.instance.setLanguageCode('fr').catchError(
    (e) => debugPrint('[Auth] setLanguageCode ignoré : $e'),
  );

  // Ne pas bloquer runApp() sur l'init des notifications (évite le freeze sur web)
  NotificationService.initialize().catchError(
    (e) => debugPrint('[FCM] Init ignorée : $e'),
  );

  runApp(const SoftMarketApp());
}

class SoftMarketApp extends StatefulWidget {
  const SoftMarketApp({super.key});

  @override
  State<SoftMarketApp> createState() => _SoftMarketAppState();
}

class _SoftMarketAppState extends State<SoftMarketApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CamerMarket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCC0000),
          brightness: Brightness.light,
          primary: const Color(0xFFCC0000),
          secondary: const Color(0xFFFFB300),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFCC0000),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCC0000),
          brightness: Brightness.dark,
          primary: const Color(0xFFCC0000),
          secondary: const Color(0xFFFFB300),
          surface: const Color(0xFF1A1A1A),
          onPrimary: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const _AuthGate(),
      // Sur desktop web : centrer le contenu dans un cadre mobile (430px max)
      builder: kIsWeb
          ? (context, child) {
              final size = MediaQuery.of(context).size;
              if (size.width <= 600) return child!;
              return ColoredBox(
                color: const Color(0xFF1A0000),
                child: Center(
                  child: SizedBox(
                    width: 430,
                    height: size.height,
                    child: ClipRect(child: child!),
                  ),
                ),
              );
            }
          : null,
    );
  }
}

// ─── Routage authentification ────────────────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Stream<User?> _authStream;
  // Fallback indépendant du stream : force la sortie du splash après N secondes
  // même si Firebase ne répond pas (iOS Safari, réseau lent, etc.)
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();

    const timeoutDuration =
        kIsWeb ? Duration(seconds: 6) : Duration(seconds: 12);
    Future.delayed(timeoutDuration, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('[AuthGate] Erreur stream auth : ${snap.error}');
        }

        // Splash seulement si on attend encore ET que le timeout n'a pas expiré
        final isWaiting =
            snap.connectionState == ConnectionState.waiting && !_timedOut;
        if (isWaiting) return const _SplashScreen();

        // Vérification stream + fallback synchrone (currentUser)
        final user = snap.data ?? FirebaseAuth.instance.currentUser;
        if (user != null) return const CamerMarketScreen();
        return const WelcomeScreen();
      },
    );
  }
}

// ─── Écran de chargement ──────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash_mobile.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
