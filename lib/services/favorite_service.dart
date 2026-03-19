import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'commerce_service.dart';

class FavoriteService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ─── Toggle favori ────────────────────────────────────────────────────────

  static Future<void> toggle(String commerceId) async {
    final ref = _db.collection('favorites').doc(_uid);
    final doc = await ref.get();
    final ids =
        (doc.data()?['boutique_ids'] as List?)?.cast<String>() ?? [];
    if (ids.contains(commerceId)) {
      await ref.update({
        'boutique_ids': FieldValue.arrayRemove([commerceId]),
      });
    } else {
      await ref.set({
        'boutique_ids': FieldValue.arrayUnion([commerceId]),
      }, SetOptions(merge: true));
    }
  }

  // ─── Écouter si un commerce est en favori ────────────────────────────────

  static Stream<bool> isFavorite(String commerceId) {
    return _db.collection('favorites').doc(_uid).snapshots().map((snap) {
      final ids =
          (snap.data()?['boutique_ids'] as List?)?.cast<String>() ?? [];
      return ids.contains(commerceId);
    });
  }

  // ─── Stream des IDs favoris ──────────────────────────────────────────────

  static Stream<List<String>> favoriteIds() {
    return _db.collection('favorites').doc(_uid).snapshots().map((snap) {
      return (snap.data()?['boutique_ids'] as List?)?.cast<String>() ?? [];
    });
  }

  // ─── Stream des commerces favoris ────────────────────────────────────────
  // Stream cold (async*) : chaque appel crée un nouvel abonnement Firestore.
  // Toujours cacher dans une variable late final initialisée dans initState().
  static Stream<List<Commerce>> streamFavorites() async* {
    await for (final snap
        in _db.collection('favorites').doc(_uid).snapshots()) {
      final ids =
          (snap.data()?['boutique_ids'] as List?)?.cast<String>() ?? [];
      if (ids.isEmpty) {
        yield [];
        continue;
      }
      // Firestore whereIn : max 30 IDs
      final chunk = ids.take(30).toList();
      final commerceSnap = await _db
          .collection('commercants')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      yield commerceSnap.docs.map(Commerce.fromDoc).toList();
    }
  }
}
