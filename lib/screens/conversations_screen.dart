import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

// ConversationsScreen doit être StatefulWidget pour cacher le stream dans
// initState. Un StatelessWidget appelant ChatService().streamConversations()
// dans build() crée une nouvelle instance de ChatService et une nouvelle
// souscription Firestore à chaque rebuild, saturant la connexion réseau et
// provoquant des freezes Android.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  // Stream caché : une seule souscription Firestore pendant toute la vie du widget.
  late final Stream<List<Map<String, dynamic>>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _conversationsStream = ChatService().streamConversations(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
        titleTextStyle: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _conversationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final convs = snapshot.data ?? [];

          if (convs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 80,
                      color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('Aucune conversation',
                      style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Contactez un commerçant\npour démarrer une conversation',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: convs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final conv = convs[index];
              final participants =
                  (conv['participants'] as List?)?.cast<String>() ??
                      [];
              final names = (conv['participant_names']
                      as Map<String, dynamic>?) ??
                  {};
              final otherUid =
                  participants.firstWhere((p) => p != uid, orElse: () => '');
              final otherName =
                  names[otherUid] as String? ?? 'Utilisateur';
              final lastMsg =
                  conv['last_message'] as String? ?? '...';
              final updatedAt = conv['updated_at'] is Timestamp
                  ? (conv['updated_at'] as Timestamp).toDate()
                  : DateTime.now();

              return _ConversationTile(
                convId: conv['id'] as String,
                otherUid: otherUid,
                otherName: otherName,
                lastMessage: lastMsg,
                updatedAt: updatedAt,
                currentUid: uid,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Tuile conversation ───────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String convId;
  final String otherUid;
  final String otherName;
  final String lastMessage;
  final DateTime updatedAt;
  final String currentUid;

  const _ConversationTile({
    required this.convId,
    required this.otherUid,
    required this.otherName,
    required this.lastMessage,
    required this.updatedAt,
    required this.currentUid,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE', 'fr_FR').format(dt);
    return DateFormat('dd/MM', 'fr_FR').format(dt);
  }

  String get _initials {
    final parts = otherName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: otherUid,
            otherUserName: otherName,
          ),
        ),
      ),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          _initials,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        otherName,
        style:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        lastMessage,
        style: textTheme.bodySmall
            ?.copyWith(color: colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(updatedAt),
        style: textTheme.labelSmall
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
