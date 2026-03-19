/// Script de test de connectivité Firebase + Google Maps
///
/// Usage : lancez cet écran temporairement en remplaçant `home` dans main.dart :
///   home: const ConnectionTestScreen(),
///
/// Résultats affichés directement dans l'UI et dans la console Flutter.
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/map_service.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final List<_TestResult> _results = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAllTests());
  }

  Future<void> _runAllTests() async {
    setState(() {
      _results.clear();
      _running = true;
    });

    await _testFirebaseInit();
    await _testFirestoreRead();
    await _testFirebaseAuth();
    await _testMapsApiKey();
    await _testGeolocation();

    setState(() => _running = false);
  }

  // ─── Test 1 : Firebase initialisé ────────────────────────────────────────

  Future<void> _testFirebaseInit() async {
    try {
      final app = FirebaseAuth.instance.app;
      _add(_TestResult(
        name: 'Firebase Core',
        status: TestStatus.pass,
        detail: 'App : ${app.name} | Projet : ${app.options.projectId}',
      ));
    } catch (e) {
      _add(_TestResult(
        name: 'Firebase Core',
        status: TestStatus.fail,
        detail: e.toString(),
      ));
    }
  }

  // ─── Test 2 : Lecture Firestore ───────────────────────────────────────────

  Future<void> _testFirestoreRead() async {
    try {
      final db = FirebaseFirestore.instance;
      // Ping : lecture d'une collection (même vide = succès)
      await db.collection('_ping').limit(1).get().timeout(
            const Duration(seconds: 10),
          );
      _add(const _TestResult(
        name: 'Cloud Firestore',
        status: TestStatus.pass,
        detail: 'Connexion Firestore OK',
      ));
    } catch (e) {
      _add(_TestResult(
        name: 'Cloud Firestore',
        status: TestStatus.fail,
        detail: e.toString(),
      ));
    }
  }

  // ─── Test 3 : FirebaseAuth ────────────────────────────────────────────────

  Future<void> _testFirebaseAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      _add(_TestResult(
        name: 'Firebase Auth',
        status: TestStatus.pass,
        detail: user != null
            ? 'Connecté : ${user.phoneNumber ?? user.email ?? user.uid}'
            : 'Service Auth actif — non connecté',
      ));
    } catch (e) {
      _add(_TestResult(
        name: 'Firebase Auth',
        status: TestStatus.fail,
        detail: e.toString(),
      ));
    }
  }

  // ─── Test 4 : Clé API Maps ────────────────────────────────────────────────

  Future<void> _testMapsApiKey() async {
    try {
      const key = String.fromEnvironment('MAPS_API_KEY');
      final valid = key.isNotEmpty && !key.contains('REMPLACER');
      _add(_TestResult(
        name: 'Google Maps API Key',
        status: valid ? TestStatus.pass : TestStatus.fail,
        detail: valid
            ? 'Clé configurée : ${key.substring(0, 12)}...'
            : 'Clé manquante ou placeholder',
      ));
    } catch (e) {
      _add(_TestResult(
        name: 'Google Maps API Key',
        status: TestStatus.fail,
        detail: e.toString(),
      ));
    }
  }

  // ─── Test 5 : Géolocalisation ────────────────────────────────────────────

  Future<void> _testGeolocation() async {
    try {
      final location = await MapService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 15));
      _add(_TestResult(
        name: 'Géolocalisation',
        status: TestStatus.pass,
        detail:
            'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
      ));
    } catch (e) {
      _add(_TestResult(
        name: 'Géolocalisation',
        status: TestStatus.warn,
        detail: 'Position par défaut utilisée (Yaoundé) : $e',
      ));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _add(_TestResult r) {
    debugPrint('[TEST] ${r.status.name.toUpperCase()} — ${r.name}: ${r.detail}');
    setState(() => _results.add(r));
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final passed = _results.where((r) => r.status == TestStatus.pass).length;
    final failed = _results.where((r) => r.status == TestStatus.fail).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de connexion'),
        actions: [
          if (!_running)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runAllTests,
              tooltip: 'Relancer les tests',
            ),
        ],
      ),
      body: Column(
        children: [
          // Résumé
          if (!_running && _results.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: failed == 0
                  ? colorScheme.primaryContainer
                  : colorScheme.errorContainer,
              child: Text(
                failed == 0
                    ? '✓ Tous les tests réussis ($passed/$passed)'
                    : '✗ $failed test(s) échoué(s) — $passed/${_results.length} OK',
                style: TextStyle(
                  color: failed == 0
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Liste des tests
          Expanded(
            child: _running && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length + (_running ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, i) {
                      if (i == _results.length) {
                        return const ListTile(
                          leading: CircularProgressIndicator(strokeWidth: 2),
                          title: Text('Test en cours...'),
                        );
                      }
                      final r = _results[i];
                      return ListTile(
                        leading: Icon(r.status.icon, color: r.status.color(colorScheme)),
                        title: Text(r.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r.detail),
                        tileColor: r.status.color(colorScheme).withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Modèles ─────────────────────────────────────────────────────────────────

enum TestStatus { pass, fail, warn }

extension _TestStatusExt on TestStatus {
  IconData get icon => switch (this) {
        TestStatus.pass => Icons.check_circle,
        TestStatus.fail => Icons.cancel,
        TestStatus.warn => Icons.warning_amber_rounded,
      };

  Color color(ColorScheme cs) => switch (this) {
        TestStatus.pass => cs.primary,
        TestStatus.fail => cs.error,
        TestStatus.warn => Colors.orange,
      };
}

class _TestResult {
  final String name;
  final TestStatus status;
  final String detail;
  const _TestResult({
    required this.name,
    required this.status,
    required this.detail,
  });
}
