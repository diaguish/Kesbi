import 'package:flutter_test/flutter_test.dart';
import 'package:kesbi/features/auth/domain/phone_number.dart';
import 'package:kesbi/features/auth/domain/pin_rules.dart';

void main() {
  group('PhoneNumber', () {
    test('accepte les mobiles sénégalais, avec ou sans indicatif', () {
      for (final input in ['770000000', '77 000 00 00', '+221 77 000 00 00', '00221770000000']) {
        expect(PhoneNumber.tryParse(input)?.e164, '+221770000000', reason: input);
      }
      for (final prefix in ['70', '75', '76', '77', '78']) {
        expect(PhoneNumber.tryParse('${prefix}1234567'), isNotNull, reason: prefix);
      }
    });

    test('refuse les numéros invalides', () {
      for (final input in ['', '7700000', '7700000000', '331234567', '791234567', 'abc', '+33612345678']) {
        expect(PhoneNumber.tryParse(input), isNull, reason: input);
      }
    });

    test('affichage lisible', () {
      expect(PhoneNumber.tryParse('771234567')!.display, '77 123 45 67');
    });
  });

  group('PinRules', () {
    test('6 chiffres exactement', () {
      expect(PinRules.isComplete('482915'), isTrue);
      expect(PinRules.isComplete('48291'), isFalse);
      expect(PinRules.isComplete('48291a'), isFalse);
    });

    test('refuse les PIN trop simples', () {
      for (final pin in ['000000', '111111', '123456', '654321', '345678']) {
        expect(PinRules.weaknessOf(pin), isNotNull, reason: pin);
      }
      expect(PinRules.weaknessOf('482915'), isNull);
    });
  });
}
