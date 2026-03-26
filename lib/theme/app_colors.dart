import 'package:flutter/material.dart';
import '../services/commerce_service.dart';

/// Couleurs aux couleurs du Cameroun
class AppColors {
  // Boutiques & Produits → Bleu
  static const Color boutique = Color(0xFF1565C0);
  static const Color boutiqueLight = Color(0xFFE3F2FD);
  static const Color boutiqueDark  = Color(0xFF1A2A4A);

  // Établissements & Services → Vert (drapeau Cameroun)
  static const Color etablissement = Color(0xFF009A44);
  static const Color etablissementLight = Color(0xFFE8F5E9);
  static const Color etablissementDark  = Color(0xFF0D2B1A);

  // Prix & Détails → Jaune (drapeau Cameroun)
  static const Color price = Color(0xFFFCD116);
  static const Color priceText     = Color(0xFF7A6000); // light mode
  static const Color priceTextDark = Color(0xFFFFD54F); // dark mode

  // Rouge général (header, accents) → Rouge (drapeau Cameroun)
  static const Color primary = Color(0xFFCC0000);

  /// Retourne la couleur principale selon le type de commerce
  static Color forType(CommerceType type) =>
      type == CommerceType.boutique ? boutique : etablissement;

  /// Retourne la couleur de fond claire/sombre selon le type et le thème
  static Color lightForType(CommerceType type, {bool dark = false}) {
    if (dark) {
      return type == CommerceType.boutique ? boutiqueDark : etablissementDark;
    }
    return type == CommerceType.boutique ? boutiqueLight : etablissementLight;
  }

  /// Retourne priceText adapté au thème courant
  static Color priceColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? priceTextDark : priceText;
  }
}
