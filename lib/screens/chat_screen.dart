import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final Map<String, dynamic>? productRef;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.productRef,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _currentUid;
  late final String _convId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser!.uid;
    _convId = _chatService.conversationId(_currentUid, widget.otherUserId);

    if (widget.productRef != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeSendProductCard();
      });
    }
  }

  /// Envoie la carte produit automatiquement si c'est le premier message
  Future<void> _maybeSendProductCard() async {
    if (!mounted) return;
    try {
      final already = await _chatService.hasMessages(_convId);
      if (!mounted || already) return;
      final user = FirebaseAuth.instance.currentUser!;
      final senderName =
          user.displayName ?? user.phoneNumber ?? user.email ?? 'Utilisateur';
      await _chatService.sendMessage(
        convId: _convId,
        senderId: _currentUid,
        text: '',
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
        senderName: senderName,
        productRef: widget.productRef,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final senderName =
          user.displayName ?? user.phoneNumber ?? user.email ?? 'Utilisateur';
      await _chatService.sendMessage(
        convId: _convId,
        senderId: _currentUid,
        text: text,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
        senderName: senderName,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _msgCtrl.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.store, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUserName,
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                  Text('Commerçant vérifié ✓',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.streamMessages(_convId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Démarrez la conversation',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _currentUid;
                    return _MessageBubble(
                        message: msg, isMe: isMe, colorScheme: colorScheme);
                  },
                );
              },
            ),
          ),

          // ─── Saisie message ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Écrire un message...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final ColorScheme colorScheme;

  const _MessageBubble(
      {required this.message,
      required this.isMe,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (message.productRef != null) {
      return _buildProductCard(context);
    }
    return _buildTextBubble(context);
  }

  // ── Carte produit ──────────────────────────────────────────────────────────

  Widget _buildProductCard(BuildContext context) {
    final ref = message.productRef!;
    final imageUrl = ref['imageUrl'] as String?;
    final nom = (ref['nom'] as String?) ?? 'Produit';
    final prix = (ref['prix'] as num?)?.toDouble() ?? 0;
    final categorie = (ref['categorie'] as String?) ?? '';
    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête "Produit partagé"
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: AppColors.boutique.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 13, color: AppColors.boutique),
                  SizedBox(width: 6),
                  Text(
                    'Produit partagé',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.boutique,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Contenu produit
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 64,
                              height: 64,
                              color: AppColors.boutiqueLight,
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: AppColors.boutiqueLight,
                            child: const Icon(Icons.inventory_2_outlined,
                                color: AppColors.boutique, size: 28),
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.price,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${prix.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              color: AppColors.priceText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (categorie.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            categorie,
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Heure
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$h:$m',
                  style: TextStyle(
                      fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bulle texte classique ──────────────────────────────────────────────────

  Widget _buildTextBubble(BuildContext context) {
    final h = message.createdAt.hour.toString().padLeft(2, '0');
    final m = message.createdAt.minute.toString().padLeft(2, '0');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$h:$m',
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? colorScheme.onPrimary.withValues(alpha: 0.7)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
