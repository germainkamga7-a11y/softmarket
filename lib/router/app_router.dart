import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart' show navigatorKey;
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../screens/add_boutique_screen.dart';
import '../screens/boutique_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/camer_market_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/cgu_screen.dart';
import '../screens/conversations_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/help_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/order_checkout_screen.dart';
import '../screens/order_tracking_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/phone_auth_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_screen.dart';
import '../screens/security_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/cart_service.dart';
import '../services/commerce_service.dart';

// ─── Noms de routes ──────────────────────────────────────────────────────────

class Routes {
  static const welcome        = '/welcome';
  static const login          = '/login';
  static const phoneAuth      = '/phone-auth';
  static const register       = '/register';
  static const home           = '/home';
  static const boutique       = '/boutique';
  static const addBoutique    = '/add-boutique';
  static const cart           = '/cart';
  static const checkout       = '/checkout';
  static const order          = '/order/:orderId';
  static const orders         = '/orders';
  static const chat           = '/chat';
  static const conversations  = '/conversations';
  static const favorites      = '/favorites';
  static const notifications  = '/notifications';
  static const search         = '/search';
  static const security       = '/security';
  static const privacy        = '/privacy';
  static const cgu            = '/cgu';
  static const help           = '/help';
  static const forgotPassword = '/forgot-password';

  static String orderPath(String orderId) => '/order/$orderId';
}

// ─── Args pour écrans complexes ──────────────────────────────────────────────

class ChatArgs {
  final String otherUserId;
  final String otherUserName;
  final Map<String, dynamic>? productRef;
  const ChatArgs({
    required this.otherUserId,
    required this.otherUserName,
    this.productRef,
  });
}

class CheckoutArgs {
  final List<CartItem> items;
  final double total;
  const CheckoutArgs({required this.items, required this.total});
}

// ─── Routeur principal ───────────────────────────────────────────────────────

class AppRouter {
  final AppAuthProvider _auth;
  late final GoRouter router;

  AppRouter(this._auth) {
    router = GoRouter(
      navigatorKey: navigatorKey,
      refreshListenable: _auth,
      initialLocation: Routes.home,
      redirect: _redirect,
      routes: _routes,
      observers: [AnalyticsService.observer],
    );
  }

  // ─── Redirection auth ─────────────────────────────────────────────────────
  // Sync uniquement — la vérification du profil Firestore est gérée
  // dans CamerMarketScreen pour éviter un redirect async qui bloquerait.

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Routes accessibles sans être connecté
    final isPublic = location == Routes.welcome ||
        location == Routes.login ||
        location == Routes.phoneAuth ||
        location == Routes.register ||
        location == Routes.cgu ||
        location == Routes.privacy;

    // Routes d'auth pures (à quitter dès qu'on est connecté)
    final isAuthRoute = location == Routes.welcome ||
        location == Routes.login ||
        location == Routes.phoneAuth;

    if (!_auth.isLoggedIn) {
      return isPublic ? null : Routes.login;
    }

    // Connecté mais sur une route d'auth pure → redirige vers home
    // /register reste accessible aux utilisateurs connectés sans profil
    if (isAuthRoute) return Routes.home;

    return null;
  }

  // ─── Définition des routes ────────────────────────────────────────────────

  List<RouteBase> get _routes => [
        GoRoute(
          path: Routes.welcome,
          builder: (_, __) => const WelcomeScreen(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: Routes.phoneAuth,
          builder: (_, __) => const PhoneAuthScreen(),
        ),
        GoRoute(
          path: Routes.register,
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: Routes.home,
          builder: (_, __) => const CamerMarketScreen(),
        ),
        GoRoute(
          path: Routes.boutique,
          builder: (context, state) {
            final commerce = state.extra as Commerce;
            return BoutiqueScreen(commerce: commerce);
          },
        ),
        GoRoute(
          path: Routes.addBoutique,
          builder: (context, state) {
            final boutique = state.extra as Commerce?;
            return AddBoutiqueScreen(boutique: boutique);
          },
        ),
        GoRoute(
          path: Routes.cart,
          builder: (_, __) => const CartScreen(),
        ),
        GoRoute(
          path: Routes.checkout,
          builder: (context, state) {
            final args = state.extra as CheckoutArgs;
            return OrderCheckoutScreen(items: args.items, total: args.total);
          },
        ),
        GoRoute(
          path: Routes.order,
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return OrderTrackingScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: Routes.orders,
          builder: (_, __) => const OrdersListScreen(),
        ),
        GoRoute(
          path: Routes.chat,
          builder: (context, state) {
            final args = state.extra as ChatArgs;
            return ChatScreen(
              otherUserId: args.otherUserId,
              otherUserName: args.otherUserName,
              productRef: args.productRef,
            );
          },
        ),
        GoRoute(
          path: Routes.conversations,
          builder: (_, __) => const ConversationsScreen(),
        ),
        GoRoute(
          path: Routes.favorites,
          builder: (_, __) => const FavoritesScreen(),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: Routes.search,
          builder: (_, __) => const SearchScreen(),
        ),
        GoRoute(
          path: Routes.security,
          builder: (_, __) => const SecurityScreen(),
        ),
        GoRoute(
          path: Routes.privacy,
          builder: (_, __) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: Routes.cgu,
          builder: (_, __) => const CguScreen(),
        ),
        GoRoute(
          path: Routes.help,
          builder: (_, __) => const HelpScreen(),
        ),
        GoRoute(
          path: Routes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
      ];
}
