import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/commerce_service.dart';
import '../services/favorite_service.dart';

// FavoritesScreen doit être StatefulWidget pour cacher le stream dans initState.
// Si laissé StatelessWidget, FavoriteService.streamFavorites() est appelé à
// chaque rebuild, créant une nouvelle souscription Firestore (stream cold via
// async*), ce qui provoque des freezes Android.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Stream caché dans initState : une seule souscription Firestore,
  // même si le widget est rebuilté plusieurs fois.
  late final Stream<List<Commerce>> _favoritesStream;

  @override
  void initState() {
    super.initState();
    _favoritesStream = FavoriteService.streamFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Commerce>>(
      stream: _favoritesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final favorites = snapshot.data ?? [];

        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_outline,
                    size: 80, color: colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(l.favoritesEmpty, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  l.favoritesEmptyHint,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                l.favoritesTitle,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              pinned: true,
              floating: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final commerce = favorites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FavoriteCard(commerce: commerce),
                    );
                  },
                  childCount: favorites.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Carte favori ─────────────────────────────────────────────────────────────

class _FavoriteCard extends StatelessWidget {
  final Commerce commerce;

  const _FavoriteCard({required this.commerce});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push(Routes.boutique, extra: commerce),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Logo
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: commerce.logoUrl != null
                    ? CachedNetworkImageProvider(commerce.logoUrl!)
                    : null,
                child: commerce.logoUrl == null
                    ? Icon(
                        commerce.type == CommerceType.etablissement
                            ? Icons.business_center
                            : Icons.storefront,
                        size: 28,
                        color: colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commerce.nomBoutique,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            commerce.typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            commerce.categorie,
                            style: textTheme.bodySmall?.copyWith(
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
              // Bouton retirer des favoris
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                tooltip: AppLocalizations.of(context)!.removeFromFavorites,
                onPressed: () async {
                  await FavoriteService.toggle(commerce.id!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
