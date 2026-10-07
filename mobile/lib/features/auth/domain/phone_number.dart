/// Numéro de mobile sénégalais (+221), seul format accepté à l'inscription.
///
/// Préfixes mobiles : 70 (Expresso), 75 (Promobile), 76 (Free), 77 / 78 (Orange).
class PhoneNumber {
  const PhoneNumber._(this.national);

  /// 9 chiffres, sans indicatif : `770000000`.
  final String national;

  static final _mobile = RegExp(r'^7[05678]\d{7}$');

  /// Accepte les espaces, tirets, `+221` ou `00221` en tête. `null` si invalide.
  static PhoneNumber? tryParse(String input) {
    var digits = input.replaceAll(RegExp(r'[\s.\-()]'), '');
    if (digits.startsWith('+221')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('00221')) {
      digits = digits.substring(5);
    }
    return _mobile.hasMatch(digits) ? PhoneNumber._(digits) : null;
  }

  /// Format E.164 attendu par Supabase : `+221770000000`.
  String get e164 => '+221$national';

  /// Affichage : `77 000 00 00`.
  String get display =>
      '${national.substring(0, 2)} ${national.substring(2, 5)} '
      '${national.substring(5, 7)} ${national.substring(7)}';

  @override
  bool operator ==(Object other) => other is PhoneNumber && other.national == national;

  @override
  int get hashCode => national.hashCode;
}
