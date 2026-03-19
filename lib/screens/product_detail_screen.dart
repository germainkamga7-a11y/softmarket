import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/commerce_service.dart';
import '../theme/app_colors.dart';
import 'boutique_screen.dart';
import 'chat_screen.dart';

// ─── Fonction globale : ouvrir le détail produit en popup ─────────────────────

void showProductDetail(
  BuildContext context, {
  required String docId,
  required String nom,
  required String description,
  required double prix,
  required String categorie,
  required List<String> imageUrls,
  required Commerce commerce,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductDetailModal(
      docId: docId,
      nom: nom,
      description: description,
      prix: prix,
      categorie: categorie,
      imageUrls: imageUrls,
      commerce: commerce,
    ),
  );
}

// ─── Modal détail produit ─────────────────────────────────────────────────────

class _ProductDetailModal extends StatefulWidget {
  final String docId;
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final List<String> imageUrls;
  final Commerce commerce;

  const _ProductDetailModal({
    required this.docId,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
    required this.imageUrls,
    required this.commerce,
  });

  @override
  State<_ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<_ProductDetailModal> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isService = widget.commerce.type == CommerceType.etablissement;
    final accentColor = isService ? AppColors.etablissement : AppColors.boutique;
    final accentLight = isService ? AppColors.etablissementLight : AppColors.boutiqueLight;
    final typeLabel = isService ? 'Service' : 'Produit';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Galerie photos ─────────────────────────────────────
                  if (widget.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: widget.imageUrls.length,
                              onPageChanged: (i) => setState(() => _currentPage = i),
                              itemBuilder: (_, i) => CachedNetworkImage(
                                imageUrl: widget.imageUrls[i],
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: accentLight,
                                  child: Center(
                                    child: CircularProgressIndicator(color: accentColor, strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Gradient bas
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            height: 60,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                                ),
                              ),
                            ),
                          ),
                          // Dots
                          if (widget.imageUrls.length > 1)
                            Positioned(
                              bottom: 12, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(widget.imageUrls.length, (i) =>
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _currentPage == i ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _currentPage == i ? Colors.white : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Compteur
                          if (widget.imageUrls.length > 1)
                            Positioned(
                              top: 12, right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_currentPage + 1}/${widget.imageUrls.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    // Placeholder sans image
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: accentLight,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Icon(
                        isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
                        size: 64,
                        color: accentColor.withValues(alpha: 0.5),
                      ),
                    ),

                  // ─── Contenu ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type + Prix
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isService ? Icons.design_services : Icons.inventory_2,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.categorie,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.price,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.prix.toStringAsFixed(0)} FCFA',
                                style: textTheme.titleSmall?.copyWith(
                                  color: AppColors.priceText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Nom
                        Text(
                          widget.nom,
                          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        // Description
                        if (widget.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),

                        // Vendu par
                        Text('Vendu par',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BoutiqueScreen(commerce: widget.commerce)),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: accentLight,
                                  backgroundImage: widget.commerce.logoUrl != null
                                      ? CachedNetworkImageProvider(widget.commerce.logoUrl!)
                                      : null,
                                  child: widget.commerce.logoUrl == null
                                      ? Icon(
                                          isService ? Icons.business_center : Icons.storefront,
                                          size: 20,
                                          color: accentColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.commerce.nomBoutique,
                                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      Text(widget.commerce.categorie,
                                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Boutons d'action (fixes en bas) ─────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BoutiqueScreen(commerce: widget.commerce)),
                      );
                    },
                    icon: Icon(isService ? Icons.business_center_outlined : Icons.storefront_outlined, size: 18),
                    label: const Text('La boutique'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            otherUserId: widget.commerce.userId,
                            otherUserName: widget.commerce.nomBoutique,
                            productRef: {
                              'id': widget.docId,
                              'nom': widget.nom,
                              'prix': widget.prix,
                              'imageUrl': widget.imageUrls.isNotEmpty
                                  ? widget.imageUrls.first
                                  : null,
                              'categorie': widget.categorie,
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Contacter'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page complète (gardée pour compatibilité navigation directe) ──────────────

class ProductDetailScreen extends StatefulWidget {
  final String docId;
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final List<String> imageUrls;
  final Commerce commerce;

  const ProductDetailScreen({
    super.key,
    required this.docId,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
    required this.imageUrls,
    required this.commerce,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Ouvrir directement en popup dès que l'écran est monté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
        showProductDetail(
          context,
          docId: widget.docId,
          nom: widget.nom,
          description: widget.description,
          prix: widget.prix,
          categorie: widget.categorie,
          imageUrls: widget.imageUrls,
          commerce: widget.commerce,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
