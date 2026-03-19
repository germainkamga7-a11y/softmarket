
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cni_scanner.dart';

/// Écran de scan de la CNI.
/// Retourne un [CniResult] au pop, ou null si annulé.
class CniScannerScreen extends StatefulWidget {
  const CniScannerScreen({super.key});

  @override
  State<CniScannerScreen> createState() => _CniScannerScreenState();
}

class _CniScannerScreenState extends State<CniScannerScreen> {
  final _scanner = CniScanner();
  final _picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _error = 'Caméra indisponible : $e');
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    setState(() => _analyzing = true);
    try {
      final file = await _cameraController!.takePicture();
      await _analyze(file.path);
    } catch (e) {
      _showError('Erreur de capture : $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _analyzing = true);
    try {
      await _analyze(picked.path);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _analyze(String path) async {
    final result = await _scanner.scan(path);

    if (!mounted) return;

    if (!result.isCamerounCni) {
      _showError(
        'Document non reconnu.\nAssurez-vous de photographier une CNI camerounaise.',
      );
      return;
    }

    if (!result.isValid) {
      // CNI reconnue mais données incomplètes → demander confirmation manuelle
      final confirmed = await _showManualConfirmDialog(result);
      if (!mounted) return;
      if (confirmed != null) Navigator.of(context).pop(confirmed);
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<CniResult?> _showManualConfirmDialog(CniResult partial) {
    final nomCtrl = TextEditingController(text: partial.nom ?? '');
    final numCtrl = TextEditingController(text: partial.numeroCni ?? '');

    return showDialog<CniResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compléter les informations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Certaines données n\'ont pas pu être lues automatiquement. '
              'Vérifiez et corrigez si nécessaire.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numCtrl,
              decoration: const InputDecoration(
                labelText: 'Numéro CNI',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final result = CniResult(
                isCamerounCni: true,
                nom: nomCtrl.text.trim(),
                numeroCni: numCtrl.text.trim(),
                rawText: partial.rawText,
              );
              Navigator.pop(ctx, result);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner la CNI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _analyzing ? null : _pickFromGallery,
            tooltip: 'Choisir dans la galerie',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Viewfinder caméra
          if (_cameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Cadre de guidage
          if (_cameraReady)
            Center(
              child: Container(
                width: 300,
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 2.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // Instruction
          if (_cameraReady)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Text(
                'Placez votre CNI dans le cadre',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),

          // Overlay d'analyse
          if (_analyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Analyse en cours...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // Bouton capture
          if (_cameraReady && !_analyzing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _captureAndAnalyze,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: colorScheme.primary, width: 4),
                    ),
                    child: Icon(Icons.camera_alt,
                        size: 36, color: colorScheme.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
