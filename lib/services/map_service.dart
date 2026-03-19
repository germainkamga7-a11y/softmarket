import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'commerce_service.dart';

/// Coordonnées par défaut : Yaoundé, Cameroun
const LatLng _kDefaultLocation = LatLng(3.8480, 11.5021);

class MapService {
  GoogleMapController? _controller;
  final Set<Marker> _staticMarkers = {};
  final Set<Marker> _commerceMarkers = {};
  Marker? _userMarker;
  final Completer<GoogleMapController> _controllerCompleter = Completer();

  LatLng? _userPosition;

  // Cache des icônes personnalisées pour éviter de les recréer à chaque update
  BitmapDescriptor? _iconBoutique;
  BitmapDescriptor? _iconEtablissement;
  BitmapDescriptor? _iconOwnBoutique;
  BitmapDescriptor? _iconOwnEtablissement;
  // Cache logo réseau : logoUrl → BitmapDescriptor
  final Map<String, BitmapDescriptor> _logoIconCache = {};

  // ─── Getters ────────────────────────────────────────────────────────────────

  Set<Marker> get markers => Set.unmodifiable({
        ..._staticMarkers,
        ..._commerceMarkers,
        if (_userMarker != null) _userMarker!,
      });

  // ─── Pré-chargement des icônes ───────────────────────────────────────────

  /// À appeler une fois au démarrage pour pré-générer les icônes de marqueurs
  Future<void> preloadIcons() async {
    // Sur web, BitmapDescriptor.bytes() n'est pas fiable →
    // on utilise les teintes natives (defaultMarkerWithHue) définies dans _getIcon()
    if (kIsWeb) {
      debugPrint('[MapService] Web détecté — icônes natives utilisées.');
      return;
    }
    _iconBoutique = await _buildMarkerIcon(
      bgColor: Colors.orange,
      icon: Icons.storefront,
    );
    _iconEtablissement = await _buildMarkerIcon(
      bgColor: Colors.deepPurple,
      icon: Icons.business_center,
    );
    _iconOwnBoutique = await _buildMarkerIcon(
      bgColor: Colors.blue,
      icon: Icons.storefront,
    );
    _iconOwnEtablissement = await _buildMarkerIcon(
      bgColor: Colors.blue,
      icon: Icons.business_center,
    );
    debugPrint('[MapService] Icônes marqueurs chargées.');
  }

  /// Génère un marqueur pin personnalisé avec une icône Material à l'intérieur
  static Future<BitmapDescriptor> _buildMarkerIcon({
    required Color bgColor,
    required IconData icon,
  }) async {
    const double w = 80;
    const double h = 100;
    const double r = 34.0;
    const Offset center = Offset(w / 2, r + 4);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // Ombre portée
    canvas.drawCircle(
      center + const Offset(0, 4),
      r,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Queue du pin (triangle)
    final tailPath = Path()
      ..moveTo(w / 2 - 10, center.dy + r - 8)
      ..lineTo(w / 2 + 10, center.dy + r - 8)
      ..lineTo(w / 2, h - 2)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = bgColor);

    // Cercle de fond
    canvas.drawCircle(center, r, Paint()..color = bgColor);

    // Bordure blanche
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Icône Material
    final tp = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 32,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Génère un marqueur pin avec le logo réseau centré dans le cercle
  static Future<BitmapDescriptor> _buildMarkerIconWithLogo({
    required Color borderColor,
    required String logoUrl,
  }) async {
    const double w = 80;
    const double h = 100;
    const double r = 34.0;
    const Offset center = Offset(w / 2, r + 4);

    // Charger l'image réseau
    ui.Image? logoImage;
    try {
      final imageProvider = NetworkImage(logoUrl);
      final completer = Completer<ui.Image>();
      final stream = imageProvider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      }, onError: (e, _) {
        if (!completer.isCompleted) completer.completeError(e);
      });
      stream.addListener(listener);
      logoImage = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Logo timeout'),
      );
      stream.removeListener(listener);
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // Ombre
    canvas.drawCircle(
      center + const Offset(0, 4),
      r,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Queue du pin
    final tailPath = Path()
      ..moveTo(w / 2 - 10, center.dy + r - 8)
      ..lineTo(w / 2 + 10, center.dy + r - 8)
      ..lineTo(w / 2, h - 2)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = borderColor);

    // Cercle blanc de fond
    canvas.drawCircle(center, r, Paint()..color = Colors.white);

