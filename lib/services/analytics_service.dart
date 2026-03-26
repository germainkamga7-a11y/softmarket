import 'package:firebase_analytics/firebase_analytics.dart';

/// Wrapper centralisé pour Firebase Analytics.
/// Tous les events clés de l'app passent par ici.
class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── Boutiques ──────────────────────────────────────────────────────────────

  static Future<void> logViewBoutique({
    required String commerceId,
    required String nom,
    required String categorie,
  }) =>
      _analytics.logEvent(
        name: 'view_boutique',
        parameters: {
          'commerce_id': commerceId,
          'nom': nom,
          'categorie': categorie,
        },
      );

  // ─── Produits ───────────────────────────────────────────────────────────────

  static Future<void> logViewProduct({
    required String productId,
    required String nom,
    required double prix,
    required String categorie,
  }) =>
      _analytics.logViewItem(
        currency: 'XAF',
        value: prix,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: nom,
            itemCategory: categorie,
            price: prix,
          ),
        ],
      );

  // ─── Panier ─────────────────────────────────────────────────────────────────

  static Future<void> logAddToCart({
    required String productId,
    required String nom,
    required double prix,
    required int quantite,
  }) =>
      _analytics.logAddToCart(
        currency: 'XAF',
        value: prix * quantite,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: nom,
            price: prix,
            quantity: quantite,
          ),
        ],
      );

  // ─── Commandes ──────────────────────────────────────────────────────────────

  static Future<void> logBeginCheckout({required double total}) =>
      _analytics.logBeginCheckout(
        currency: 'XAF',
        value: total,
      );

  static Future<void> logPurchase({
    required String orderId,
    required double total,
    required String modePaiement,
  }) =>
      _analytics.logPurchase(
        currency: 'XAF',
        value: total,
        transactionId: orderId,
        affiliation: modePaiement,
      );

  // ─── Auth ───────────────────────────────────────────────────────────────────

  static Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  static Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  // ─── Recherche / Carte ───────────────────────────────────────────────────────

  static Future<void> logSearch(String query) =>
      _analytics.logSearch(searchTerm: query);
}
