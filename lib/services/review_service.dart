import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ─── Ajouter / Modifier un avis ──────────────────────────────────────────

  static Future<void> submitReview({
    required String commerceId,
    required int rating,
    required String comment,
    required String username,
  }) async {
    final itemRef = _db
        .collection('reviews')
        .doc(commerceId)
        .collection('items')
        .doc(_uid);

    // Lire l'ancien avis pour recalculer la moyenne
    final oldDoc = await itemRef.get();
    final oldRating =
        oldDoc.exists ? (oldDoc.data()?['rating'] as int? ?? 0) : 0;
    final isNew = !oldDoc.exists;

    // Sauvegarder l'avis
    await itemRef.set({
      'rating': rating,
      'comment': comment.trim(),
      'username': username,
      'user_id': _uid,
      'created_at': Timestamp.now(),
    });

    // Mettre à jour l'agrégat (moyenne + compteur)
    final aggRef = _db.collection('reviews').doc(commerceId);
    await _db.runTransaction((tx) async {
      final aggDoc = await tx.get(aggRef);
      if (!aggDoc.exists || isNew) {
        final currentCount =
            (aggDoc.data()?['count'] as int? ?? 0);
        final currentSum =
            ((aggDoc.data()?['avg_rating'] as num? ?? 0) *
                currentCount);
        final newCount = currentCount + 1;
        final newAvg = (currentSum + rating) / newCount;
        tx.set(
          aggRef,
          {'avg_rating': newAvg, 'count': newCount},
          SetOptions(merge: true),
        );
      } else {
        final currentCount =
            (aggDoc.data()?['count'] as int? ?? 1);
        final currentSum =
            ((aggDoc.data()?['avg_rating'] as num? ?? 0) *
                currentCount);
        final newSum = currentSum - oldRating + rating;
        final newAvg = newSum / currentCount;
        tx.update(aggRef, {'avg_rating': newAvg});
      }
    });
  }

  // ─── Supprimer un avis ────────────────────────────────────────────────────

  static Future<void> deleteReview(String commerceId) async {
    final itemRef = _db
        .collection('reviews')
        .doc(commerceId)
        .collection('items')
        .doc(_uid);
    final doc = await itemRef.get();
    if (!doc.exists) return;
    final oldRating = doc.data()?['rating'] as int? ?? 0;
    await itemRef.delete();

    final aggRef = _db.collection('reviews').doc(commerceId);
    await _db.runTransaction((tx) async {
      final aggDoc = await tx.get(aggRef);
      final currentCount =
          (aggDoc.data()?['count'] as int? ?? 1);
      if (currentCount <= 1) {
        tx.delete(aggRef);
      } else {
        final currentSum =
            ((aggDoc.data()?['avg_rating'] as num? ?? 0) *
                currentCount);
        final newCount = currentCount - 1;
        final newAvg = (currentSum - oldRating) / newCount;
        tx.update(aggRef,
            {'avg_rating': newAvg, 'count': newCount});
      }
    });
  }

  // ─── Stream de la moyenne ─────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> streamAggregate(
      String commerceId) {
    return _db
        .collection('reviews')
        .doc(commerceId)
        .snapshots()
        .map((snap) => snap.data() ?? {});
  }

  // ─── Stream de la liste des avis ─────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> streamReviews(
      String commerceId) {
    return _db
        .collection('reviews')
        .doc(commerceId)
        .collection('items')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  // ─── Lire mon propre avis ────────────────────────────────────────────────

  static Stream<Map<String, dynamic>?> streamMyReview(
      String commerceId) {
    return _db
        .collection('reviews')
        .doc(commerceId)
        .collection('items')
        .doc(_uid)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }
}
