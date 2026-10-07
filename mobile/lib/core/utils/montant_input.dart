import 'package:flutter/services.dart';

/// Saisie d'un montant FCFA : chiffres uniquement, groupés par milliers
/// pendant la frappe (`25000` → `25 000`). Jamais de décimales.
class MontantInputFormatter extends TextInputFormatter {
  const MontantInputFormatter();

  /// 999 milliards : sous la borne de l'API (10¹² FCFA).
  static const maxChiffres = 12;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.length > maxChiffres) return oldValue;
    final formatted = grouper(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String grouper(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// `"25 000"` → `25000`. Champ vide → 0.
int parseMontant(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}
