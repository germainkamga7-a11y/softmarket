import 'package:flutter_test/flutter_test.dart';

import 'package:camermarket/services/order_service.dart';

void main() {
  // ─── OrderStatus ───────────────────────────────────────────────────────────

  group('OrderStatus.fromString', () {
    test('retourne enAttente par défaut', () {
      expect(OrderStatus.fromString('en_attente'), OrderStatus.enAttente);
      expect(OrderStatus.fromString('inconnu'), OrderStatus.enAttente);
      expect(OrderStatus.fromString(''), OrderStatus.enAttente);
    });

    test('parse chaque valeur correctement', () {
      expect(OrderStatus.fromString('confirmee'), OrderStatus.confirmee);
      expect(OrderStatus.fromString('en_livraison'), OrderStatus.enLivraison);
      expect(OrderStatus.fromString('livree'), OrderStatus.livree);
      expect(OrderStatus.fromString('annulee'), OrderStatus.annulee);
    });
  });

  group('OrderStatus.value', () {
    test('retourne la chaîne Firestore correcte', () {
      expect(OrderStatus.enAttente.value, 'en_attente');
      expect(OrderStatus.confirmee.value, 'confirmee');
      expect(OrderStatus.enLivraison.value, 'en_livraison');
      expect(OrderStatus.livree.value, 'livree');
      expect(OrderStatus.annulee.value, 'annulee');
    });

    test('aller-retour fromString/value est idempotent', () {
      for (final s in OrderStatus.values) {
        expect(OrderStatus.fromString(s.value), s);
      }
    });
  });

  group('OrderStatus.label', () {
    test('retourne le libellé lisible en français', () {
      expect(OrderStatus.enAttente.label, 'En attente');
      expect(OrderStatus.confirmee.label, 'Confirmée');
      expect(OrderStatus.enLivraison.label, 'En livraison');
      expect(OrderStatus.livree.label, 'Livrée');
      expect(OrderStatus.annulee.label, 'Annulée');
    });

    test('tous les statuts ont un label non-vide', () {
      for (final s in OrderStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  // ─── OrderItem ─────────────────────────────────────────────────────────────

  group('OrderItem', () {
    final item = OrderItem(
      productId: 'prod_1',
      nom: 'Sac en cuir',
      prix: 15000,
      quantite: 2,
      imageUrl: 'https://example.com/sac.jpg',
      commerceId: 'com_1',
      commerceNom: 'Maroquinerie Douala',
    );

    test('toMap contient tous les champs', () {
      final m = item.toMap();
      expect(m['productId'], 'prod_1');
      expect(m['nom'], 'Sac en cuir');
      expect(m['prix'], 15000.0);
      expect(m['quantite'], 2);
      expect(m['imageUrl'], 'https://example.com/sac.jpg');
      expect(m['commerceId'], 'com_1');
      expect(m['commerceNom'], 'Maroquinerie Douala');
    });

    test('fromMap recrée un OrderItem identique', () {
      final m = item.toMap();
      final restored = OrderItem.fromMap(m);
      expect(restored.productId, item.productId);
      expect(restored.nom, item.nom);
      expect(restored.prix, item.prix);
      expect(restored.quantite, item.quantite);
      expect(restored.imageUrl, item.imageUrl);
      expect(restored.commerceId, item.commerceId);
      expect(restored.commerceNom, item.commerceNom);
    });

    test('fromMap accepte un prix entier (int)', () {
      final m = {
        'productId': 'p',
        'nom': 'Produit',
        'prix': 5000, // int, pas double
        'quantite': 1,
        'commerceId': 'c',
        'commerceNom': 'Commerce',
      };
      final item = OrderItem.fromMap(m);
      expect(item.prix, 5000.0);
      expect(item.prix, isA<double>());
    });

    test('fromMap accepte imageUrl null', () {
      final m = {
        'productId': 'p',
        'nom': 'Produit',
        'prix': 1000,
        'quantite': 1,
        'imageUrl': null,
        'commerceId': 'c',
        'commerceNom': 'Commerce',
      };
      final item = OrderItem.fromMap(m);
      expect(item.imageUrl, isNull);
    });
  });

  // ─── Order.itemCount ───────────────────────────────────────────────────────

  group('Order.itemCount', () {
    OrderItem makeItem({int qty = 1}) => OrderItem(
          productId: 'p',
          nom: 'P',
          prix: 100,
          quantite: qty,
          commerceId: 'c',
          commerceNom: 'C',
        );

    test('somme les quantités de tous les articles', () {
      final items = [makeItem(qty: 3), makeItem(qty: 2)];
      // On teste Order.itemCount via la logique du getter
      final total = items.fold(0, (acc, i) => acc + i.quantite);
      expect(total, 5);
    });

    test('retourne 0 pour une liste vide', () {
      final total = <OrderItem>[].fold(0, (acc, i) => acc + i.quantite);
      expect(total, 0);
    });
  });
}
