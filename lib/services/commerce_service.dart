import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum CommerceType { boutique, etablissement }

class Commerce {
  final String? id;
  final String nomBoutique;
  final String nomCommercant;
  final String description;
  final String categorie;
  final String telephone;
  final String userId;
  final String numeroCni;
  final LatLng position;
  final DateTime createdAt;
  final CommerceType type;
  final String? logoUrl;

  static const List<String> categoriesBoutique = [
    'Alimentation & Épicerie',
    'Boulangerie & Pâtisserie',
    'Boucherie & Poissonnerie',
    'Fruits & Légumes',
    'Boissons',
    'Mode & Vêtements',
    'Chaussures & Maroquinerie',
    'Électronique & Téléphonie',
    'Électroménager',
    'Informatique & Accessoires',
    'Maison & Déco',
    'Meubles & Literie',
    'Matériaux & Construction',
    'Quincaillerie',
    'Agriculture & Élevage',
    'Pharmacie & Parapharmacie',
    'Cosmétiques & Parfums',
    'Jouets & Loisirs',
    'Librairie & Papeterie',
    'Autre',
  ];

  static const List<String> categoriesEtablissement = [
    'Santé & Soins médicaux',
    'Coiffure & Barbier',
    'Beauté & Esthétique',
    'Restauration & Fast-food',
    'Traiteur & Cuisine à domicile',
    'Hôtellerie & Hébergement',
    'Transport & Livraison',
    'Mécanique Auto & Moto',
    'Électricité & Plomberie',
    'Menuiserie & Ébénisterie',
    'Maçonnerie & Construction',
    'Réparation & Maintenance',
    'Service Numérique & Informatique',
    'Infographie & Design',
    'Photographie & Vidéo',
    'Événementiel & Animation',
    'Éducation & Formation',
    'Couture & Retouche',
    'Jardinage & Nettoyage',
    'Services financiers & Mobile Money',
    'Autres services',
  ];

  // Kept for backward compatibility
  static const List<String> categories = [
    'Alimentation',
    'Électronique',
    'Mode & Vêtements',
    'Agriculture',
    'Matériaux & Construction',
    'Services',
    'Santé & Beauté',
    'Maison & Déco',
    'Autre',
  ];

  const Commerce({
    this.id,
    required this.nomBoutique,
    required this.nomCommercant,
    required this.description,
    required this.categorie,
    required this.telephone,
    required this.userId,
    required this.numeroCni,
    required this.position,
    required this.createdAt,
    this.type = CommerceType.boutique,
    this.logoUrl,
  });

  String get typeLabel =>
      type == CommerceType.boutique ? 'Boutique' : 'Établissement';

  List<String> get categoriesForType =>
      type == CommerceType.boutique ? categoriesBoutique : categoriesEtablissement;

  Map<String, dynamic> toMap() => {
        'nom_boutique': nomBoutique,
        'nom_commercant': nomCommercant,
        'description': description,
        'categorie': categorie,
        'telephone': telephone,
        'user_id': userId,
        'numero_cni': numeroCni,
        'type': type.name,
        'position': GeoPoint(position.latitude, position.longitude),
        'created_at': Timestamp.fromDate(createdAt),
        if (logoUrl != null) 'logo_url': logoUrl,
      };

  factory Commerce.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geo = data['position'] as GeoPoint;
    final typeStr = data['type'] as String? ?? 'boutique';
    return Commerce(
      id: doc.id,
      nomBoutique: data['nom_boutique'] as String? ?? data['nom_commercant'] as String? ?? '',
      nomCommercant: data['nom_commercant'] as String? ?? '',
      description: data['description'] as String? ?? '',
      categorie: data['categorie'] as String? ?? 'Autre',
      telephone: data['telephone'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      numeroCni: data['numero_cni'] as String? ?? '',
      type: typeStr == 'etablissement'
          ? CommerceType.etablissement
          : CommerceType.boutique,
      position: LatLng(geo.latitude, geo.longitude),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      logoUrl: data['logo_url'] as String?,
    );
  }

