import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/camer_market_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'firebase_options.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

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

  // Crashlytics — actif seulement sur mobile (pas sur web/desktop)
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

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
    return ChangeNotifierProvider(
      create: (_) => CartService(),
      child: _buildApp(),
    );
  }

  Widget _buildApp() {
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
      navigatorKey: navigatorKey,
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
        if (user != null) return _ProfileCheck(uid: user.uid);
        return const LoginScreen();
      },
    );
  }
}

// ─── Vérification profil Firestore ───────────────────────────────────────────
// Évite que _AuthGate navigue vers CamerMarketScreen si le profil n'existe pas
// encore (ex: auto-vérification Android avant fin de l'inscription).

class _ProfileCheck extends StatelessWidget {
  final String uid;
  const _ProfileCheck({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const _SplashScreen();
        if (snap.data!.exists) return const CamerMarketScreen();
        // Profil absent → l'utilisateur est authentifié mais n'a pas
        // terminé son inscription (ex: auto-vérif Android). On reprend
        // l'inscription à l'étape mot de passe.
        return const RegisterScreen();
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
      backgroundColor: const Color(0xFFFF0000),
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 160,
        ),
      ),
    );
  }
}
