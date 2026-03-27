import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/commerce_provider.dart';
import '../router/app_router.dart';
import '../services/cart_service.dart';
import '../services/map_service.dart';
import '../services/commerce_service.dart';
import '../services/favorite_service.dart';
import '../services/social_auth_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'favorites_screen.dart';
import 'orders_list_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';

class CamerMarketScreen extends StatefulWidget {
  const CamerMarketScreen({super.key});

  @override
  State<CamerMarketScreen> createState() => _CamerMarketScreenState();
}

class _CamerMarketScreenState extends State<CamerMarketScreen> {
  int _selectedIndex = 0;
  final MapService _mapService = MapService();
  final CommerceService _commerceService = CommerceService();
  late CommerceProvider _commerceProvider;
  StreamSubscription<Position>? _locationSubscription;

  String? _selectedMapCategory;
  MapType _mapType = MapType.normal;
  LatLng? _userLocation;
  double _userBearing = 0;

  // ── Filtres avancés ────────────────────────────────────────────────────────
  double _maxDistanceKm = 50.0;
  CommerceType? _filterType; // null = tous
  String _sortBy = 'distance'; // 'distance' | 'newest'

  // ── Pagination produits (onglet Accueil) ───────────────────────────────────
  static const int _productsPageSize = 10;
  List<Map<String, dynamic>> _homeProducts = [];
  DocumentSnapshot? _lastProductDoc;
  bool _loadingMoreProducts = false;
  bool _hasMoreProducts = true;

  // Cache de la future de localisation initiale pour la carte.
  // DOIT être créé une seule fois : _buildMapTab() est appelé à chaque
  // rebuild (IndexedStack rend tous les onglets) → sans cache, chaque
  // setState() déclenchait un nouveau Geolocator.getCurrentPosition()
  // créant une boucle GPS qui gelait l'UI.
  late final Future<LatLng> _initialLocationFuture;

  @override
  void initState() {
    super.initState();
    _initialLocationFuture = _mapService.getCurrentLocation();
    _preloadMapIcons();
    _startLocationStream();
    _loadInitialProducts();
    _checkProfile();
  }