  Commerce copyWith({
    String? nomBoutique,
    String? description,
    String? categorie,
    String? telephone,
    String? logoUrl,
  }) =>
      Commerce(
        id: id,
        nomBoutique: nomBoutique ?? this.nomBoutique,
        nomCommercant: nomCommercant,
        description: description ?? this.description,
        categorie: categorie ?? this.categorie,
        telephone: telephone ?? this.telephone,
        userId: userId,
        numeroCni: numeroCni,
        type: type,
        position: position,
        createdAt: createdAt,
        logoUrl: logoUrl ?? this.logoUrl,
      );
}

class CommerceService {
  static const _collection = 'commercants';
  final _db = FirebaseFirestore.instance;

  Future<String> saveBoutique({
    required String nomBoutique,
    required String nomCommercant,
    required String description,
    required String categorie,
    required String telephone,
    required String userId,
    required LatLng position,
    required CommerceType type,
    String numeroCni = '',
  }) async {
    try {
      final commerce = Commerce(
        nomBoutique: nomBoutique,
        nomCommercant: nomCommercant,
        description: description,
        categorie: categorie,
        telephone: telephone,
        userId: userId,
        numeroCni: numeroCni,
        type: type,
        position: position,
        createdAt: DateTime.now(),
      );
      final ref = await _db
          .collection(_collection)
          .add(commerce.toMap())
          .timeout(const Duration(seconds: 12));
      debugPrint('[CommerceService] ${commerce.typeLabel} créé : ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('[CommerceService] Erreur : $e');
      rethrow;
    }
  }

  Future<void> updateBoutique(String id, {
    required String nomBoutique,
    required String description,
    required String categorie,
    required String telephone,
    String? logoUrl,
  }) async {
    final data = {
      'nom_boutique': nomBoutique,
      'description': description,
      'categorie': categorie,
      'telephone': telephone,
      if (logoUrl != null) 'logo_url': logoUrl,
    };
    await _db.collection(_collection).doc(id).update(data)
        .timeout(const Duration(seconds: 12));
  }

  // Stream cold : chaque appel à streamCommerces() ouvre une nouvelle connexion
  // Firestore. C'est le comportement standard des streams Firestore.
  // IMPORTANT : toujours cacher ce stream dans une variable d'instance ou
  // initState() et ne JAMAIS l'appeler directement dans build() ou dans le
  // constructeur d'un StreamBuilder — cela créerait une nouvelle connexion
  // réseau à chaque rebuild et provoquerait des freezes Android.
  Stream<List<Commerce>> streamCommerces() {
    return _db
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) {
          final result = <Commerce>[];
          for (final doc in snap.docs) {
            try {
              result.add(Commerce.fromDoc(doc));
            } catch (e) {
              debugPrint('[CommerceService] Erreur parsing doc ${doc.id}: $e');
            }
          }
          return result;
        });
  }

  // Stream cold — même remarque que streamCommerces() : cacher dans initState.
  Stream<List<Commerce>> streamUserBoutiques(String userId) {
    return _db
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final result = <Commerce>[];
          for (final doc in snap.docs) {
            try {
              result.add(Commerce.fromDoc(doc));
            } catch (e) {
              debugPrint('[CommerceService] Erreur parsing doc ${doc.id}: $e');
            }
          }
          result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return result;
        });
  }

  Future<void> deleteCommerce(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> streamLatestProducts({int limit = 10}) {
    return _db
        .collection('produits')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  /// Récupère une page de produits (pagination startAfter)
  Future<({List<Map<String, dynamic>> items, DocumentSnapshot? lastDoc})>
      fetchProductsPage({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _db
        .collection('produits')
        .orderBy('created_at', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    return (
      items: snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  // Legacy method kept for compatibility
  Future<String> saveCommerce({
    required String nom,
    required String numeroCni,
    required LatLng position,
    String userId = '',
  }) async {
    return saveBoutique(
      nomBoutique: nom,
      nomCommercant: nom,
      description: '',
      categorie: 'Autre',
      telephone: '',
      userId: userId,
      type: CommerceType.boutique,
      numeroCni: numeroCni,
      position: position,
    );
  }
}
