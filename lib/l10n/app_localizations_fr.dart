// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'CamerMarket';

  @override
  String get appTagline => 'LE MARCHÉ DIGITAL DU CAMEROUN';

  @override
  String get welcome => 'Bienvenue !';

  @override
  String get welcomeSubtitle =>
      'Achetez, vendez et échangez avec des\ncommerçants vérifiés près de chez vous.';

  @override
  String get securityNote =>
      'Transactions sécurisées · Commerçants géolocalisés';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signIn => 'Se connecter';

  @override
  String get continueWithPhone => 'Continuer avec un numéro';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueAsVisitor => 'Continuer en tant que visiteur';

  @override
  String get buy => 'Acheter';

  @override
  String get sell => 'Vendre';

  @override
  String get deliver => 'Livrer';

  @override
  String get navMap => 'Market';

  @override
  String get navHome => 'Accueil';

  @override
  String get navOrders => 'Commandes';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navProfile => 'Profil';

  @override
  String get searchHint => 'Rechercher un marché, produit...';

  @override
  String get searchMapHint => 'Rechercher sur la carte...';

  @override
  String get addCommerce => 'Ajouter mon commerce';

  @override
  String get visitBoutique => 'Visiter la boutique';

  @override
  String get contactSeller => 'Contacter le commerçant';

  @override
  String nearbySection(int count, String plural) {
    return 'À proximité · $count commerce$plural';
  }

  @override
  String get filterAll => 'Tous';

  @override
  String get filterButton => 'Filtres';

  @override
  String filterWithCount(int count) {
    return 'Filtres ($count)';
  }

  @override
  String get gpsActive => 'GPS actif';

  @override
  String get offlineError => 'Erreur réseau. Données en cache affichées.';

  @override
  String get retry => 'Réessayer';

  @override
  String get anonBannerText => 'Mode visiteur — Créez un compte pour commander';

  @override
  String get profileTitle => 'Profil';

  @override
  String get myShops => 'Mes boutiques & établissements';

  @override
  String get create => 'Créer';

  @override
  String get noShop => 'Aucune boutique';

  @override
  String get noShopSubtitle => 'Créez votre première boutique ou établissement';

  @override
  String get settings => 'Paramètres';

  @override
  String get messages => 'Messages';

  @override
  String get myOrders => 'Mes commandes';

  @override
  String get notifications => 'Notifications';

  @override
  String get securityPin => 'Sécurité & PIN';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get helpSupport => 'Aide & Support';

  @override
  String get signOut => 'Déconnexion';

  @override
  String get signOutConfirm => 'Confirmer la déconnexion';

  @override
  String get signOutMessage => 'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get cartTitle => 'Mon panier';

  @override
  String get cartEmpty => 'Votre panier est vide';

  @override
  String get cartEmptySubtitle => 'Ajoutez des produits depuis les boutiques';

  @override
  String get cartClear => 'Vider le panier';

  @override
  String get cartClearConfirm => 'Vider le panier ?';

  @override
  String get cartTotal => 'Total';

  @override
  String get proceedToCheckout => 'Passer la commande';

  @override
  String get orderTrackingTitle => 'Suivi de commande';

  @override
  String get orderStatusEnAttente => 'En attente';

  @override
  String get orderStatusConfirmee => 'Confirmée';

  @override
  String get orderStatusEnLivraison => 'En livraison';

  @override
  String get orderStatusLivree => 'Livrée';

  @override
  String get orderStatusAnnulee => 'Annulée';

  @override
  String get cancelOrder => 'Annuler la commande';

  @override
  String get ordersListTitle => 'Mes commandes';

  @override
  String get ordersEmpty => 'Aucune commande pour l\'instant';

  @override
  String get ordersEmptySubtitle => 'Vos commandes apparaîtront ici';

  @override
  String get favoritesTitle => 'Mes favoris';

  @override
  String get favoritesEmpty => 'Aucun favori pour l\'instant';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchNoResult => 'Aucun résultat';

  @override
  String get checkoutTitle => 'Passer la commande';

  @override
  String get checkoutAddress => 'Adresse de livraison';

  @override
  String get checkoutAddressHint => 'Quartier, rue, point de repère...';

  @override
  String get checkoutPhone => 'Numéro de téléphone';

  @override
  String get checkoutPhoneHint => '6XX XXX XXX';

  @override
  String get checkoutPayment => 'Mode de paiement';

  @override
  String get checkoutPayCash => 'Paiement à la livraison';

  @override
  String get checkoutConfirm => 'Confirmer la commande';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get errorNetwork => 'Erreur réseau. Vérifiez votre connexion.';

  @override
  String get errorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get share => 'Partager';

  @override
  String get report => 'Signaler';

  @override
  String get verified => 'Vérifié';

  @override
  String get shopType_boutique => 'Boutique';

  @override
  String get shopType_etablissement => 'Établissement';

  @override
  String addedToCart(String name) {
    return '$name ajouté au panier';
  }

  @override
  String get viewCart => 'Voir panier';

  @override
  String get requireAccountTitle => 'Compte requis';

  @override
  String get requireAccountMessage =>
      'Créez un compte pour accéder à cette fonctionnalité.';

  @override
  String get cguTitle => 'Conditions d\'utilisation';

  @override
  String get privacyTitle => 'Politique de confidentialité';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get helpTitle => 'Aide & Support';

  @override
  String get orDivider => 'ou';

  @override
  String get continueWithoutAccount => 'Continuer sans compte';

  @override
  String get errorGoogleSignIn => 'Connexion Google échouée. Réessayez.';

  @override
  String get registerTitle => 'Votre profil';

  @override
  String get registerSubtitle =>
      'Ces informations seront visibles\npar les autres utilisateurs';

  @override
  String get usernameLabel => 'Nom d\'utilisateur';

  @override
  String get usernameHint => 'Ex: jeankamga';

  @override
  String get cityLabel => 'Ville';

  @override
  String get birthDateLabel => 'Date de naissance';

  @override
  String get selectDate => 'Sélectionner une date';

  @override
  String get termsPrefix =>
      'En terminant votre inscription, vous acceptez nos ';

  @override
  String get termsAnd => ' et notre ';

  @override
  String get finishRegistration => 'Terminer l\'inscription';

  @override
  String get usernameRequired => 'Veuillez entrer votre nom d\'utilisateur';

  @override
  String get birthDateRequired => 'Veuillez entrer votre date de naissance';

  @override
  String get slowNetwork =>
      'Réseau lent. Vérifiez votre connexion et réessayez.';

  @override
  String get cartClearShort => 'Vider';

  @override
  String get cartClearConfirmMessage => 'Supprimer tous les articles ?';

  @override
  String get checkoutButtonCOD => 'Commander — Paiement à la livraison';

  @override
  String get cartItemWord => 'article';

  @override
  String get notProvided => 'Non renseignée';

  @override
  String get memberSince => 'Membre depuis';

  @override
  String get signOutButton => 'Se déconnecter';

  @override
  String get signOutDialogTitle => 'Déconnexion';

  @override
  String get commerceDeleted => 'Commerce supprimé';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get visitShop => 'Voir la boutique';

  @override
  String get loadShopsError => 'Impossible de charger les boutiques';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get navExplore => 'Explorer';

  @override
  String get favoritesEmptyHint =>
      'Appuyez sur ♡ dans une boutique\npour l\'ajouter à vos favoris';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get noConversation => 'Aucune conversation';

  @override
  String get noConversationHint =>
      'Contactez un commerçant\npour démarrer une conversation';

  @override
  String get justNow => 'À l\'instant';

  @override
  String get orderConfirmedTitle => 'Commande confirmée !';

  @override
  String get orderNotFound => 'Commande introuvable.';

  @override
  String get orderTrackingSection => 'Suivi';

  @override
  String get deliveryLabel => 'Livraison';

  @override
  String get contactLabel => 'Contact';

  @override
  String get paymentLabel => 'Paiement';

  @override
  String get paymentCODLabel => 'À la livraison (espèces)';

  @override
  String get cancelOrderDialogTitle => 'Annuler la commande ?';

  @override
  String get irreversibleAction => 'Cette action est irréversible.';

  @override
  String get yesCancelOrder => 'Oui, annuler';

  @override
  String get orderStatusSubtitleEnAttente =>
      'En attente de confirmation du vendeur';

  @override
  String get orderStatusSubtitleConfirmee =>
      'Le vendeur a confirmé votre commande';

  @override
  String get orderStatusSubtitleEnLivraison => 'Votre commande est en route !';

  @override
  String get orderStatusSubtitleLivree => 'Commande livrée avec succès';

  @override
  String itemsWithCount(int count) {
    return 'Articles ($count)';
  }

  @override
  String get checkoutFinalizeTitle => 'Finaliser la commande';

  @override
  String get checkoutSummary => 'Récapitulatif';

  @override
  String get checkoutPayCashSubtitle => 'Vous payez en espèces à la réception';

  @override
  String get checkoutDeliveryInfo => 'Informations de livraison';

  @override
  String get checkoutAddressRequired => 'Adresse requise';

  @override
  String get checkoutAddressTooShort => 'Adresse trop courte';

  @override
  String get checkoutPhoneRequired => 'Numéro requis';

  @override
  String get checkoutPhoneInvalid => 'Numéro invalide';

  @override
  String get processing => 'Traitement…';

  @override
  String get checkoutTermsNote =>
      'En confirmant, vous acceptez d\'être contacté par le vendeur pour organiser la livraison.';

  @override
  String get searchBarHint => 'Rechercher un commerçant, un produit...';

  @override
  String get searchRecentMerchants => 'Commerçants récents';

  @override
  String get searchNoMerchant => 'Aucun commerçant enregistré';

  @override
  String searchNoResultFor(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String get searchNoResultHint =>
      'Essayez un autre nom, catégorie ou description';

  @override
  String searchResultCount(int count, String plural) {
    return '$count résultat$plural';
  }

  @override
  String get phoneCodeSent => 'Code envoyé';

  @override
  String phoneCodeSentSubtitle(String phone) {
    return 'Entrez le code reçu par SMS sur $phone';
  }

  @override
  String get phoneSendCodeSubtitle =>
      'Nous vous enverrons un code de vérification';

  @override
  String get phoneWithoutDialCode => 'Numéro sans indicatif';

  @override
  String get phoneHint => 'Ex : 699123456';

  @override
  String get phoneVerifyCode => 'Vérifier le code';

  @override
  String get phoneSendCode => 'Envoyer le code';

  @override
  String get phoneResendCode => 'Renvoyer le code';

  @override
  String get phoneChangeNumber => 'Modifier le numéro';

  @override
  String get notifSectionActivity => 'Activité';

  @override
  String get notifMessagesSubtitle => 'Nouveaux messages des commerçants';

  @override
  String get notifNewProducts => 'Nouveaux produits';

  @override
  String get notifNewProductsSubtitle =>
      'Produits ajoutés par vos boutiques favorites';

  @override
  String get notifReviews => 'Avis & Notes';

  @override
  String get notifReviewsSubtitle => 'Nouveaux avis sur votre boutique';

  @override
  String get notifSectionMarketing => 'Marketing';

  @override
  String get notifPromos => 'Promotions & Offres';

  @override
  String get notifPromosSubtitle => 'Offres spéciales et réductions';

  @override
  String get notifSystemNote =>
      'Les notifications système (sécurité, compte) sont toujours activées.';
}