  bool _commerceListenerAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_commerceListenerAttached) {
      _commerceListenerAttached = true;
      _commerceProvider = context.read<CommerceProvider>();
      _commerceProvider.addListener(_onCommercesUpdated);
    }
  }

  void _onCommercesUpdated() {
    if (mounted) {
      setState(() {});
      _updateMapMarkers();
    }
  }

  // Redirige vers /register si le profil Firestore n'existe pas encore
  // (cas : auto-vérification Android avant fin d'inscription).
  Future<void> _checkProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.register);
      });
    }
  }

  Future<void> _loadInitialProducts() async {
    final result = await _commerceService.fetchProductsPage(
        limit: _productsPageSize);
    if (mounted) {
      setState(() {
        _homeProducts = result.items;
        _lastProductDoc = result.lastDoc;
        _hasMoreProducts = result.items.length == _productsPageSize;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingMoreProducts || !_hasMoreProducts) return;
    setState(() => _loadingMoreProducts = true);
    final result = await _commerceService.fetchProductsPage(
      limit: _productsPageSize,
      startAfter: _lastProductDoc,
    );
    if (mounted) {
      setState(() {
        _homeProducts.addAll(result.items);
        _lastProductDoc = result.lastDoc;
        _hasMoreProducts = result.items.length == _productsPageSize;
        _loadingMoreProducts = false;
      });
    }
  }

  Future<void> _preloadMapIcons() async {
    try {
      await _mapService.preloadIcons();
    } catch (e) {
      debugPrint('[CamerMarket] preloadIcons ignoré : $e');
    }
  }

  Future<void> _startLocationStream() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Vérifier mounted après un gap async (la permission dialog peut prendre du temps)
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) { return; }

    _locationSubscription = _mapService.startLocationStream().listen((position) {
      final loc = LatLng(position.latitude, position.longitude);
      _mapService.updateUserPosition(loc);
      _updateMapMarkers();
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _userBearing = position.heading;
        });
      }
    });
  }

  void _updateMapMarkers() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    _mapService.updateCommerceMarkers(
      _filteredCommerces.map((c) => (
        id: c.id ?? '',
        position: c.position,
        nom: c.nomBoutique,
        type: c.type,
        isOwner: currentUid != null && c.userId == currentUid,
        logoUrl: c.logoUrl,
        onTap: () => _showCommerceSheet(c),
      )).toList(),
      onLogoLoaded: () { if (mounted) setState(() {}); },
    );
  }

  List<String> get _mapCategories {
    final cats = _commerceProvider.commerces.map((c) => c.categorie).toSet().toList();
    cats.sort();
    return cats;
  }

  /// Commerces filtrés + triés selon tous les critères actifs
  List<Commerce> get _filteredCommerces {
    var list = _commerceProvider.commerces.where((c) {
      if (_selectedMapCategory != null && c.categorie != _selectedMapCategory) {
        return false;
      }
      if (_filterType != null && c.type != _filterType) return false;
      if (_userLocation != null) {
        final dist = Geolocator.distanceBetween(
          _userLocation!.latitude, _userLocation!.longitude,
          c.position.latitude, c.position.longitude,
        );
        if (dist > _maxDistanceKm * 1000) return false;
      }
      return true;
    }).toList();

    if (_sortBy == 'newest') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_userLocation != null) {
      list.sort((a, b) {
        final da = Geolocator.distanceBetween(
          _userLocation!.latitude, _userLocation!.longitude,
          a.position.latitude, a.position.longitude,
        );
        final db = Geolocator.distanceBetween(
          _userLocation!.latitude, _userLocation!.longitude,
          b.position.latitude, b.position.longitude,
        );
        return da.compareTo(db);
      });
    }
    return list;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_maxDistanceKm < 50.0) count++;
    if (_sortBy != 'distance') count++;
    return count;
  }

  /// Retourne les 5 commerces les plus proches triés par distance
  List<({Commerce commerce, double distance})> get _nearestCommerces {
    if (_userLocation == null) return [];
    final withDist = _filteredCommerces.map((c) {
      final dist = Geolocator.distanceBetween(
        _userLocation!.latitude, _userLocation!.longitude,
        c.position.latitude, c.position.longitude,
      );
      return (commerce: c, distance: dist);
    }).toList();
    withDist.sort((a, b) => a.distance.compareTo(b.distance));
    return withDist.take(5).toList();
  }

  String _formatDistance(double meters) => MapService.formatDistance(meters);

  @override
  void dispose() {
    if (_commerceListenerAttached) {
      _commerceProvider.removeListener(_onCommercesUpdated);
    }
    _locationSubscription?.cancel();
    _mapService.dispose();
    super.dispose();
  }

  final List<_MarketCategory> _categories = const [
    _MarketCategory(icon: Icons.storefront, label: 'Marchés'),
    _MarketCategory(icon: Icons.agriculture, label: 'Agriculture'),
    _MarketCategory(icon: Icons.phone_android, label: 'Électronique'),
    _MarketCategory(icon: Icons.checkroom, label: 'Mode'),
    _MarketCategory(icon: Icons.restaurant, label: 'Alimentation'),
    _MarketCategory(icon: Icons.construction, label: 'Matériaux'),
  ];

  // Featured items are now fetched dynamically

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final authProvider = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Bandeau visiteur anonyme
      bottomSheet: authProvider.isAnonymous
          ? _AnonBanner()
          : null,
      body: Column(
        children: [
          if (_commerceProvider.hasCachedData)
            const _OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMapTab(),
                _buildHomeTab(colorScheme, textTheme),
                const OrdersListScreen(),
                _buildFavoritesTab(colorScheme, textTheme),
                _buildProfileTab(colorScheme, textTheme),
              ],
            ),
          ),
        ],
      ),
      // FAB "Ajouter un commerce" visible uniquement sur l'onglet carte
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'add_commerce',
              onPressed: _startAddCommerce,
              icon: const Icon(Icons.store_mall_directory),
              label: Text(l.addCommerce),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navExplore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: l.navFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l.navProfile,
          ),
        ],
      ),
    );
  }

  // ─── Flow "Ajouter un commerce" ───────────────────────────────────────────

  Future<void> _startAddCommerce() async {
    if (!SocialAuthService.requireAccount(context)) return;
    await context.push(Routes.addBoutique);
    // Le stream Firestore met à jour les marqueurs automatiquement
  }

  // ─── Fiche commerce (bottom sheet) ───────────────────────────────────────

  void _showCommerceSheet(Commerce commerce) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && commerce.userId == currentUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        // ignore: no_leading_underscores_for_local_identifiers
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poignée
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Avatar + nom + bouton favori
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bouton favori (haut droite)
                  if (!isOwner && commerce.id != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: StreamBuilder<bool>(
                        stream:
                            FavoriteService.isFavorite(commerce.id!),
                        builder: (_, snap) {
                          final isFav = snap.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite
                                  : Icons.favorite_outline,
                              color: isFav
                                  ? Colors.red
                                  : colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () =>
                                FavoriteService.toggle(commerce.id!),
                            tooltip: isFav
                                ? 'Retirer des favoris'
                                : 'Ajouter aux favoris',
                          );
                        },
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isOwner
                        ? Colors.blue.shade100
                        : colorScheme.primaryContainer,
                    child: Icon(Icons.store, size: 28,
                        color: isOwner ? Colors.blue : colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOwner) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Ma boutique',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(commerce.nomBoutique,
                            style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Commerçant enregistré',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Infos
              _InfoRow(icon: Icons.location_on_outlined,
                  label: 'Position',
                  value: '${commerce.position.latitude.toStringAsFixed(4)}, '
                      '${commerce.position.longitude.toStringAsFixed(4)}'),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.calendar_today_outlined,
                  label: 'Enregistré le',
                  value: '${commerce.createdAt.day}/${commerce.createdAt.month}/${commerce.createdAt.year}'),
              const SizedBox(height: 28),
              // Boutons
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(Routes.boutique, extra: commerce);
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Visiter la boutique'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(Routes.chat, extra: ChatArgs(
                      otherUserId: commerce.userId,
                      otherUserName: commerce.nomBoutique,
                    ));
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Contacter le commerçant'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Onglet Accueil ────────────────────────────────────────────────────────

  Widget _buildHomeTab(ColorScheme colorScheme, TextTheme textTheme) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _homeProducts = [];
          _lastProductDoc = null;
          _hasMoreProducts = true;
        });
        await _loadInitialProducts();
      },
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 2,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Text(
                'CamerMarket',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // Icône panier avec badge
              Consumer<CartService>(
                builder: (_, cart, __) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      color: colorScheme.onPrimary,
                      onPressed: () => context.push(Routes.cart),
                    ),
                    if (cart.itemCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFB300),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: colorScheme.onPrimary,
                onPressed: () {},
              ),
            ],
          ),

          // Barre de recherche
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SearchBar(
                hintText: 'Rechercher un marché, produit...',
                leading: const Icon(Icons.search, size: 20),
                onTap: () => context.push(Routes.search),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                )),
              ),
            ),
          ),

          // Catégories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Explorer par catégorie',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.2),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _CategoryChip(category: _categories[index]),
              ),
            ),
          ),

          // Nouveaux Produits Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nouveaux produits',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Tout voir'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: _homeProducts.isEmpty && _loadingMoreProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _homeProducts.isEmpty
                      ? _buildEmptyState(
                          'Aucun produit récent', Icons.inventory_2_outlined)
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          // +1 pour le bouton "Voir plus" ou indicateur fin
                          itemCount: _homeProducts.length +
                              (_hasMoreProducts ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Bouton "Voir plus" en fin de liste
                            if (index == _homeProducts.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 12),
                                child: Center(
                                  child: _loadingMoreProducts
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: _loadMoreProducts,
                                          icon: const Icon(
                                              Icons.expand_more,
                                              size: 16),
                                          label:
                                              const Text('Voir plus'),
                                          style:
                                              OutlinedButton.styleFrom(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12),
                                          ),
                                        ),
                                ),
                              );
                            }
                            final p = _homeProducts[index];
                            final commerce = _commerceProvider.commerces
                                .where((c) => c.id == p['commerce_id'])
                                .firstOrNull;
                            final rawUrls = p['image_urls'];
                            final String? firstImage = (rawUrls is List &&
                                    rawUrls.isNotEmpty)
                                ? rawUrls.first as String?
                                : p['image_url'] as String?;
                            final imageUrls = (rawUrls is List)
                                ? rawUrls.cast<String>()
                                : (firstImage != null ? [firstImage] : <String>[]);
                            return Padding(
                              padding: EdgeInsets.only(
                                  right: index < _homeProducts.length - 1
                                      ? 12
                                      : 0),
                              child: _ProductHorizontalCard(
                                nom: p['nom'] ?? '',
                                prix: (p['prix'] as num?)?.toDouble() ?? 0,
                                imageUrls: imageUrls,
                                categorie: p['categorie'] ?? '',
                                description: p['description'] ?? '',
                                docId: p['id'] ?? '',
                                commerce: commerce,
                                onTap: commerce == null
                                    ? null
                                    : () => showProductDetail(
                                          context,
                                          docId: p['id'] ?? '',
                                          nom: p['nom'] ?? '',
                                          description: p['description'] ?? '',
                                          prix: (p['prix'] as num?)?.toDouble() ?? 0,
                                          categorie: p['categorie'] ?? '',
                                          imageUrls: imageUrls,
                                          commerce: commerce,
                                        ),
                              ),
                            );
                          },
                        ),
            ),
          ),

          // Marchés à proximité (Dynamic from Firestore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commerces à proximité',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: const Text('Voir sur carte'),
                  ),
                ],
              ),
            ),
          ),
          if (_commerceProvider.isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_commerceProvider.commerces.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyState(
                  'Aucun commerce trouvé', Icons.storefront_outlined),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _MarketCard(commerce: _commerceProvider.commerces[index]),
                ),
                childCount: _commerceProvider.commerces.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Onglet Carte ──────────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapFilterSheet(
        maxDistanceKm: _maxDistanceKm,
        filterType: _filterType,
        sortBy: _sortBy,
        onApply: (dist, type, sort) {
          setState(() {
            _maxDistanceKm = dist;
            _filterType = type;
            _sortBy = sort;
          });
          _updateMapMarkers();
        },
      ),
    );
  }

  Widget _buildMapTab() {
    final visibleCount = _filteredCommerces.length;
    final nearest = _nearestCommerces;

    return FutureBuilder<LatLng>(
      future: _initialLocationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final initialPos = snapshot.data!;
        final colorScheme = Theme.of(context).colorScheme;
        return Stack(
          children: [
            // ── Carte 3D ──
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPos,
                zoom: 17,
                tilt: 50,
                bearing: _userBearing,
              ),
              myLocationEnabled: !kIsWeb, // non supporté sur web → marqueur explicite
              myLocationButtonEnabled: false,
              mapType: _mapType,
              buildingsEnabled: true,
              compassEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              onMapCreated: _mapService.onMapCreated,
              markers: _mapService.markers,
            ),

            // ── Barre de recherche ──
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: SearchBar(
                hintText: 'Rechercher sur la carte...',
                leading: const Icon(Icons.search),
                onTap: () => context.push(Routes.search),
                elevation: const WidgetStatePropertyAll(4),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16)),
              ),
            ),

            // ── Filtres catégories ──
            Positioned(
              top: 116,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Tous'),
                        selected: _selectedMapCategory == null,
                        onSelected: (_) {
                          setState(() => _selectedMapCategory = null);
                          _updateMapMarkers();
                        },
                        backgroundColor: colorScheme.surface,
                        selectedColor: colorScheme.primaryContainer,
                        checkmarkColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          color: _selectedMapCategory == null
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: _selectedMapCategory == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        elevation: 2,
                      ),
                    ),
                    ..._mapCategories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat),
                            selected: _selectedMapCategory == cat,
                            onSelected: (_) {
                              setState(() => _selectedMapCategory =
                                  _selectedMapCategory == cat ? null : cat);
                              _updateMapMarkers();
                            },
                            backgroundColor: colorScheme.surface,
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: _selectedMapCategory == cat
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: _selectedMapCategory == cat
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            elevation: 2,
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // ── Bouton Filtres avancés ──
            Positioned(
              top: 116,
              right: 12,
              child: GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  height: 36,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeFilterCount > 0
                        ? colorScheme.primary
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune,
                          size: 16,
                          color: _activeFilterCount > 0
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface),
                      const SizedBox(width: 4),
                      Text(
                        _activeFilterCount > 0
                            ? 'Filtres ($_activeFilterCount)'
                            : 'Filtres',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _activeFilterCount > 0
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Badge compteur + position GPS ──
            Positioned(
              top: 164,
              left: 16,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$visibleCount commerce${visibleCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (_userLocation != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'GPS actif',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Bannière erreur réseau ──
            if (_commerceProvider.error != null)
              Positioned(
                top: 210,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _commerceProvider.error!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _commerceProvider.retry,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Réessayer',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Boutons droite : Ma position 3D + Style carte ──
            Positioned(
              bottom: 230,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_type',
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    onPressed: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal
                            ? MapType.satellite
                            : MapType.normal;
                      });
                    },
                    child: Icon(
                      _mapType == MapType.normal
                          ? Icons.satellite_alt
                          : Icons.map,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'location',
                    onPressed: _mapService.goToCurrentLocation,
                    tooltip: 'Vue 3D ma position',
                    child: const Icon(Icons.navigation),
                  ),
                ],
              ),
            ),

            // ── Panneau Yango : commerces les plus proches ──
            if (nearest.isNotEmpty)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'À proximité · ${nearest.length} commerce${nearest.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: nearest.length,
                        itemBuilder: (ctx, i) {
                          final item = nearest[i];
                          final isOwner =
                              FirebaseAuth.instance.currentUser?.uid ==
                                  item.commerce.userId;
                          return GestureDetector(
                            onTap: () => _showCommerceSheet(item.commerce),
                            child: Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: isOwner
                                    ? Border.all(
                                        color: colorScheme.primary, width: 2)
                                    : null,
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        item.commerce.type ==
                                                CommerceType.etablissement
                                            ? Icons.business_center
                                            : Icons.storefront,
                                        color: isOwner
                                            ? Colors.blue
                                            : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.commerce.nomBoutique,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.commerce.categorie,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Icon(Icons.place,
                                          size: 13,
                                          color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDistance(item.distance),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue),
                                      ),
                                      if (isOwner) ...[
                                        const Spacer(),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Ma boutique',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── Onglet Favoris ────────────────────────────────────────────────────────

  Widget _buildFavoritesTab(ColorScheme colorScheme, TextTheme textTheme) {
    return const FavoritesScreen();
  }

  // ─── Onglet Profil ─────────────────────────────────────────────────────────

  Widget _buildProfileTab(ColorScheme colorScheme, TextTheme textTheme) {
    return const ProfileScreen();
  }
}

// ─── Widgets utilitaires ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _MarketCategory {
  final IconData icon;
  final String label;
  const _MarketCategory({required this.icon, required this.label});
}

