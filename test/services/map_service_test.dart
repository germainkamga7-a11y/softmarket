import 'package:flutter_test/flutter_test.dart';

import 'package:camermarket/services/map_service.dart';

void main() {
  // ─── MapService.formatDistance ─────────────────────────────────────────────

  group('MapService.formatDistance', () {
    test('affiche en mètres pour < 1000 m', () {
      expect(MapService.formatDistance(0), '0 m');
      expect(MapService.formatDistance(500), '500 m');
      expect(MapService.formatDistance(999), '999 m');
    });

    test('arrondit les mètres à l\'entier le plus proche', () {
      expect(MapService.formatDistance(250.6), '251 m');
      expect(MapService.formatDistance(750.2), '750 m');
    });

    test('affiche en km pour >= 1000 m', () {
      expect(MapService.formatDistance(1000), '1.0 km');
      expect(MapService.formatDistance(1500), '1.5 km');
      expect(MapService.formatDistance(10000), '10.0 km');
    });

    test('affiche une décimale pour les km', () {
      expect(MapService.formatDistance(2300), '2.3 km');
      expect(MapService.formatDistance(12345), '12.3 km');
    });

    test('exactement 1000 m → 1.0 km', () {
      expect(MapService.formatDistance(1000), '1.0 km');
    });
  });
}
