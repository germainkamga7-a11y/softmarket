import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:camermarket/services/commerce_service.dart';

// Coordonnée de test : centre de Yaoundé
const _yaounde = LatLng(3.8480, 11.5021);

Commerce _makeCommerce({
  String? id,
  CommerceType type = CommerceType.boutique,
  String? logoUrl,
  bool verified = false,
  String numeroMobileMoney = '',
  String operateurMobileMoney = '',
}) =>
    Commerce(
      id: id,
      nomBoutique: 'Boutique Test',
      nomCommercant: 'Jean Dupont',
      description: 'Vente de produits alimentaires',
      categorie: 'Alimentation & Épicerie',
      telephone: '+237600000000',
      userId: 'user_123',
      numeroCni: '000000000',
      position: _yaounde,
      createdAt: DateTime(2024, 6, 1),
      type: type,
      logoUrl: logoUrl,
      verified: verified,
      numeroMobileMoney: numeroMobileMoney,
      operateurMobileMoney: operateurMobileMoney,
    );

void main() {
  // ─── typeLabel ─────────────────────────────────────────────────────────────

  group('Commerce.typeLabel', () {
    test('retourne "Boutique" pour CommerceType.boutique', () {
      expect(_makeCommerce(type: CommerceType.boutique).typeLabel, 'Boutique');
    });

    test('retourne "Établissement" pour CommerceType.etablissement', () {
      expect(
        _makeCommerce(type: CommerceType.etablissement).typeLabel,
        'Établissement',
      );
    });
  });

  // ─── categoriesForType ─────────────────────────────────────────────────────

  group('Commerce.categoriesForType', () {
    test('retourne categoriesBoutique pour type boutique', () {
      final c = _makeCommerce(type: CommerceType.boutique);
      expect(c.categoriesForType, Commerce.categoriesBoutique);
    });

    test('retourne categoriesEtablissement pour type etablissement', () {
      final c = _makeCommerce(type: CommerceType.etablissement);
      expect(c.categoriesForType, Commerce.categoriesEtablissement);
    });

    test('les deux listes sont non-vides et disjointes', () {
      expect(Commerce.categoriesBoutique, isNotEmpty);
      expect(Commerce.categoriesEtablissement, isNotEmpty);
      final intersection = Commerce.categoriesBoutique
          .toSet()
          .intersection(Commerce.categoriesEtablissement.toSet());
      expect(intersection, isEmpty);
    });
  });

  // ─── copyWith ──────────────────────────────────────────────────────────────

  group('Commerce.copyWith', () {
    test('préserve les champs non modifiés', () {
      final original = _makeCommerce();
      final copy = original.copyWith();
      expect(copy.nomBoutique, original.nomBoutique);
      expect(copy.description, original.description);
      expect(copy.categorie, original.categorie);
      expect(copy.telephone, original.telephone);
      expect(copy.userId, original.userId);
      expect(copy.type, original.type);
      expect(copy.position, original.position);
    });

    test('met à jour nomBoutique', () {
      final copy = _makeCommerce().copyWith(nomBoutique: 'Nouveau Nom');
      expect(copy.nomBoutique, 'Nouveau Nom');
    });

    test('met à jour description', () {
      final copy = _makeCommerce().copyWith(description: 'Nouvelle description');
      expect(copy.description, 'Nouvelle description');
    });

    test('met à jour logoUrl', () {
      final copy = _makeCommerce().copyWith(logoUrl: 'https://example.com/logo.png');
      expect(copy.logoUrl, 'https://example.com/logo.png');
    });

    test('logoUrl null préserve l\'original si non fourni', () {
      final original = _makeCommerce(logoUrl: 'https://example.com/logo.png');
      final copy = original.copyWith(nomBoutique: 'Autre');
      expect(copy.logoUrl, 'https://example.com/logo.png');
    });

    test('met à jour numeroMobileMoney et operateur', () {
      final copy = _makeCommerce().copyWith(
        numeroMobileMoney: '+237670000000',
        operateurMobileMoney: 'MTN',
      );
      expect(copy.numeroMobileMoney, '+237670000000');
      expect(copy.operateurMobileMoney, 'MTN');
    });

    test('l\'id est conservé', () {
      final original = _makeCommerce(id: 'doc_abc');
      final copy = original.copyWith(nomBoutique: 'X');
      expect(copy.id, 'doc_abc');
    });
  });

  // ─── toMap ─────────────────────────────────────────────────────────────────

  group('Commerce.toMap', () {
    test('contient tous les champs requis', () {
      final m = _makeCommerce().toMap();
      expect(m['nom_boutique'], 'Boutique Test');
      expect(m['nom_commercant'], 'Jean Dupont');
      expect(m['description'], 'Vente de produits alimentaires');
      expect(m['categorie'], 'Alimentation & Épicerie');
      expect(m['telephone'], '+237600000000');
      expect(m['user_id'], 'user_123');
      expect(m['numero_cni'], '000000000');
      expect(m['type'], 'boutique');
    });

    test('position sérialisée en GeoPoint', () {
      final m = _makeCommerce().toMap();
      final geo = m['position'] as GeoPoint;
      expect(geo.latitude, closeTo(3.8480, 0.0001));
      expect(geo.longitude, closeTo(11.5021, 0.0001));
    });

    test('created_at sérialisé en Timestamp', () {
      final m = _makeCommerce().toMap();
      expect(m['created_at'], isA<Timestamp>());
    });

    test('type etablissement sérialisé correctement', () {
      final m = _makeCommerce(type: CommerceType.etablissement).toMap();
      expect(m['type'], 'etablissement');
    });

    test('logoUrl absent si null', () {
      final m = _makeCommerce().toMap();
      expect(m.containsKey('logo_url'), isFalse);
    });

    test('logoUrl présent si fourni', () {
      final m = _makeCommerce(logoUrl: 'https://example.com/img.png').toMap();
      expect(m['logo_url'], 'https://example.com/img.png');
    });

    test('numeroMobileMoney absent si vide', () {
      final m = _makeCommerce().toMap();
      expect(m.containsKey('numero_mobile_money'), isFalse);
    });

    test('numeroMobileMoney présent si renseigné', () {
      final m = _makeCommerce(
        numeroMobileMoney: '+237670000000',
        operateurMobileMoney: 'MTN',
      ).toMap();
      expect(m['numero_mobile_money'], '+237670000000');
      expect(m['operateur_mobile_money'], 'MTN');
    });

    test('verified est toujours false dans toMap (valeur Firestore fixée)', () {
      // verified = true dans le modèle local, mais toMap() force false
      // (seul l'admin peut vérifier via Firebase Console)
      final m = _makeCommerce(verified: true).toMap();
      expect(m['verified'], isFalse);
    });
  });
}
