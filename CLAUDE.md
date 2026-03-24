# CamerMarket — Instructions Claude Code

## Contexte projet
Marketplace Flutter dédiée au Cameroun.
- Acheteurs : parcourent boutiques/établissements, favoris, chat
- Commerçants : créent leur boutique, publient des produits
- Admin : gestion via Firebase Console

## Stack
- **Framework:** Flutter (SDK >=3.0.0 <4.0.0), Dart
- **State management:** Provider 6.1.1
- **Backend:** Firebase (Auth, Firestore, Storage, FCM)
- **Maps:** Google Maps Flutter
- **ML:** Google ML Kit OCR (scan CNI camerounaise)
- **Plateforme cible principale:** Android + Web (mobile 430px)

## Firebase
- **Project ID:** `softmarket-55f22`
- **Auth Domain:** `softmarket-55f22.firebaseapp.com`
- **Storage Bucket:** `softmarket-55f22.firebasestorage.app`
- **Measurement ID:** `G-F6JBVRQ11M`
- **Config locale:** `dart-defines.json` (ne jamais committer les vraies clés)

## Structure lib/
```
lib/
├── main.dart               # Point d'entrée, AuthGate, theme
├── firebase_options.dart   # Config Firebase (généré par flutterfire)
├── screens/                # 21 écrans (auth, home, boutique, chat, profil...)
├── services/               # Logique métier (auth, commerce, chat, map, pin, cni...)
├── theme/
│   └── app_colors.dart     # Couleurs drapeau camerounais (#CC0000, vert, jaune)
├── utils/                  # RecaptchaVerifier (web/stub)
└── widgets/
    └── pin_pad.dart        # Pavé PIN numérique
```

## Collections Firestore
- `users/{uid}` — profil + fcm_token
- `commercants/{id}` — boutiques et établissements (GeoPoint position)
- `produits/{id}` — produits liés à un commerce
- `favorites/{uid}` — boutique_ids[]
- `reviews/{commerceId}` — avis agrégés + items/{uid}
- `conversations/{id}` — chat avec messages/{id}

## Conventions code
- Langue UI : **français** (tous les textes affichés)
- Indentation : **2 espaces** (Dart standard)
- Nommage fichiers : **snake_case**
- Nommage classes : **PascalCase**
- Pas de `print()` en production — utiliser des logs conditionnels
- Toujours vérifier `mounted` avant `setState()` après un await
- Streams Firestore : toujours cacher dans `late final` dans `initState()`

## Commandes courantes
```bash
# Lancer l'app
flutter run -d chrome --dart-define-from-file=dart-defines.json

# Build web
flutter build web --dart-define-from-file=dart-defines.json

# Analyser le code
flutter analyze > analysis_output.txt

# Déployer Firebase (rules + hosting)
firebase deploy

# Régénérer firebase_options.dart
flutterfire configure

# Ajouter un package
flutter pub add <package>
```

## Erreurs connues à corriger
- ✅ Toutes les erreurs d'analyse corrigées (`flutter analyze` → No issues found)

## Points d'attention
- **PIN Service:** Logique cross-device complexe — ne pas refactorer sans tester sur device réel
- **CNI Scanner:** Parsing OCR fragile — toujours valider le résultat avant sauvegarde
- **Web:** Centré à 430px max — ne pas briser ce layout pour mobile
- **FCM:** Désactivé sur desktop (Linux/Windows/macOS) — comportement voulu
- **Timeouts Firestore:** `.timeout(12s)` sur écritures — ne pas réduire pour réseau camerounais
- **Sécurité Firestore:** Toujours vérifier les rules avant d'ajouter une nouvelle collection
- **CartService:** Provider enregistré dans main.dart — accès via `context.read/watch<CartService>()`
- **Mobile Money:** Flux USSD client uniquement — paiement réel sur l'app/réseau MTN/Orange

## Nouveaux services (v1.1.0)
- `cart_service.dart` — Panier avec persistance SharedPreferences
- `mobile_money_service.dart` — MTN MoMo + Orange Money via USSD
- `report_service.dart` — Signalement avec bottom sheet réutilisable
- `notification_service.dart` — FCM avec tap→navigation via navigatorKey

## Améliorations réalisées (v1.1.0)
- ✅ Corriger les erreurs d'analyse
- ✅ Rate limiting chat anti-spam (1s cooldown)
- ✅ Système de paiement Mobile Money (MTN + Orange)
- ✅ Panier / commande (CartService + CartScreen)
- ✅ Partage boutique et produits (share_plus)
- ✅ Numéro téléphone cliquable (url_launcher)
- ✅ Signalement (commerce, produit, utilisateur)
- ✅ Badge commerçant vérifié
- ✅ Règles Firestore sécurisées
- ✅ Pagination carte (limit 200)
- ✅ Erreurs réseau avec retry
- ✅ Notifications push tap→navigation
- ✅ CGU + Politique de confidentialité liées à l'inscription
- ✅ Suppression compte complète (Firestore + Auth + re-auth)

## Améliorations restantes
- [ ] Migrer vers go_router (navigation centralisée)
- [ ] Ajouter Provider global (AuthProvider, CommerceProvider)
- [ ] Ajouter unit tests et widget tests
- [ ] Dark mode complet
- [ ] Offline support (Firestore persistence)
- [ ] i18n (français + anglais pour le Cameroun bilingue)
- [ ] Analytics Firebase
- [ ] Numéro Mobile Money vendeur dans profil boutique
- [ ] Cloud Functions pour notifications push serveur

## Git workflow
- Branches : `feature/description`, `fix/description`
- Ne jamais committer `dart-defines.json` (contient les clés API)
- Ne jamais committer `google-services.json` ou `GoogleService-Info.plist`
- Toujours builder avant de committer : `flutter build web`
