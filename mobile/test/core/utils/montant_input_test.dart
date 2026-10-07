import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/core/utils/montant_input.dart';

void main() {
  const formatter = MontantInputFormatter();
  String saisir(String texte) =>
      formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texte)).text;

  test('groupe les milliers pendant la frappe', () {
    expect(saisir('25000'), '25 000');
    expect(saisir('1250000'), '1 250 000');
    expect(saisir('500'), '500');
  });

  test("ignore tout ce qui n'est pas un chiffre (pas de décimales)", () {
    expect(saisir('25,50'), '2 550');
    expect(saisir('-8000'), '8 000');
    expect(saisir('007'), '7');
  });

  test('refuse au-delà de 12 chiffres', () {
    const avant = TextEditingValue(text: '999 999 999 999');
    final apres = formatter.formatEditUpdate(avant, const TextEditingValue(text: '9999999999991'));
    expect(apres.text, avant.text);
  });

  test('parseMontant', () {
    expect(parseMontant('25 000'), 25000);
    expect(parseMontant(''), 0);
  });
}
