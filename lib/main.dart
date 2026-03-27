import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/commerce_provider.dart';
import 'router/app_router.dart';
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

  // Offline support : cache Firestore illimité — critique pour réseau camerounais
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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
  late final AppAuthProvider _auth;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _auth = AppAuthProvider();
    _appRouter = AppRouter(_auth);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => CommerceProvider()),
      ],
      child: _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp.router(
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
          surface: const Color(0xFF121212),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFCC0000),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2A2A2A)),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: _appRouter.router,
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

// ─── Écran de chargement (utilisé par CamerMarketScreen pendant la vérif profil)

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
