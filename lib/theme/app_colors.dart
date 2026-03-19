import 'package:flutter/material.dart';
import '../services/commerce_service.dart';

/// Couleurs aux couleurs du Cameroun
class AppColors {
  // Boutiques & Produits → Bleu
  static const Color boutique = Color(0xFF1565C0);
  static const Color boutiqueLight = Color(0xFFE3F2FD);

  // Établissements & Services → Vert (drapeau Cameroun)
  static const Color etablissement = Color(0xFF009A44);
  static const Color etablissementLight = Color(0xFFE8F5E9);

  // Prix & Détails → Jaune (drapeau Cameroun)
  static const Color price = Color(0xFFFCD116);
  static const Color priceText = Color(0xFF7A6000);

  // Rouge général (header, accents) → Rouge (drapeau Cameroun)
  static const Color primary = Color(0xFFCC0000);

  /// Retourne la couleur principale selon le type de commerce
  static Color forType(CommerceType type) =>
      type == CommerceType.boutique ? boutique : etablissement;

  /// Retourne la couleur claire selon le type de commerce
  static Color lightForType(CommerceType type) =>
      type == CommerceType.boutique ? boutiqueLight : etablissementLight;
}
