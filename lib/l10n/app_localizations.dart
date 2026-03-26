import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Application name
  ///
  /// In fr, this message translates to:
  /// **'CamerMarket'**
  String get appName;

  /// App tagline displayed on splash / auth screens
  ///
  /// In fr, this message translates to:
  /// **'LE MARCHÉ DIGITAL DU CAMEROUN'**
  String get appTagline;

  /// No description provided for @welcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue !'**
  String get welcome;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Achetez, vendez et échangez avec des\ncommerçants vérifiés près de chez vous.'**
  String get welcomeSubtitle;

  /// No description provided for @securityNote.
  ///
  /// In fr, this message translates to:
  /// **'Transactions sécurisées · Commerçants géolocalisés'**
  String get securityNote;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @continueWithPhone.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec un numéro'**
  String get continueWithPhone;

  /// No description provided for @continueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// No description provided for @continueAsVisitor.
  ///
  /// In fr, this message translates to:
  /// **'Continuer en tant que visiteur'**
  String get continueAsVisitor;

  /// No description provided for @buy.
  ///
  /// In fr, this message translates to:
  /// **'Acheter'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In fr, this message translates to:
  /// **'Vendre'**
  String get sell;

  /// No description provided for @deliver.
  ///
  /// In fr, this message translates to:
  /// **'Livrer'**
  String get deliver;

  /// No description provided for @navMap.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get navMap;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navOrders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get navOrders;

  /// No description provided for @navFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get navFavorites;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un marché, produit...'**
  String get searchHint;

  /// No description provided for @searchMapHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher sur la carte...'**
  String get searchMapHint;

  /// No description provided for @addCommerce.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter mon commerce'**
  String get addCommerce;

  /// No description provided for @visitBoutique.
  ///
  /// In fr, this message translates to:
  /// **'Visiter la boutique'**
  String get visitBoutique;

  /// No description provided for @contactSeller.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le commerçant'**
  String get contactSeller;

  /// No description provided for @nearbySection.
  ///
  /// In fr, this message translates to:
  /// **'À proximité · {count} commerce{plural}'**
  String nearbySection(int count, String plural);

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @filterButton.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filterButton;

  /// No description provided for @filterWithCount.
  ///
  /// In fr, this message translates to:
  /// **'Filtres ({count})'**
  String filterWithCount(int count);

  /// No description provided for @gpsActive.
  ///
  /// In fr, this message translates to:
  /// **'GPS actif'**
  String get gpsActive;

  /// No description provided for @offlineError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau. Données en cache affichées.'**
  String get offlineError;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @anonBannerText.
  ///
  /// In fr, this message translates to:
  /// **'Mode visiteur — Créez un compte pour commander'**
  String get anonBannerText;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @myShops.
  ///
  /// In fr, this message translates to:
  /// **'Mes boutiques & établissements'**
  String get myShops;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @noShop.
  ///
  /// In fr, this message translates to:
  /// **'Aucune boutique'**
  String get noShop;

  /// No description provided for @noShopSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre première boutique ou établissement'**
  String get noShopSubtitle;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @messages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @myOrders.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get myOrders;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @securityPin.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité & PIN'**
  String get securityPin;

  /// No description provided for @privacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicy;

  /// No description provided for @helpSupport.
  ///
  /// In fr, this message translates to:
  /// **'Aide & Support'**
  String get helpSupport;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la déconnexion'**
  String get signOutConfirm;

  /// No description provided for @signOutMessage.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir vous déconnecter ?'**
  String get signOutMessage;

  /// No description provided for @cartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon panier'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Votre panier est vide'**
  String get cartEmpty;

  /// No description provided for @cartEmptySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des produits depuis les boutiques'**
  String get cartEmptySubtitle;

  /// No description provided for @cartClear.
  ///
  /// In fr, this message translates to:
  /// **'Vider le panier'**
  String get cartClear;

  /// No description provided for @cartClearConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Vider le panier ?'**
  String get cartClearConfirm;

  /// No description provided for @cartTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get cartTotal;

  /// No description provided for @proceedToCheckout.
  ///
  /// In fr, this message translates to:
  /// **'Passer la commande'**
  String get proceedToCheckout;

  /// No description provided for @orderTrackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de commande'**
  String get orderTrackingTitle;

  /// No description provided for @orderStatusEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get orderStatusEnAttente;

  /// No description provided for @orderStatusConfirmee.
  ///
  /// In fr, this message translates to:
  /// **'Confirmée'**
  String get orderStatusConfirmee;

  /// No description provided for @orderStatusEnLivraison.
  ///
  /// In fr, this message translates to:
  /// **'En livraison'**
  String get orderStatusEnLivraison;

  /// No description provided for @orderStatusLivree.
  ///
  /// In fr, this message translates to:
  /// **'Livrée'**
  String get orderStatusLivree;

  /// No description provided for @orderStatusAnnulee.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get orderStatusAnnulee;

  /// No description provided for @cancelOrder.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get cancelOrder;

  /// No description provided for @ordersListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get ordersListTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande pour l\'instant'**
  String get ordersEmpty;

  /// No description provided for @ordersEmptySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos commandes apparaîtront ici'**
  String get ordersEmptySubtitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes favoris'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori pour l\'instant'**
  String get favoritesEmpty;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// No description provided for @searchNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get searchNoResult;

  /// No description provided for @checkoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Passer la commande'**
  String get checkoutTitle;

  /// No description provided for @checkoutAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de livraison'**
  String get checkoutAddress;

  /// No description provided for @checkoutAddressHint.
  ///
  /// In fr, this message translates to:
  /// **'Quartier, rue, point de repère...'**
  String get checkoutAddressHint;

  /// No description provided for @checkoutPhone.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get checkoutPhone;

  /// No description provided for @checkoutPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'6XX XXX XXX'**
  String get checkoutPhoneHint;

  /// No description provided for @checkoutPayment.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get checkoutPayment;

  /// No description provided for @checkoutPayCash.
  ///
  /// In fr, this message translates to:
  /// **'Paiement à la livraison'**
  String get checkoutPayCash;

  /// No description provided for @checkoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la commande'**
  String get checkoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get error;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau. Vérifiez votre connexion.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get errorGeneric;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @report.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get report;

  /// No description provided for @verified.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié'**
  String get verified;

  /// No description provided for @shopType_boutique.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get shopType_boutique;

  /// No description provided for @shopType_etablissement.
  ///
  /// In fr, this message translates to:
  /// **'Établissement'**
  String get shopType_etablissement;

  /// No description provided for @addedToCart.
  ///
  /// In fr, this message translates to:
  /// **'{name} ajouté au panier'**
  String addedToCart(String name);

  /// No description provided for @viewCart.
  ///
  /// In fr, this message translates to:
  /// **'Voir panier'**
  String get viewCart;

  /// No description provided for @requireAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte requis'**
  String get requireAccountTitle;

  /// No description provided for @requireAccountMessage.
  ///
  /// In fr, this message translates to:
  /// **'Créez un compte pour accéder à cette fonctionnalité.'**
  String get requireAccountMessage;

  /// No description provided for @cguTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get cguTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyTitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPasswordTitle;

  /// No description provided for @helpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide & Support'**
  String get helpTitle;

  /// No description provided for @orDivider.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get orDivider;

  /// No description provided for @continueWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans compte'**
  String get continueWithoutAccount;

  /// No description provided for @errorGoogleSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connexion Google échouée. Réessayez.'**
  String get errorGoogleSignIn;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations seront visibles\npar les autres utilisateurs'**
  String get registerSubtitle;

  /// No description provided for @usernameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: jeankamga'**
  String get usernameHint;

  /// No description provided for @cityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get cityLabel;

  /// No description provided for @birthDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get birthDateLabel;

  /// No description provided for @selectDate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date'**
  String get selectDate;

  /// No description provided for @termsPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En terminant votre inscription, vous acceptez nos '**
  String get termsPrefix;

  /// No description provided for @termsAnd.
  ///
  /// In fr, this message translates to:
  /// **' et notre '**
  String get termsAnd;

  /// No description provided for @finishRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Terminer l\'inscription'**
  String get finishRegistration;

  /// No description provided for @usernameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre nom d\'utilisateur'**
  String get usernameRequired;

  /// No description provided for @birthDateRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre date de naissance'**
  String get birthDateRequired;

  /// No description provided for @slowNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Réseau lent. Vérifiez votre connexion et réessayez.'**
  String get slowNetwork;

  /// No description provided for @cartClearShort.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get cartClearShort;

  /// No description provided for @cartClearConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer tous les articles ?'**
  String get cartClearConfirmMessage;

  /// No description provided for @checkoutButtonCOD.
  ///
  /// In fr, this message translates to:
  /// **'Commander — Paiement à la livraison'**
  String get checkoutButtonCOD;

  /// No description provided for @cartItemWord.
  ///
  /// In fr, this message translates to:
  /// **'article'**
  String get cartItemWord;

  /// No description provided for @notProvided.
  ///
  /// In fr, this message translates to:
  /// **'Non renseignée'**
  String get notProvided;

  /// No description provided for @memberSince.
  ///
  /// In fr, this message translates to:
  /// **'Membre depuis'**
  String get memberSince;

  /// No description provided for @signOutButton.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOutButton;

  /// No description provided for @signOutDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get signOutDialogTitle;

  /// No description provided for @commerceDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Commerce supprimé'**
  String get commerceDeleted;

  /// No description provided for @editProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfile;

  /// No description provided for @visitShop.
  ///
  /// In fr, this message translates to:
  /// **'Voir la boutique'**
  String get visitShop;

  /// No description provided for @loadShopsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les boutiques'**
  String get loadShopsError;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
