
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Résultat de l'analyse d'une CNI camerounaise
class CniResult {
  final bool isCamerounCni;
  final String? nom;
  final String? numeroCni;
  final String rawText;

  const CniResult({
    required this.isCamerounCni,
    this.nom,
    this.numeroCni,
    required this.rawText,
  });

  bool get isValid => isCamerounCni && nom != null && numeroCni != null;

  @override
  String toString() =>
      'CniResult(valid=$isValid, nom=$nom, numero=$numeroCni)';
}

/// Service d'analyse de CNI par OCR (ML Kit)
class CniScanner {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Analyse une image de CNI et retourne les données extraites.
  /// [imagePath] : chemin absolu vers le fichier image.
  Future<CniResult> scan(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    RecognizedText recognizedText;

    try {
      recognizedText = await _recognizer.processImage(inputImage);
    } catch (e) {
      debugPrint('[CniScanner] Erreur ML Kit : $e');
      return const CniResult(
        isCamerounCni: false,
        rawText: '',
      );
    }

    final raw = recognizedText.text;
    debugPrint('[CniScanner] Texte brut :\n$raw');

    return _parse(raw);
  }

  // ─── Parsing ──────────────────────────────────────────────────────────────

  CniResult _parse(String raw) {
    final normalized = raw.toUpperCase();

    // Vérification : c'est bien une CNI camerounaise
    final isCni = normalized.contains('REPUBLIQUE DU CAMEROUN') ||
        normalized.contains('REPUBLIC OF CAMEROON') ||
        normalized.contains('CARTE NATIONALE') ||
        normalized.contains('NATIONAL IDENTITY');

    if (!isCni) {
      return CniResult(isCamerounCni: false, rawText: raw);
    }

    final nom = _extractNom(raw);
    final numero = _extractNumero(raw);

    return CniResult(
      isCamerounCni: true,
      nom: nom,
      numeroCni: numero,
      rawText: raw,
    );
  }

  /// Extrait le nom de famille + prénom(s).
  /// Les CNI camerounaises affichent typiquement :
  ///   NOM / SURNAME : DUPONT
  ///   PRENOMS / GIVEN NAMES : JEAN MARIE
  String? _extractNom(String raw) {
    // Tente le pattern bilingue (FR/EN)
    final patterns = [
      RegExp(r'(?:NOM|SURNAME)\s*[:/]?\s*([A-Z][A-Z\s\-]+)', caseSensitive: false),
      RegExp(r'(?:PRENOMS?|GIVEN\s+NAMES?)\s*[:/]?\s*([A-Z][A-Z\s\-]+)', caseSensitive: false),
    ];

    final parts = <String>[];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw.toUpperCase());
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.length > 1) parts.add(_capitalize(value));
      }
    }

    if (parts.isNotEmpty) return parts.join(' ');

    // Fallback : ligne en majuscules après le header "REPUBLIQUE"
    final lines = raw.split('\n').map((l) => l.trim()).toList();
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toUpperCase().contains('REPUBLIQUE') && i + 2 < lines.length) {
        final candidate = lines[i + 2].trim();
        if (candidate.length > 2 && RegExp(r'^[A-Z\s\-]+$').hasMatch(candidate)) {
          return _capitalize(candidate);
        }
      }
    }
    return null;
  }

  /// Extrait le numéro de CNI camerounais.
  /// Format attendu : 6 à 9 chiffres (ex : 000123456 ou 1234567)
  String? _extractNumero(String raw) {
    // Pattern explicite avec label
    final labeledPattern = RegExp(
      r'(?:N[°º]?\s*(?:CNI|ID|CARTE|IDENTITY)?)\s*[:/]?\s*(\d{6,12})',
      caseSensitive: false,
    );
    final labeledMatch = labeledPattern.firstMatch(raw);
    if (labeledMatch != null) return labeledMatch.group(1)?.trim();

    // Fallback : séquence de 6–12 chiffres isolée
    final numericPattern = RegExp(r'\b(\d{6,12})\b');
    final allMatches = numericPattern.allMatches(raw).toList();
    if (allMatches.isNotEmpty) return allMatches.first.group(1);

    return null;
  }

  String _capitalize(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'[\s\-]'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  void dispose() {
    _recognizer.close();
  }
}
