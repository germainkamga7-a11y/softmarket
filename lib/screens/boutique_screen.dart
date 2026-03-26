import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';

import '../services/commerce_service.dart';
import '../services/mobile_money_service.dart';
import '../services/report_service.dart';
import '../services/review_service.dart';
import '../services/social_auth_service.dart';
import '../theme/app_colors.dart';
import 'product_detail_screen.dart';

class BoutiqueScreen extends StatefulWidget {
  final Commerce commerce;
  const BoutiqueScreen({super.key, required this.commerce});

  @override
  State<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends State<BoutiqueScreen> {
  late final Stream<QuerySnapshot> _produitsStream;
  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.commerce.userId;

  Color get _themeColor => AppColors.forType(widget.commerce.type);

  // ─── Logo state ─────────────────────────────────────────────────────────────
  String? _logoUrl;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _logoUrl = widget.commerce.logoUrl;
    _produitsStream = FirebaseFirestore.instance
        .collection('produits')
        .where('commerce_id', isEqualTo: widget.commerce.id)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> _updateLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingLogo = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('commerces/${widget.commerce.id}/logo.jpg');
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(file.path));
      }
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('commercants')
          .doc(widget.commerce.id)
          .update({'logo_url': url});
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour du logo : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  void _showReviewSheet(
      BuildContext context, Map<String, dynamic>? existing) {
    if (!SocialAuthService.requireAccount(context)) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        commerceId: widget.commerce.id!,
        existing: existing,
      ),
    );
  }

  void _shareBoutique() {
    final nom = widget.commerce.nomBoutique;
    final cat = widget.commerce.categorie;
    final desc = widget.commerce.description.isNotEmpty
        ? '\n${widget.commerce.description}'
        : '';
    Share.share(
      '🛒 Découvre $nom sur CamerMarket !\n$cat$desc',
      subject: nom,
    );
  }

  void _showAddProduitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProduitSheet(
        commerce: widget.commerce,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Header boutique ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Partager',
                onPressed: _shareBoutique,
              ),
              if (_isOwner)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifier la boutique',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _EditBoutiqueSheet(commerce: widget.commerce),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Signaler cette boutique',
                  onPressed: () => showReportDialog(
                    context,
                    targetType: ReportTargetType.commerce,
                    targetId: widget.commerce.id!,
                    targetName: widget.commerce.nomBoutique,
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _themeColor,
                      _themeColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _isOwner ? _updateLogo : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white24,
                                backgroundImage: _logoUrl != null
                                    ? CachedNetworkImageProvider(_logoUrl!)
                                    : null,
                                child: _uploadingLogo
                                    ? const SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : _logoUrl == null
                                        ? Icon(
                                            widget.commerce.type ==
                                                    CommerceType.etablissement
                                                ? Icons.business_center
                                                : Icons.storefront,
                                            size: 40,
                                            color: colorScheme.onPrimary,
                                          )
                                        : null,
                              ),
                              if (_isOwner)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _themeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.edit,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.commerce.nomBoutique,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.commerce.typeLabel,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (widget.commerce.verified) ...[
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(Icons.verified, size: 14, color: Colors.greenAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Commerçant vérifié',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Depuis ${widget.commerce.createdAt.day}/${widget.commerce.createdAt.month}/${widget.commerce.createdAt.year}',
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimary
                                        .withValues(alpha: 0.8)),
                              ),
                              const SizedBox(height: 4),
                              StreamBuilder<Map<String, dynamic>>(
                                stream: ReviewService.streamAggregate(
                                    widget.commerce.id!),
                                builder: (context, snap) {
                                  final data = snap.data ?? {};
                                  final avg = (data['avg_rating'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final count =
                                      (data['count'] as int?) ?? 0;
                                  if (count == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Row(
                                    children: [
                                      ...List.generate(
                                        5,
                                        (i) => Icon(
                                          i < avg.round()
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${avg.toStringAsFixed(1)} ($count avis)',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Infos contact ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (widget.commerce.description.isNotEmpty) ...[
                    Text(
                      widget.commerce.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Boutons contact
                  Row(
                    children: [
                      if (widget.commerce.telephone.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final tel = widget.commerce.telephone
                                  .replaceAll(' ', '');
                              final number = tel.startsWith('+')
                                  ? tel
                                  : '+237$tel';
                              final uri = Uri(scheme: 'tel', path: number);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.phone_outlined, size: 18),
                            label: Text(
                              widget.commerce.telephone.isNotEmpty
                                  ? widget.commerce.telephone
                                  : 'Appeler',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _themeColor,
                              side: BorderSide(color: _themeColor),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => showMobileMoneySheet(
                            context,
                            commerce: widget.commerce,
                          ),
                          icon: const Icon(Icons.mobile_friendly, size: 18),
                          label: const Text('Mobile Money'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB300),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),

          // ─── Titre section ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.commerce.type == CommerceType.etablissement
                    ? 'Services proposés'
                    : 'Produits disponibles',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),

          // ─── Liste produits ───────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: _produitsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator())),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            widget.commerce.type == CommerceType.etablissement
                                ? Icons.miscellaneous_services_outlined
                                : Icons.inventory_2_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            widget.commerce.type == CommerceType.etablissement
                                ? 'Aucun service pour l\'instant'
                                : 'Aucun produit pour l\'instant',
                            style: textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            _isOwner
                                ? 'Appuyez sur + pour ajouter votre premier élément.'
                                : widget.commerce.type == CommerceType.etablissement
                                    ? 'L\'établissement n\'a pas encore ajouté de services.'
                                    : 'La boutique n\'a pas encore ajouté de produits.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 900
                        ? 4
                        : MediaQuery.of(context).size.width > 600
                            ? 3
                            : 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      // Backward compat: support both image_urls (array) and image_url (string)
                      final rawUrls = data['image_urls'];
                      final List<String> imageUrls;
                      if (rawUrls is List && rawUrls.isNotEmpty) {
                        imageUrls = rawUrls.cast<String>();
                      } else if (data['image_url'] is String &&
                          (data['image_url'] as String).isNotEmpty) {
                        imageUrls = [data['image_url'] as String];
                      } else {
                        imageUrls = [];
                      }
                      return _ProduitCard(
                        docId: doc.id,
                        nom: data['nom'] as String? ?? '',
                        description: data['description'] as String? ?? '',
                        prix: (data['prix'] as num?)?.toDouble() ?? 0,
                        categorie: data['categorie'] as String? ?? '',
                        imageUrls: imageUrls,
                        commerce: widget.commerce,
                        isOwner: _isOwner,
                        disponible: data['disponible'] as bool? ?? true,
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
          // ─── Section Avis ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Avis clients',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!_isOwner)
                    StreamBuilder<Map<String, dynamic>?>(
                      stream: ReviewService.streamMyReview(widget.commerce.id!),
                      builder: (context, snap) {
                        final hasReview = snap.data != null;
                        return TextButton.icon(
                          onPressed: () => _showReviewSheet(
                              context, snap.data),
                          icon: Icon(
                            hasReview ? Icons.edit : Icons.rate_review,
                            size: 16,
                          ),
                          label:
                              Text(hasReview ? 'Modifier' : 'Laisser un avis'),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ReviewService.streamReviews(widget.commerce.id!),
            builder: (context, snap) {
              final reviews = snap.data ?? [];
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (reviews.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Aucun avis pour l\'instant. Soyez le premier à donner votre avis !',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ReviewTile(review: reviews[i]),
                    childCount: reviews.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // FAB visible uniquement pour le propriétaire
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: _showAddProduitDialog,
              icon: const Icon(Icons.add),
              label: Text(
                widget.commerce.type == CommerceType.etablissement
                    ? 'Ajouter un service'
                    : 'Ajouter un produit',
              ),
            )
          : null,
    );
  }
}

// ─── Bottom sheet ajout produit ───────────────────────────────────────────────

class _AddProduitSheet extends StatefulWidget {
  final Commerce commerce;
  const _AddProduitSheet({required this.commerce});

  @override
  State<_AddProduitSheet> createState() => _AddProduitSheetState();
}

class _AddProduitSheetState extends State<_AddProduitSheet> {
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  String _categorie = 'Alimentation';
  final List<XFile> _imageFiles = [];
  bool _uploading = false;
  double _uploadProgress = 0;

  bool get _isBoutique => widget.commerce.type == CommerceType.boutique;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageFiles.length >= 4) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file != null) setState(() => _imageFiles.add(file));
  }

  void _removeImage(int index) {
    setState(() => _imageFiles.removeAt(index));
  }

  Future<List<String>> _uploadImages(String produitId) async {
    final urls = <String>[];
    for (var i = 0; i < _imageFiles.length; i++) {
      final file = _imageFiles[i];
      final ref = FirebaseStorage.instance
          .ref('produits/${widget.commerce.id}/${produitId}_$i.jpg');
      UploadTask task;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        task = ref.putFile(File(file.path));
      }
      task.snapshotEvents.listen((snap) {
        if (mounted) {
          setState(() => _uploadProgress =
              (i + snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes)) /
              _imageFiles.length);
        }
      });
      await task;
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    if (_prixCtrl.text.trim().isEmpty) return;
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins une photo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      // 1. Créer le document produit pour avoir un ID
      final ref = await FirebaseFirestore.instance.collection('produits').add({
        'commerce_id': widget.commerce.id,
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'prix': double.tryParse(_prixCtrl.text.trim()) ?? 0,
        'categorie': _categorie,
        'image_url': null,
        'created_at': Timestamp.now(),
      });

      // 2. Upload des images avec l'ID du document
      final imageUrls = await _uploadImages(ref.id);

      // 3. Mettre à jour le document avec les URLs des images
      if (imageUrls.isNotEmpty) {
        await ref.update({
          'image_urls': imageUrls,
          'image_url': imageUrls.first, // backward compat
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categories = _isBoutique
        ? Commerce.categoriesBoutique
        : Commerce.categoriesEtablissement;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
              _isBoutique ? 'Ajouter un produit' : 'Ajouter un service',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ─── Zone photos ───────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Photos (${_imageFiles.length}/4) *',
                      style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_imageFiles.isNotEmpty && _imageFiles.length < 4)
                      TextButton.icon(
                        onPressed: _uploading ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: const Text('Ajouter'),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_imageFiles.isEmpty)
                  GestureDetector(
                    onTap: _uploading ? null : _pickImage,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colorScheme.outlineVariant, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6)),
                          const SizedBox(height: 8),
                          Text(
                            'Ajouter des photos *',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jusqu\'à 4 photos depuis la galerie',
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageFiles.length < 4
                          ? _imageFiles.length + 1
                          : _imageFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        // Bouton "+" à la fin si < 4 photos
                        if (i == _imageFiles.length) {
                          return GestureDetector(
                            onTap: _uploading ? null : _pickImage,
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: colorScheme.outlineVariant,
                                    style: BorderStyle.solid),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 28,
                                      color: colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 4),
                                  Text('Ajouter',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          );
                        }
                        // Miniature photo
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(
                                      _imageFiles[i].path,
                                      width: 100,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_imageFiles[i].path),
                                      width: 100,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(i),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            if (i == 0)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Principale',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Nom
            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _isBoutique ? 'Nom du produit *' : 'Nom du service *',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Prix
            TextField(
              controller: _prixCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Prix (FCFA) *',
                suffixText: 'FCFA',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Catégorie
            DropdownButtonFormField<String>(
              initialValue: categories.contains(_categorie) ? _categorie : categories.first,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Catégorie',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categorie = v!),
            ),
            const SizedBox(height: 20),

            // Barre de progression upload
            if (_uploading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text(
                _uploadProgress < 1
                    ? 'Upload en cours... ${(_uploadProgress * 100).toInt()}%'
                    : 'Finalisation...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_uploading ? 'Enregistrement...' : 'Ajouter'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
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

// ─── Bottom sheet modifier produit ─────────────────────────────────────────

class _EditProduitSheet extends StatefulWidget {
  final String docId;
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final List<String> existingImageUrls;
  final Commerce commerce;

  const _EditProduitSheet({
    required this.docId,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
    required this.existingImageUrls,
    required this.commerce,
  });

  @override
  State<_EditProduitSheet> createState() => _EditProduitSheetState();
}

class _EditProduitSheetState extends State<_EditProduitSheet> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _prixCtrl;
  late String _categorie;
  late List<String> _existingUrls;
  final List<XFile> _newFiles = [];
  bool _uploading = false;
  double _uploadProgress = 0;

  bool get _isBoutique => widget.commerce.type == CommerceType.boutique;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.nom);
    _descCtrl = TextEditingController(text: widget.description);
    _prixCtrl = TextEditingController(text: widget.prix.toStringAsFixed(0));
    _categorie = widget.categorie;
    _existingUrls = List.from(widget.existingImageUrls);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  int get _totalImages => _existingUrls.length + _newFiles.length;

  Future<void> _pickImage() async {
    if (_totalImages >= 4) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file != null) setState(() => _newFiles.add(file));
  }

  Future<List<String>> _uploadNewImages() async {
    final urls = <String>[];
    for (var i = 0; i < _newFiles.length; i++) {
      final file = _newFiles[i];
      final ref = FirebaseStorage.instance
          .ref('produits/${widget.commerce.id}/${widget.docId}_new_$i.jpg');
      UploadTask task;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        task = ref.putFile(File(file.path));
      }
      task.snapshotEvents.listen((snap) {
        if (mounted) {
          setState(() => _uploadProgress =
              (i + snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes)) /
              _newFiles.length);
        }
      });
      await task;
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_nomCtrl.text.trim().isEmpty || _prixCtrl.text.trim().isEmpty) return;
    if (_totalImages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez garder au moins une photo'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() { _uploading = true; _uploadProgress = 0; });

    try {
      List<String> newUrls = [];
      if (_newFiles.isNotEmpty) {
        newUrls = await _uploadNewImages();
      }

      final allUrls = [..._existingUrls, ...newUrls];

      await FirebaseFirestore.instance.collection('produits').doc(widget.docId).update({
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'prix': double.tryParse(_prixCtrl.text.trim()) ?? 0,
        'categorie': _categorie,
        'image_urls': allUrls,
        'image_url': allUrls.isNotEmpty ? allUrls.first : null,
        'updated_at': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categories = _isBoutique ? Commerce.categoriesBoutique : Commerce.categoriesEtablissement;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isBoutique ? 'Modifier le produit' : 'Modifier le service',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ─── Photos existantes + nouvelles ─────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Photos ($_totalImages/4) *',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_totalImages < 4)
                      TextButton.icon(
                        onPressed: _uploading ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: const Text('Ajouter'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Photos existantes (URLs)
                      ..._existingUrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: e.value,
                                width: 100, height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (e.key == 0)
                              Positioned(
                                bottom: 4, left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Principale', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingUrls.removeAt(e.key)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      // Nouvelles photos (XFile)
                      ..._newFiles.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(e.value.path, width: 100, height: 120, fit: BoxFit.cover)
                                  : Image.file(File(e.value.path), width: 100, height: 120, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _newFiles.removeAt(e.key)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      // Bouton ajouter
                      if (_totalImages < 4)
                        GestureDetector(
                          onTap: _uploading ? null : _pickImage,
                          child: Container(
                            width: 100, height: 120,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 28, color: colorScheme.onSurfaceVariant),
                                const SizedBox(height: 4),
                                Text('Ajouter', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _isBoutique ? 'Nom du produit *' : 'Nom du service *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Prix (FCFA) *',
                suffixText: 'FCFA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: categories.contains(_categorie) ? _categorie : categories.first,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _categorie = v!),
            ),
            const SizedBox(height: 20),

            if (_uploading) ...[
              LinearProgressIndicator(value: _uploadProgress, color: AppColors.forType(widget.commerce.type)),
              const SizedBox(height: 8),
              Text(
                _uploadProgress < 1 ? 'Upload... ${(_uploadProgress * 100).toInt()}%' : 'Finalisation...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ],

            FilledButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_uploading ? 'Enregistrement...' : 'Enregistrer les modifications'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forType(widget.commerce.type),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card produit ─────────────────────────────────────────────────────────────

class _ProduitCard extends StatefulWidget {
  final String docId;
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final List<String> imageUrls;
  final Commerce commerce;
  final bool isOwner;
  final bool disponible;

  const _ProduitCard({
    required this.docId,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
    required this.imageUrls,
    required this.commerce,
    required this.isOwner,
    this.disponible = true,
  });

  @override
  State<_ProduitCard> createState() => _ProduitCardState();
}

class _ProduitCardState extends State<_ProduitCard> {
  int _currentPage = 0;

  // Couleurs selon type (produit=bleu, service=vert)
  Color get _accent => AppColors.forType(widget.commerce.type);
  Color get _accentLight => AppColors.lightForType(widget.commerce.type);
  bool get _isService => widget.commerce.type == CommerceType.etablissement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => showProductDetail(
        context,
        docId: widget.docId,
        nom: widget.nom,
        description: widget.description,
        prix: widget.prix,
        categorie: widget.categorie,
        imageUrls: widget.imageUrls,
        commerce: widget.commerce,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Photo(s) ───────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image(s)
                  widget.imageUrls.isEmpty
                      ? Container(
                          color: _accentLight,
                          child: Icon(
                            _isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
                            size: 36,
                            color: _accent.withValues(alpha: 0.5),
                          ),
                        )
                      : PageView.builder(
                          itemCount: widget.imageUrls.length,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: widget.imageUrls[i],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: _accentLight,
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _accent),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: _accentLight,
                              child: Icon(_isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
                                  size: 36, color: _accent.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),

                  // Gradient léger bas
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                        ),
                      ),
                    ),
                  ),

                  // Dots minimalistes
                  if (widget.imageUrls.length > 1)
                    Positioned(
                      bottom: 5, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.imageUrls.length, (i) =>
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == i ? 12 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Badge type (Produit / Service)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isService ? 'Service' : 'Produit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // Overlay indisponible
                  if (!widget.disponible)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Indisponible',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                      ),
                    ),

                  // Boutons propriétaire (discrets)
                  if (widget.isOwner) ...[
                    Positioned(
                      top: 6, right: 34,
                      child: GestureDetector(
                        onTap: () => _showEditSheet(context),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─── Infos ──────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nom + description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nom,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),

                    // Prix + toggle disponibilité
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.price,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${widget.prix.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              color: AppColors.priceText,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (widget.isOwner) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => FirebaseFirestore.instance
                                .collection('produits')
                                .doc(widget.docId)
                                .update({'disponible': !widget.disponible}),
                            child: Icon(
                              widget.disponible ? Icons.check_circle_outline : Icons.cancel_outlined,
                              size: 14,
                              color: widget.disponible ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProduitSheet(
        docId: widget.docId,
        nom: widget.nom,
        description: widget.description,
        prix: widget.prix,
        categorie: widget.categorie,
        existingImageUrls: widget.imageUrls,
        commerce: widget.commerce,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${widget.nom}" définitivement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('produits')
                  .doc(widget.docId)
                  .delete();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ─── Tuile avis ───────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rating = (review['rating'] as int?) ?? 0;
    final username = review['username'] as String? ?? 'Anonyme';
    final comment = review['comment'] as String? ?? '';
    final createdAt = review['created_at'] is Timestamp
        ? (review['created_at'] as Timestamp).toDate()
        : DateTime.now();
    final dateStr =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 13,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(dateStr,
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sheet avis (créer / modifier / supprimer) ────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final String commerceId;
  final Map<String, dynamic>? existing;
  const _ReviewSheet({required this.commerceId, this.existing});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;
  late final TextEditingController _commentCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _rating = (widget.existing?['rating'] as int?) ?? 5;
    _commentCtrl = TextEditingController(
        text: widget.existing?['comment'] as String? ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final username = user.displayName ?? user.email ?? 'Utilisateur';
    setState(() => _loading = true);
    try {
      await ReviewService.submitReview(
        commerceId: widget.commerceId,
        rating: _rating,
        comment: _commentCtrl.text,
        username: username,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      await ReviewService.deleteReview(widget.commerceId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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
            isEditing ? 'Modifier mon avis' : 'Laisser un avis',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Étoiles
          Text('Note',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Commentaire
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Commentaire (optionnel)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_loading
                ? 'Enregistrement...'
                : isEditing
                    ? 'Mettre à jour'
                    : 'Publier l\'avis'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (isEditing) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer mon avis'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom sheet modifier boutique ──────────────────────────────────────────

class _EditBoutiqueSheet extends StatefulWidget {
  final Commerce commerce;
  const _EditBoutiqueSheet({required this.commerce});

  @override
  State<_EditBoutiqueSheet> createState() => _EditBoutiqueSheetState();
}

class _EditBoutiqueSheetState extends State<_EditBoutiqueSheet> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _telCtrl;
  late String _categorie;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.commerce.nomBoutique);
    _descCtrl = TextEditingController(text: widget.commerce.description);
    _telCtrl = TextEditingController(text: widget.commerce.telephone);
    _categorie = widget.commerce.categorie;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await CommerceService().updateBoutique(
        widget.commerce.id!,
        nomBoutique: _nomCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categorie: _categorie,
        telephone: _telCtrl.text.trim(),
        logoUrl: widget.commerce.logoUrl,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = widget.commerce.type == CommerceType.boutique
        ? Commerce.categoriesBoutique
        : Commerce.categoriesEtablissement;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Modifier la boutique',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nom de la boutique *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                prefixText: '+237 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: categories.contains(_categorie) ? _categorie : categories.first,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _categorie = v!),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forType(widget.commerce.type),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
