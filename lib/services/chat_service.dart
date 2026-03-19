import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final Map<String, dynamic>? productRef;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.productRef,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['sender_id'] as String,
      text: (data['text'] as String?) ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      productRef: data['product_ref'] as Map<String, dynamic>?,
    );
  }
}

class ChatService {
  final _db = FirebaseFirestore.instance;

  /// ID de conversation unique entre deux utilisateurs
  String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<Message>> streamMessages(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String convId,
    required String senderId,
    required String text,
    required String otherUserId,
    required String otherUserName,
    required String senderName,
    Map<String, dynamic>? productRef,
  }) async {
    final batch = _db.batch();

    // Ajouter le message
    final msgRef = _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'sender_id': senderId,
      'text': text,
      'created_at': Timestamp.now(),
      if (productRef != null) 'product_ref': productRef,
    });

    // Métadonnées conversation
    final lastMsg = productRef != null
        ? '📦 ${productRef['nom'] ?? 'Produit partagé'}'
        : text;
    final convRef = _db.collection('conversations').doc(convId);
    batch.set(convRef, {
      'participants': [senderId, otherUserId],
      'participant_names': {senderId: senderName, otherUserId: otherUserName},
      'last_message': lastMsg,
      'last_message_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Vérifie si une conversation a déjà des messages
  Future<bool> hasMessages(String convId) async {
    final snap = await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Stream<List<Map<String, dynamic>>> streamConversations(String uid) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              return {'id': d.id, ...data};
            }).toList());
  }
}
