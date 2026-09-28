import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/core/utils/money.dart';

/// Remplace l'espace insécable par une espace normale pour lire les attentes.
String plain(String s) => s.replaceAll(' ', ' ');

void main() {
  group('formatFcfa', () {
    test('groupe les milliers', () {
      expect(plain(formatFcfa(0)), '0 FCFA');
      expect(plain(formatFcfa(500)), '500 FCFA');
      expect(plain(formatFcfa(8000)), '8 000 FCFA');
      expect(plain(formatFcfa(120000)), '120 000 FCFA');
      expect(plain(formatFcfa(485000)), '485 000 FCFA');
      expect(plain(formatFcfa(1250000)), '1 250 000 FCFA');
    });

    test('négatif avec signe moins typographique', () {
      expect(plain(formatFcfa(-8000)), '−8 000 FCFA');
    });

    test('utilise des espaces insécables', () {
      expect(formatFcfa(25000).contains(' '), isFalse);
    });
  });

  group('formatFcfaSigned', () {
    test('entrée et sortie', () {
      expect(plain(formatFcfaSigned(25000)), '+ 25 000 FCFA');
      expect(plain(formatFcfaSigned(-8000)), '− 8 000 FCFA');
    });
  });
}
