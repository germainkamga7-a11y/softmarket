import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String productId;
  final String nom;
  final double prix;
  final String? imageUrl;
  final String commerceId;
  final String commerceNom;
  int quantite;

  CartItem({
    required this.productId,
    required this.nom,
    required this.prix,
    this.imageUrl,
    required this.commerceId,
    required this.commerceNom,
    this.quantite = 1,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'nom': nom,
        'prix': prix,
        'imageUrl': imageUrl,
        'commerceId': commerceId,
        'commerceNom': commerceNom,
        'quantite': quantite,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: j['productId'] as String,
        nom: j['nom'] as String,
        prix: (j['prix'] as num).toDouble(),
        imageUrl: j['imageUrl'] as String?,
        commerceId: j['commerceId'] as String,
        commerceNom: j['commerceNom'] as String,
        quantite: (j['quantite'] as int?) ?? 1,
      );
}

class CartService extends ChangeNotifier {
  static const _key = 'cart_items';

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantite);
  double get totalAmount => _items.fold(0, (sum, i) => sum + i.prix * i.quantite);

  CartService() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items.addAll(list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CartService] Erreur chargement panier : $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[CartService] Erreur persistance panier : $e');
    }
  }

  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      _items[idx].quantite++;
    } else {
      _items.add(item);
    }
    notifyListeners();
    _persist();
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
    _persist();
  }

  void updateQuantity(String productId, int delta) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    _items[idx].quantite = (_items[idx].quantite + delta).clamp(1, 99);
    notifyListeners();
    _persist();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persist();
  }
}