    // Clip circulaire pour le logo
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: r - 3)));
    canvas.drawImageRect(
      logoImage,
      Rect.fromLTWH(
          0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
      Rect.fromCircle(center: center, radius: r - 3),
      Paint(),
    );
    canvas.restore();

    // Bordure colorée
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  BitmapDescriptor _getIcon(CommerceType type, bool isOwner) {
    if (isOwner) {
      return type == CommerceType.etablissement
          ? (_iconOwnEtablissement ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure))
          : (_iconOwnBoutique ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));
    }
    return type == CommerceType.etablissement
        ? (_iconEtablissement ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
        : (_iconBoutique ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange));
  }

  // ─── Initialisation de la carte ─────────────────────────────────────────────

  void onMapCreated(GoogleMapController controller) {
    _controller = controller;
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }
    _loadNearbyMarkets();
  }

  // ─── Localisation ───────────────────────────────────────────────────────────

  Future<LatLng> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _kDefaultLocation;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      final loc = LatLng(position.latitude, position.longitude);
      _userPosition = loc;
      return loc;
    } catch (e) {
      debugPrint('[MapService] Position indisponible : $e');
      return _kDefaultLocation;
    }
  }

  /// Stream de position en temps réel (mise à jour tous les 5 mètres)
  Stream<Position> startLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .timeout(
      const Duration(seconds: 30),
      onTimeout: (sink) {
        debugPrint('[MapService] Location stream timeout — GPS indisponible');
        sink.close();
      },
    );
  }

  void updateUserPosition(LatLng position) {
    _userPosition = position;
    // Sur web, myLocationEnabled n'est pas supporté → marqueur explicite
    if (kIsWeb) {
      _userMarker = Marker(
        markerId: const MarkerId('user_location'),
        position: position,
        infoWindow: const InfoWindow(title: 'Ma position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        zIndexInt: 10,
      );
    }
  }

  /// Déplace la caméra en vue 3D vers la position actuelle
  Future<void> goToCurrentLocation() async {
    final location = await getCurrentLocation();
    final controller = await _controllerCompleter.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 17, tilt: 50),
      ),
    );
  }

  // ─── Marqueurs ──────────────────────────────────────────────────────────────

  void _loadNearbyMarkets() {
    final sampleMarkets = [
      const _MarketPin(
        id: 'marche_central',
        name: 'Marché Central de Yaoundé',
        position: LatLng(3.8667, 11.5167),
      ),
      const _MarketPin(
        id: 'marche_mokolo',
        name: 'Marché Mokolo',
        position: LatLng(3.8779, 11.5086),
      ),
      const _MarketPin(
        id: 'marche_mfoundi',
        name: 'Marché du Mfoundi',
        position: LatLng(3.8512, 11.5098),
      ),
    ];

    for (final market in sampleMarkets) {
      String snippet = 'Appuyez pour plus de détails';
      if (_userPosition != null) {
        final dist = Geolocator.distanceBetween(
          _userPosition!.latitude, _userPosition!.longitude,
          market.position.latitude, market.position.longitude,
        );
        snippet = formatDistance(dist);
      }
      _staticMarkers.add(
        Marker(
          markerId: MarkerId(market.id),
          position: market.position,
          infoWindow: InfoWindow(title: market.name, snippet: snippet),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
  }

  /// Met à jour les marqueurs avec l'icône ou le logo de la boutique
  void updateCommerceMarkers(
    List<({
      String id,
      LatLng position,
      String nom,
      CommerceType type,
      bool isOwner,
      String? logoUrl,
      VoidCallback onTap,
    })> commerces, {
    VoidCallback? onLogoLoaded,
  }) {
    _commerceMarkers.clear();
    for (final c in commerces) {
      String snippet = 'Commerçant vérifié ✓';
      if (_userPosition != null) {
        final dist = Geolocator.distanceBetween(
          _userPosition!.latitude, _userPosition!.longitude,
          c.position.latitude, c.position.longitude,
        );
        snippet = '${formatDistance(dist)} · Commerçant vérifié ✓';
      }

      // Utiliser le logo en cache si disponible, sinon l'icône par défaut
      final cachedLogo = c.logoUrl != null ? _logoIconCache[c.logoUrl] : null;
      _commerceMarkers.add(
        Marker(
          markerId: MarkerId('commerce_${c.id}'),
          position: c.position,
          infoWindow: InfoWindow(title: c.nom, snippet: snippet),
          icon: cachedLogo ?? _getIcon(c.type, c.isOwner),
          onTap: c.onTap,
        ),
      );

      // Charger le logo en arrière-plan si pas encore en cache
      if (c.logoUrl != null && !_logoIconCache.containsKey(c.logoUrl)) {
        final logoUrl = c.logoUrl!;
        final borderColor = c.isOwner
            ? Colors.blue
            : (c.type == CommerceType.etablissement
                ? Colors.deepPurple
                : Colors.orange);
        _buildMarkerIconWithLogo(logoUrl: logoUrl, borderColor: borderColor)
            .then((icon) {
          _logoIconCache[logoUrl] = icon;
          // Mettre à jour ce marqueur spécifique avec le logo
          _commerceMarkers.removeWhere(
              (m) => m.markerId == MarkerId('commerce_${c.id}'));
          _commerceMarkers.add(
            Marker(
              markerId: MarkerId('commerce_${c.id}'),
              position: c.position,
              infoWindow: InfoWindow(title: c.nom, snippet: snippet),
              icon: icon,
              onTap: c.onTap,
            ),
          );
          onLogoLoaded?.call();
        }).catchError((_) {});
      }
    }
  }

  // ─── Utilitaires ────────────────────────────────────────────────────────────

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // ─── Nettoyage ──────────────────────────────────────────────────────────────

  void dispose() {
    _controller?.dispose();
  }
}

// ─── Modèle interne ───────────────────────────────────────────────────────────

class _MarketPin {
  final String id;
  final String name;
  final LatLng position;

  const _MarketPin({
    required this.id,
    required this.name,
    required this.position,
  });
}
