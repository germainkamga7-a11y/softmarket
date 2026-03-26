import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camermarket/services/cart_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── CartItem ──────────────────────────────────────────────────────────────

  group('CartItem', () {
    final item = CartItem(
      productId: 'p1',
      nom: 'Poulet braisé',
      prix: 3500,
      imageUrl: 'https://example.com/img.jpg',
      commerceId: 'c1',
      commerceNom: 'Resto Wouri',
      quantite: 2,
    );

    test('toJson contient tous les champs', () {
      final json = item.toJson();
      expect(json['productId'], 'p1');
      expect(json['nom'], 'Poulet braisé');
      expect(json['prix'], 3500.0);
      expect(json['imageUrl'], 'https://example.com/img.jpg');
      expect(json['commerceId'], 'c1');
      expect(json['commerceNom'], 'Resto Wouri');
      expect(json['quantite'], 2);
    });

    test('fromJson recrée un CartItem identique', () {
      final json = item.toJson();
      final restored = CartItem.fromJson(json);
      expect(restored.productId, item.productId);
      expect(restored.nom, item.nom);
      expect(restored.prix, item.prix);
      expect(restored.imageUrl, item.imageUrl);
      expect(restored.commerceId, item.commerceId);
      expect(restored.commerceNom, item.commerceNom);
      expect(restored.quantite, item.quantite);
    });

    test('fromJson fonctionne sans imageUrl', () {
      final json = {
        'productId': 'p2',
        'nom': 'Ndolé',
        'prix': 2000,
        'imageUrl': null,
        'commerceId': 'c2',
        'commerceNom': 'Chez Mama',
        'quantite': 1,
      };
      final item = CartItem.fromJson(json);
      expect(item.imageUrl, isNull);
      expect(item.quantite, 1);
    });

    test('fromJson applique quantite=1 par défaut si absent', () {
      final json = {
        'productId': 'p3',
        'nom': 'Beignets',
        'prix': 500,
        'commerceId': 'c3',
        'commerceNom': 'Boulangerie',
      };
      final item = CartItem.fromJson(json);
      expect(item.quantite, 1);
    });
  });

  // ─── CartService ───────────────────────────────────────────────────────────

  group('CartService', () {
    CartItem makeItem({String id = 'p1', double prix = 1000, int qty = 1}) =>
        CartItem(
          productId: id,
          nom: 'Item $id',
          prix: prix,
          commerceId: 'c1',
          commerceNom: 'Commerce Test',
          quantite: qty,
        );

    test('démarre vide', () {
      final cart = CartService();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0.0);
    });

    test('addItem ajoute un nouvel article', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1', prix: 2000));
      expect(cart.items.length, 1);
      expect(cart.items.first.nom, 'Item p1');
      expect(cart.itemCount, 1);
    });

    test('addItem incrémente la quantité si le produit existe déjà', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.addItem(makeItem(id: 'p1'));
      expect(cart.items.length, 1);
      expect(cart.items.first.quantite, 2);
      expect(cart.itemCount, 2);
    });

    test('addItem distingue deux produits différents', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.addItem(makeItem(id: 'p2'));
      expect(cart.items.length, 2);
      expect(cart.itemCount, 2);
    });

    test('removeItem supprime l\'article', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.addItem(makeItem(id: 'p2'));
      cart.removeItem('p1');
      expect(cart.items.length, 1);
      expect(cart.items.first.productId, 'p2');
    });

    test('removeItem sur id inexistant ne plante pas', () {
      final cart = CartService();
      cart.addItem(makeItem());
      expect(() => cart.removeItem('inexistant'), returnsNormally);
      expect(cart.items.length, 1);
    });

    test('updateQuantity augmente la quantité', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.updateQuantity('p1', 2);
      expect(cart.items.first.quantite, 3);
    });

    test('updateQuantity diminue la quantité', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1', qty: 3));
      cart.updateQuantity('p1', -1);
      expect(cart.items.first.quantite, 2);
    });

    test('updateQuantity ne descend pas en dessous de 1', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.updateQuantity('p1', -99);
      expect(cart.items.first.quantite, 1);
    });

    test('updateQuantity ne dépasse pas 99', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1', qty: 99));
      cart.updateQuantity('p1', 10);
      expect(cart.items.first.quantite, 99);
    });

    test('updateQuantity sur id inexistant ne plante pas', () {
      final cart = CartService();
      expect(() => cart.updateQuantity('inexistant', 1), returnsNormally);
    });

    test('clear vide le panier', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1'));
      cart.addItem(makeItem(id: 'p2'));
      cart.clear();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0.0);
    });

    test('totalAmount calcule correctement', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1', prix: 1000));
      cart.addItem(makeItem(id: 'p2', prix: 2500));
      cart.updateQuantity('p1', 1); // p1 qty = 2
      // total = 2*1000 + 1*2500 = 4500
      expect(cart.totalAmount, 4500.0);
    });

    test('itemCount somme les quantités', () {
      final cart = CartService();
      cart.addItem(makeItem(id: 'p1', qty: 3));
      cart.addItem(makeItem(id: 'p2', qty: 2));
      expect(cart.itemCount, 5);
    });
  });
}
