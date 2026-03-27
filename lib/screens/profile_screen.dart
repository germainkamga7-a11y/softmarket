import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../services/commerce_service.dart';

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
    final l = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.delete),
        content: Text(
            'Supprimer "${commerce.nomBoutique}" définitivement ?\nCette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await CommerceService().deleteCommerce(commerce.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.commerceDeleted)),
      );
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final l = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.signOutDialogTitle),
        content: Text(l.signOutMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.confirm)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AppAuthProvider>().signOut();
    // go_router redirige automatiquement vers /login via refreshListenable
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
        final verificationStatus =
            data['verification_status'] as String? ?? 'none';
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
                      // Nom + téléphone + badge vérification
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (verificationStatus == 'verified') ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: 'Identité vérifiée',
                                    child: Icon(Icons.verified,
                                        color: Colors.greenAccent, size: 18),
                                  ),
                                ],
                              ],
                            ),
                            if (phone.isNotEmpty)
                              Text(
                                phone,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                ),
                              ),
                            const SizedBox(height: 6),
                            _VerificationBadge(
                              status: verificationStatus,
                              onTap: () => context.push(Routes.verification),
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
                          label: l.cityLabel,
                          value: ville.isEmpty ? l.notProvided : ville,
                        ),
                        if (createdAt != null) ...[
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          _InfoTile(
                            icon: Icons.calendar_today_outlined,
                            label: l.memberSince,
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
                          l.myShops,
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(Routes.addBoutique),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l.create),
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
                                      l.loadShopsError,
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
                                  Text(l.noShop, style: textTheme.titleSmall),
                                  const SizedBox(height: 6),
                                  Text(
                                    l.noShopSubtitle,
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
                                    onVisit: () => context.push(Routes.boutique, extra: c),
                                    onEdit: () => context.push(Routes.addBoutique, extra: c),
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
                    child: Text(l.settings,
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
                            title: Text(l.messages),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.conversations),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                            title: Text(l.myOrders),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.orders),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.notifications_outlined, color: colorScheme.primary),
                            title: Text(l.notifications),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.notifications),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.security_outlined, color: colorScheme.primary),
                            title: Text(l.securityPin),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.security),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.privacy_tip_outlined, color: colorScheme.primary),
                            title: Text(l.privacyPolicy),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.privacy),
                          ),
                          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
                          ListTile(
                            leading: Icon(Icons.help_outline, color: colorScheme.primary),
                            title: Text(l.helpSupport),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(Routes.help),
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
                      label: Text(l.signOutButton,
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
                itemBuilder: (ctx) {
                  final l = AppLocalizations.of(ctx)!;
                  return [
                    PopupMenuItem(
                      value: 'visit',
                      child: Row(children: [
                        const Icon(Icons.visibility_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(l.visitShop),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(l.edit),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(l.delete,
                            style: const TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ];
                },
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
    final username = _nomCtrl.text.trim();
    if (username.isEmpty || username.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom doit contenir au moins 2 caractères.')),
      );
      return;
    }
    if (username.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom ne peut pas dépasser 50 caractères.')),
      );
      return;
    }
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
    final l = AppLocalizations.of(context)!;
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
              l.editProfile,
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
                labelText: '${l.usernameLabel} *',
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
                labelText: l.cityLabel,
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
              label: Text(_saving ? l.saving : l.save),
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

// ─── Badge de vérification ────────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  final String status; // 'none' | 'pending' | 'verified' | 'rejected'
  final VoidCallback onTap;

  const _VerificationBadge({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (status == 'verified') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 11, color: Colors.white),
            SizedBox(width: 4),
            Text('Identité vérifiée',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 11, color: Colors.white),
            SizedBox(width: 4),
            Text('Vérification en cours',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    // none ou rejected → bouton pour démarrer/réessayer
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: status == 'rejected'
              ? Colors.red.shade700
              : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.6), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'rejected' ? Icons.refresh : Icons.shield_outlined,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              status == 'rejected'
                  ? 'Refusé — Réessayer'
                  : 'Vérifier mon identité',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
