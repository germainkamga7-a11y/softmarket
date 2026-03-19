import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/camer_market_screen.dart';
import 'screens/login_screen.dart';
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
  // Le stream est créé UNE SEULE FOIS en initState.
  // Si _AuthGate était StatelessWidget, chaque rebuild recréerait un nouveau
  // stream → StreamBuilder se réabonnait → le timeout de 10 s se réinitialisait
  // en boucle → splash infinie.
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // Timeout plus court sur web (5s) car pas de restauration locale
    final timeoutDuration =
        kIsWeb ? const Duration(seconds: 5) : const Duration(seconds: 10);
    _authStream = FirebaseAuth.instance.authStateChanges().timeout(
      timeoutDuration,
      onTimeout: (sink) => sink.add(null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          debugPrint('[AuthGate] Erreur stream auth : ${authSnapshot.error}');
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        // Utilisateur connecté → app principale
        if (authSnapshot.hasData) {
          return const CamerMarketScreen();
        }
        // Non connecté → écran de bienvenue
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
