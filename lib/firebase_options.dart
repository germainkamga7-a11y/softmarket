// FICHIER GÉNÉRÉ — À remplacer par le fichier généré via FlutterFire CLI :
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Ce fichier est un placeholder. Remplacez toutes les valeurs par celles
// de votre projet Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'Plateforme non configurée pour Firebase. '
          'Exécutez "flutterfire configure" pour générer ce fichier.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGsbEObzNb4QiIPIKpFL6bIW8Qx7IQLGk',
    appId: '1:795518110767:web:12f2e5ac320fee117c4ada',
    messagingSenderId: '795518110767',
    projectId: 'softmarket-55f22',
    authDomain: 'softmarket-55f22.firebaseapp.com',
    storageBucket: 'softmarket-55f22.firebasestorage.app',
    measurementId: 'G-F6JBVRQ11M',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6pUWJhwxce7wlBb7kctFahGHk6F27P2Y',
    appId: '1:795518110767:android:52e9903454093b8a7c4ada',
    messagingSenderId: '795518110767',
    projectId: 'softmarket-55f22',
    authDomain: 'softmarket-55f22.firebaseapp.com',
    storageBucket: 'softmarket-55f22.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDiQ3BW-8gb_lwI-vFICdZBgfSB7L-SY-U',
    appId: '1:795518110767:ios:cff38725cd20306b7c4ada',
    messagingSenderId: '795518110767',
    projectId: 'softmarket-55f22',
    storageBucket: 'softmarket-55f22.firebasestorage.app',
    iosBundleId: 'com.example.softmarket',
  );
}