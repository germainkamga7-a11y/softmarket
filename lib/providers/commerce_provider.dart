import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/commerce_service.dart';

/// Provider global pour la liste des commerces.
/// - Un seul stream Firestore partagé entre tous les écrans.
/// - Timeout de chargement : évite le spinner infini hors ligne sans cache.
/// - Auto-retry quand la connexion est rétablie.
class CommerceProvider extends ChangeNotifier {
  static const int _limit = 200;
  static const _kLoadingTimeout = Duration(seconds: 8);

  final _service = CommerceService();
  StreamSubscription<List<Commerce>>? _sub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _loadingTimer;

  List<Commerce> _commerces = [];
  bool _isLoading = true;
  String? _error;
  bool _isOnline = true;

  List<Commerce> get commerces => _commerces;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// true si l'appareil a une connexion réseau active.
  bool get isOnline => _isOnline;

  /// true si des données en cache sont disponibles pendant une coupure réseau.
  bool get hasCachedData => !_isOnline && _commerces.isNotEmpty;

  CommerceProvider() {
    _subscribe();
    _listenConnectivity();
  }

  // ─── Connectivité ──────────────────────────────────────────────────────────

  void _listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = results.any((r) => r != ConnectivityResult.none);
      if (nowOnline == _isOnline) return; // pas de changement d'état

      _isOnline = nowOnline;

      if (_isOnline && (_error != null || _isLoading)) {
        // Connexion rétablie → relance automatique du stream
        retry();
      } else {
        notifyListeners();
      }
    });

    // Vérification initiale de l'état réseau
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_isOnline) notifyListeners();
    });
  }

  // ─── Stream Firestore ──────────────────────────────────────────────────────

  void _subscribe() {
    // Timeout : si aucune donnée n'arrive dans _kLoadingTimeout,
    // l'appareil est probablement hors-ligne sans cache → afficher une erreur.
    _loadingTimer?.cancel();
    _loadingTimer = Timer(_kLoadingTimeout, () {
      if (_isLoading) {
        _isLoading = false;
        _error = 'Données indisponibles. Vérifiez votre connexion.';
        notifyListeners();
      }
    });

    _sub = _service.streamCommerces(limit: _limit).listen(
      (list) {
        _loadingTimer?.cancel();
        _commerces = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loadingTimer?.cancel();
        debugPrint('[CommerceProvider] Erreur stream : $e');
        _isLoading = false;
        _error = _isNetworkError(e)
            ? 'Connexion impossible. Vérifiez votre réseau.'
            : 'Impossible de charger les commerces.';
        notifyListeners();
      },
    );
  }

  /// Annule le stream courant et en ouvre un nouveau.
  void retry() {
    _sub?.cancel();
    _loadingTimer?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();
    _subscribe();
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('unavailable') ||
        msg.contains('timeout') ||
        msg.contains('socket') ||
        msg.contains('connection');
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _connectivitySub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
