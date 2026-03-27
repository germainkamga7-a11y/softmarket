// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CamerMarket';

  @override
  String get appTagline => 'CAMEROON\'S DIGITAL MARKET';

  @override
  String get welcome => 'Welcome!';

  @override
  String get welcomeSubtitle =>
      'Buy, sell and trade with verified\nmerchants near you.';

  @override
  String get securityNote => 'Secure transactions · Geolocated merchants';

  @override
  String get createAccount => 'Create account';

  @override
  String get signIn => 'Sign in';

  @override
  String get continueWithPhone => 'Continue with phone number';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueAsVisitor => 'Continue as visitor';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get deliver => 'Deliver';

  @override
  String get navMap => 'Map';

  @override
  String get navHome => 'Home';

  @override
  String get navOrders => 'Orders';

  @override
  String get navFavorites => 'Favourites';

  @override
  String get navProfile => 'Profile';

  @override
  String get searchHint => 'Search a market, product...';

  @override
  String get searchMapHint => 'Search on map...';

  @override
  String get addCommerce => 'Add my business';

  @override
  String get visitBoutique => 'Visit the shop';

  @override
  String get contactSeller => 'Contact seller';

  @override
  String nearbySection(int count, String plural) {
    return 'Nearby · $count business$plural';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterButton => 'Filters';

  @override
  String filterWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get gpsActive => 'GPS active';

  @override
  String get offlineError => 'Network error. Cached data displayed.';

  @override
  String get retry => 'Retry';

  @override
  String get anonBannerText => 'Visitor mode — Create an account to order';

  @override
  String get profileTitle => 'Profile';

  @override
  String get myShops => 'My shops & businesses';

  @override
  String get create => 'Create';

  @override
  String get noShop => 'No shop yet';

  @override
  String get noShopSubtitle => 'Create your first shop or business';

  @override
  String get settings => 'Settings';

  @override
  String get messages => 'Messages';

  @override
  String get myOrders => 'My orders';

  @override
  String get notifications => 'Notifications';

  @override
  String get securityPin => 'Security & PIN';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Confirm sign out';

  @override
  String get signOutMessage => 'Are you sure you want to sign out?';

  @override
  String get cartTitle => 'My cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartEmptySubtitle => 'Add products from shops';

  @override
  String get cartClear => 'Clear cart';

  @override
  String get cartClearConfirm => 'Clear cart?';

  @override
  String get cartTotal => 'Total';

  @override
  String get proceedToCheckout => 'Place order';

  @override
  String get orderTrackingTitle => 'Order tracking';

  @override
  String get orderStatusEnAttente => 'Pending';

  @override
  String get orderStatusConfirmee => 'Confirmed';

  @override
  String get orderStatusEnLivraison => 'Out for delivery';

  @override
  String get orderStatusLivree => 'Delivered';

  @override
  String get orderStatusAnnulee => 'Cancelled';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get ordersListTitle => 'My orders';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersEmptySubtitle => 'Your orders will appear here';

  @override
  String get favoritesTitle => 'My favourites';

  @override
  String get favoritesEmpty => 'No favourites yet';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchNoResult => 'No results';

  @override
  String get checkoutTitle => 'Place order';

  @override
  String get checkoutAddress => 'Delivery address';

  @override
  String get checkoutAddressHint => 'Neighbourhood, street, landmark...';

  @override
  String get checkoutPhone => 'Phone number';

  @override
  String get checkoutPhoneHint => '6XX XXX XXX';

  @override
  String get checkoutPayment => 'Payment method';

  @override
  String get checkoutPayCash => 'Cash on delivery';

  @override
  String get checkoutConfirm => 'Confirm order';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get errorNetwork => 'Network error. Check your connection.';

  @override
  String get errorGeneric => 'An error occurred. Please try again.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get share => 'Share';

  @override
  String get report => 'Report';

  @override
  String get verified => 'Verified';

  @override
  String get shopType_boutique => 'Shop';

  @override
  String get shopType_etablissement => 'Business';

  @override
  String addedToCart(String name) {
    return '$name added to cart';
  }

  @override
  String get viewCart => 'View cart';

  @override
  String get requireAccountTitle => 'Account required';

  @override
  String get requireAccountMessage =>
      'Create an account to access this feature.';

  @override
  String get cguTitle => 'Terms of use';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get helpTitle => 'Help & Support';

  @override
  String get orDivider => 'or';

  @override
  String get continueWithoutAccount => 'Continue without account';

  @override
  String get errorGoogleSignIn => 'Google sign-in failed. Please try again.';

  @override
  String get registerTitle => 'Your profile';

  @override
  String get registerSubtitle =>
      'This information will be visible\nto other users';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHint => 'e.g. jeankamga';

  @override
  String get cityLabel => 'City';

  @override
  String get birthDateLabel => 'Date of birth';

  @override
  String get selectDate => 'Select a date';

  @override
  String get termsPrefix =>
      'By completing your registration, you agree to our ';

  @override
  String get termsAnd => ' and our ';

  @override
  String get finishRegistration => 'Finish registration';

  @override
  String get usernameRequired => 'Please enter your username';

  @override
  String get birthDateRequired => 'Please enter your date of birth';

  @override
  String get slowNetwork =>
      'Slow network. Check your connection and try again.';

  @override
  String get cartClearShort => 'Clear';

  @override
  String get cartClearConfirmMessage => 'Remove all items?';

  @override
  String get checkoutButtonCOD => 'Order — Cash on delivery';

  @override
  String get cartItemWord => 'item';

  @override
  String get notProvided => 'Not provided';

  @override
  String get memberSince => 'Member since';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get signOutDialogTitle => 'Sign out';

  @override
  String get commerceDeleted => 'Business deleted';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get visitShop => 'View shop';

  @override
  String get loadShopsError => 'Unable to load shops';

  @override
  String get saving => 'Saving...';

  @override
  String get navExplore => 'Explore';

  @override
  String get favoritesEmptyHint =>
      'Tap ♡ on a shop to add it to your favourites';

  @override
  String get removeFromFavorites => 'Remove from favourites';

  @override
  String get noConversation => 'No conversations';

  @override
  String get noConversationHint =>
      'Contact a merchant\nto start a conversation';

  @override
  String get justNow => 'Just now';

  @override
  String get orderConfirmedTitle => 'Order confirmed!';

  @override
  String get orderNotFound => 'Order not found.';

  @override
  String get orderTrackingSection => 'Tracking';

  @override
  String get deliveryLabel => 'Delivery';

  @override
  String get contactLabel => 'Contact';

  @override
  String get paymentLabel => 'Payment';

  @override
  String get paymentCODLabel => 'Cash on delivery';

  @override
  String get cancelOrderDialogTitle => 'Cancel order?';

  @override
  String get irreversibleAction => 'This action cannot be undone.';

  @override
  String get yesCancelOrder => 'Yes, cancel';

  @override
  String get orderStatusSubtitleEnAttente => 'Waiting for seller confirmation';

  @override
  String get orderStatusSubtitleConfirmee =>
      'The seller has confirmed your order';

  @override
  String get orderStatusSubtitleEnLivraison => 'Your order is on its way!';

  @override
  String get orderStatusSubtitleLivree => 'Order delivered successfully';

  @override
  String itemsWithCount(int count) {
    return 'Items ($count)';
  }

  @override
  String get checkoutFinalizeTitle => 'Checkout';

  @override
  String get checkoutSummary => 'Summary';

  @override
  String get checkoutPayCashSubtitle => 'You pay in cash upon receipt';

  @override
  String get checkoutDeliveryInfo => 'Delivery information';

  @override
  String get checkoutAddressRequired => 'Address required';

  @override
  String get checkoutAddressTooShort => 'Address too short';

  @override
  String get checkoutPhoneRequired => 'Phone number required';

  @override
  String get checkoutPhoneInvalid => 'Invalid phone number';

  @override
  String get processing => 'Processing…';

  @override
  String get checkoutTermsNote =>
      'By confirming, you agree to be contacted by the seller to arrange delivery.';

  @override
  String get searchBarHint => 'Search a merchant, product...';

  @override
  String get searchRecentMerchants => 'Recent merchants';

  @override
  String get searchNoMerchant => 'No merchants registered';

  @override
  String searchNoResultFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchNoResultHint => 'Try another name, category or description';

  @override
  String searchResultCount(int count, String plural) {
    return '$count result$plural';
  }

  @override
  String get phoneCodeSent => 'Code sent';

  @override
  String phoneCodeSentSubtitle(String phone) {
    return 'Enter the code received by SMS on $phone';
  }

  @override
  String get phoneSendCodeSubtitle => 'We will send you a verification code';

  @override
  String get phoneWithoutDialCode => 'Number without dial code';

  @override
  String get phoneHint => 'E.g. 699123456';

  @override
  String get phoneVerifyCode => 'Verify code';

  @override
  String get phoneSendCode => 'Send code';

  @override
  String get phoneResendCode => 'Resend code';

  @override
  String get phoneChangeNumber => 'Change number';

  @override
  String get notifSectionActivity => 'Activity';

  @override
  String get notifMessagesSubtitle => 'New messages from merchants';

  @override
  String get notifNewProducts => 'New products';

  @override
  String get notifNewProductsSubtitle =>
      'Products added by your favourite shops';

  @override
  String get notifReviews => 'Reviews & Ratings';

  @override
  String get notifReviewsSubtitle => 'New reviews on your shop';

  @override
  String get notifSectionMarketing => 'Marketing';

  @override
  String get notifPromos => 'Promotions & Offers';

  @override
  String get notifPromosSubtitle => 'Special offers and discounts';

  @override
  String get notifSystemNote =>
      'System notifications (security, account) are always enabled.';
}