class _CategoryChip extends StatelessWidget {
  final _MarketCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: colorScheme.onSecondaryContainer),
              const SizedBox(height: 8),
              Text(
                category.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final Commerce commerce;
  const _MarketCard({required this.commerce});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid != null && commerce.userId == currentUid;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOwner
              ? Colors.blue.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isOwner ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.boutique, extra: commerce),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.lightForType(commerce.type, dark: Theme.of(context).brightness == Brightness.dark),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  commerce.type == CommerceType.etablissement
                      ? Icons.business_center
                      : Icons.storefront,
                  color: AppColors.forType(commerce.type),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOwner) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forType(commerce.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          commerce.type == CommerceType.etablissement ? 'Mon établissement' : 'Ma boutique',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(commerce.nomBoutique,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(commerce.categorie,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.forType(commerce.type)),
                        const SizedBox(width: 4),
                        Text('Distance simulée',
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightForType(commerce.type, dark: Theme.of(context).brightness == Brightness.dark),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            commerce.typeLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.forType(commerce.type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet filtres carte ───────────────────────────────────────────────

class _MapFilterSheet extends StatefulWidget {
  final double maxDistanceKm;
  final CommerceType? filterType;
  final String sortBy;
  final void Function(double dist, CommerceType? type, String sort) onApply;

  const _MapFilterSheet({
    required this.maxDistanceKm,
    required this.filterType,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<_MapFilterSheet> {
  late double _dist;
  late CommerceType? _type;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _dist = widget.maxDistanceKm;
    _type = widget.filterType;
    _sort = widget.sortBy;
  }

  void _reset() => setState(() {
        _dist = 50.0;
        _type = null;
        _sort = 'distance';
      });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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

          // Titre + Réinitialiser
          Row(
            children: [
              Text('Filtres avancés',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: _reset,
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Distance ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Distance maximale',
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _dist >= 50 ? 'Pas de limite' : '${_dist.toInt()} km',
                  style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          Slider(
            value: _dist,
            min: 1,
            max: 50,
            divisions: 49,
            label: _dist >= 50 ? '∞' : '${_dist.toInt()} km',
            onChanged: (v) => setState(() => _dist = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              Text('50 km (∞)',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Type de commerce ────────────────────────────────────────────
          Text('Type de commerce',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tous'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              ChoiceChip(
                label: const Text('Boutiques'),
                selected: _type == CommerceType.boutique,
                onSelected: (_) =>
                    setState(() => _type = CommerceType.boutique),
              ),
              ChoiceChip(
                label: const Text('Établissements'),
                selected: _type == CommerceType.etablissement,
                onSelected: (_) =>
                    setState(() => _type = CommerceType.etablissement),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Trier par ────────────────────────────────────────────────────
          Text('Trier par',
              style:
                  textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, size: 14),
                    SizedBox(width: 4),
                    Text('Distance'),
                  ],
                ),
                selected: _sort == 'distance',
                onSelected: (_) => setState(() => _sort = 'distance'),
              ),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 14),
                    SizedBox(width: 4),
                    Text('Plus récents'),
                  ],
                ),
                selected: _sort == 'newest',
                onSelected: (_) => setState(() => _sort = 'newest'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              widget.onApply(_dist, _type, _sort);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Appliquer les filtres'),
          ),
        ],
      ),
    );
  }
}

// ─── Card produit horizontal ──────────────────────────────────────────────────

class _ProductHorizontalCard extends StatelessWidget {
  final String nom;
  final double prix;
  final List<String> imageUrls;
  final String categorie;
  final String description;
  final String docId;
  final Commerce? commerce;
  final VoidCallback? onTap;

  const _ProductHorizontalCard({
    required this.nom,
    required this.prix,
    required this.imageUrls,
    required this.categorie,
    required this.description,
    required this.docId,
    this.commerce,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isService = commerce?.type == CommerceType.etablissement;
    final accent = isService ? AppColors.etablissement : AppColors.boutique;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentLight = isService ? AppColors.lightForType(CommerceType.etablissement, dark: isDark) : AppColors.lightForType(CommerceType.boutique, dark: isDark);
    final typeLabel = isService ? 'Service' : 'Produit';
    final typeIcon = isService ? Icons.design_services : Icons.inventory_2_outlined;
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  firstImage != null
                      ? Image.network(firstImage, fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          color: accentLight,
                          child: Center(
                            child: Icon(typeIcon, color: accent.withValues(alpha: 0.5), size: 32),
                          ),
                        ),
                  // Type badge
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.price,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${prix.toStringAsFixed(0)} FCFA',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.priceColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (commerce != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          isService ? Icons.business_center : Icons.storefront,
                          size: 10,
                          color: accent.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            commerce!.nomBoutique,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bandeau visiteur anonyme ─────────────────────────────────────────────────

class _AnonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.person_off_outlined,
                  size: 18, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode visiteur — Créez un compte pour commander',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Créer un compte',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bannière hors-ligne ──────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade700,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hors ligne • données en cache',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

