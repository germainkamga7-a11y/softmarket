import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Statuts commande ──────────────────────────────────────────────────────────

enum OrderStatus {
  enAttente,
  confirmee,
  enLivraison,
  livree,
  annulee;

  String get label {
    switch (this) {
      case OrderStatus.enAttente:   return 'En attente';
      case OrderStatus.confirmee:   return 'Confirmée';
      case OrderStatus.enLivraison: return 'En livraison';
      case OrderStatus.livree:      return 'Livrée';
      case OrderStatus.annulee:     return 'Annulée';
    }
  }

  static OrderStatus fromString(String s) {
    switch (s) {
      case 'confirmee':   return OrderStatus.confirmee;
      case 'en_livraison': return OrderStatus.enLivraison;
      case 'livree':      return OrderStatus.livree;
      case 'annulee':     return OrderStatus.annulee;
      default:            return OrderStatus.enAttente;
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.enAttente:   return 'en_attente';
      case OrderStatus.confirmee:   return 'confirmee';
      case OrderStatus.enLivraison: return 'en_livraison';
      case OrderStatus.livree:      return 'livree';
      case OrderStatus.annulee:     return 'annulee';
    }
  }
}

// ─── Modèles ───────────────────────────────────────────────────────────────────

class OrderItem {
  final String productId;
  final String nom;
  final double prix;
  final int quantite;
  final String? imageUrl;
  final String commerceId;
  final String commerceNom;

  const OrderItem({
    required this.productId,
    required this.nom,
    required this.prix,
    required this.quantite,
    this.imageUrl,
    required this.commerceId,
    required this.commerceNom,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'nom': nom,
    'prix': prix,
    'quantite': quantite,
    'imageUrl': imageUrl,
    'commerceId': commerceId,
    'commerceNom': commerceNom,
  };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    productId:   m['productId'] as String,
    nom:         m['nom'] as String,
    prix:        (m['prix'] as num).toDouble(),
    quantite:    (m['quantite'] as num).toInt(),
    imageUrl:    m['imageUrl'] as String?,
    commerceId:  m['commerceId'] as String,
    commerceNom: m['commerceNom'] as String,
  );
}

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double total;
  final String adresseLivraison;
  final String telephone;
  final OrderStatus statut;
  final String modePaiement; // 'livraison' | 'mobile_money'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.adresseLivraison,
    required this.telephone,
    required this.statut,
    required this.modePaiement,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Order(
      id:               doc.id,
      userId:           d['userId'] as String,
      items:            (d['items'] as List).map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      total:            (d['total'] as num).toDouble(),
      adresseLivraison: d['adresseLivraison'] as String,
      telephone:        d['telephone'] as String,
      statut:           OrderStatus.fromString(d['statut'] as String),
      modePaiement:     d['modePaiement'] as String? ?? 'livraison',
      createdAt:        (d['createdAt'] as Timestamp).toDate(),
      updatedAt:        (d['updatedAt'] as Timestamp).toDate(),
    );
  }

  int get itemCount => items.fold(0, (acc, i) => acc + i.quantite);
}

// ─── Service ───────────────────────────────────────────────────────────────────

class OrderService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference get col => _db.collection('commandes');

  /// Crée une nouvelle commande depuis le panier
  static Future<String> createOrder({
    required List<OrderItem> items,
    required double total,
    required String adresseLivraison,
    required String telephone,
    String modePaiement = 'livraison',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Non authentifié');

    final now = Timestamp.now();
    final ref = await col.add({
      'userId':           uid,
      'items':            items.map((i) => i.toMap()).toList(),
      'total':            total,
      'adresseLivraison': adresseLivraison,
      'telephone':        telephone,
      'statut':           OrderStatus.enAttente.value,
      'modePaiement':     modePaiement,
      'createdAt':        now,
      'updatedAt':        now,
    }).timeout(const Duration(seconds: 12));

    return ref.id;
  }

  /// Stream des commandes de l'utilisateur connecté (tri par date décroissante)
  static Stream<List<Order>> streamUserOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return col
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Order.fromDoc(d)).toList());
  }

  /// Récupère une commande par ID
  static Future<Order?> getOrder(String id) async {
    final doc = await col.doc(id).get();
    if (!doc.exists) return null;
    return Order.fromDoc(doc);
  }

  /// Annule une commande (seulement si statut en_attente)
  static Future<void> cancelOrder(String id) async {
    await col.doc(id).update({
      'statut':    OrderStatus.annulee.value,
      'updatedAt': Timestamp.now(),
    }).timeout(const Duration(seconds: 12));
  }
}
