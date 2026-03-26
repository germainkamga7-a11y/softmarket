import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/commerce_service.dart';
import 'add_boutique_screen.dart';
import 'boutique_screen.dart';
import 'conversations_screen.dart';
import 'help_screen.dart';
import 'orders_list_screen.dart';
import 'notifications_screen.dart';
import 'privacy_policy_screen.dart';
import 'security_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _uploadingAvatar = false;

  // Streams cachés dans initState pour éviter une nouvelle souscription
  // Firestore à chaque rebuild (chaque rebuild appelait CommerceService() et
  // FirebaseFirestore.instance…snapshots(), créant un nouveau listener).
  late final Stream<DocumentSnapshot> _userStream;
  late final Stream<List<Commerce>> _userBoutiquesStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots();
    _userBoutiquesStream = CommerceService().streamUserBoutiques(_uid);
  }

  // ─── Upload avatar ────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final ref =
          FirebaseStorage.instance.ref('users/$_uid/avatar.jpg');
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(file.path));
      }
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set({'avatar_url': url}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ─── Édition profil ───────────────────────────────────────────────────────

  void _showEditSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(uid: _uid, data: data),
    );
  }

  // ─── Supprimer commerce ───────────────────────────────────────────────────

  Future<void> _deleteCommerce(Commerce commerce) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(
            'Supprimer "${commerce.nomBoutique}" définitivement ?\nCette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await CommerceService().deleteCommerce(commerce.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commerce supprimé')),
      );
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content:
            const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déconnecter')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AppAuthProvider>().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Créer le document utilisateur s'il n'existe pas encore (connexion sans inscription)
        if (!snapshot.data!.exists) {
          FirebaseFirestore.instance.collection('users').doc(_uid).set({
            'username': FirebaseAuth.instance.currentUser?.displayName ?? '',
            'phone': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
            'created_at': Timestamp.now(),
          }, SetOptions(merge: true));
        }

        final data =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final username =
            data['username'] as String? ?? 'Utilisateur';
        final ville = data['ville'] as String? ?? '';
        final phone =
            FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
        final avatarUrl = data['avatar_url'] as String?;
        final createdAt = data['created_at'] is Timestamp
            ? (data['created_at'] as Timestamp).toDate()
            : null;

        return Column(
          children: [
            // ─── Header coloré ──────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Row(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white24,
                              backgroundImage: avatarUrl != null
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : avatarUrl == null
                                      ? Icon(Icons.person,
                                          size: 40, color: colorScheme.onPrimary)
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.edit, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Nom + téléphone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        onPressed: () => _showEditSheet(data),
                        tooltip: 'Modifier le profil',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Contenu scrollable ─────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // ─── Carte infos ──────────────────────────────────
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.location_city_outlined,
                          label: 'Ville',
                          value: ville.isEmpty ? 'Non renseignée' : ville,
                        ),
                        if (createdAt != null) ...[
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          _InfoTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Membre depuis',
                            value: DateFormat('MMMM yyyy', 'fr_FR').format(createdAt),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ─── Mes boutiques ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mes boutiques & établissements',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AddBoutiqueScreen())),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Créer'),
                        ),
                      ],
                    ),
                  ),

                  StreamBuilder<List<Commerce>>(
                    stream: _userBoutiquesStream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator()));
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: colorScheme.error),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Impossible de charger les boutiques',
                                      style: TextStyle(color: colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                children: [
                                  Icon(Icons.storefront_outlined,
                                      size: 48, color: colorScheme.outlineVariant),
                                  const SizedBox(height: 12),
                                  Text('Aucune boutique', style: textTheme.titleSmall),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Créez votre première boutique ou établissement',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: list
                            .map((c) => Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: _BoutiqueListTile(
                                    commerce: c,
                                    onVisit: () => Navigator.push(context,
                                        MaterialPageRoute(
                                            builder: (_) => BoutiqueScreen(commerce: c))),
                                    onEdit: () => Navigator.push(context,
                                        MaterialPageRoute(
                                            builder: (_) => AddBoutiqueScreen(boutique: c))),
                                    onDelete: () => _deleteCommerce(c),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),

                  // ─── Paramètres ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Paramètres',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.chat_outlined, color: colorScheme.primary),
                            title: const Text('Messages'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ConversationsScreen())),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                            title: const Text('Mes commandes'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const OrdersListScreen())),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.notifications_outlined, color: colorScheme.primary),
                            title: const Text('Notifications'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.security_outlined, color: colorScheme.primary),
                            title: const Text('Sécurité & PIN'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SecurityScreen())),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.privacy_tip_outlined, color: colorScheme.primary),
                            title: const Text('Politique de confidentialité'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.help_outline, color: colorScheme.primary),
                            title: const Text('Aide & Support'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const HelpScreen())),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Déconnexion ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout, color: colorScheme.error),
                      label: Text('Se déconnecter',
                          style: TextStyle(color: colorScheme.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: colorScheme.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Tile info profil ─────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant)),
              Text(value,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tile boutique dans le profil ─────────────────────────────────────────────

class _BoutiqueListTile extends StatelessWidget {
  final Commerce commerce;
  final VoidCallback onVisit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BoutiqueListTile({
    required this.commerce,
    required this.onVisit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onVisit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Logo ou icône
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: commerce.logoUrl != null
                    ? CachedNetworkImageProvider(commerce.logoUrl!)
                    : null,
                child: commerce.logoUrl == null
                    ? Icon(
                        commerce.type == CommerceType.etablissement
                            ? Icons.business_center
                            : Icons.storefront,
                        size: 22,
                        color: colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commerce.nomBoutique,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            commerce.typeLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            commerce.categorie,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                  if (v == 'visit') onVisit();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'visit',
                    child: Row(children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Voir la boutique'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet édition profil ─────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;

  const _EditProfileSheet({required this.uid, required this.data});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _villeCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl =
        TextEditingController(text: widget.data['username'] ?? '');
    _villeCtrl =
        TextEditingController(text: widget.data['ville'] ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({
        'username': _nomCtrl.text.trim(),
        'ville': _villeCtrl.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modifier le profil',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nom d\'utilisateur *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _villeCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Ville',
                prefixIcon:
                    const Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
