/// Formatage des montants FCFA. Seul point de formatage de l'app.
///
/// Les montants sont TOUJOURS des entiers (FCFA n'a pas de centimes, voir CLAUDE.md).
library;

/// Espace insécable : le montant ne se coupe jamais sur deux lignes.
const _nbsp = ' ';

/// Signe moins typographique (plus lisible que le tiret « - »).
const _minus = '−';

/// `25000` → `25 000 FCFA`, `-8000` → `−8 000 FCFA`.
String formatFcfa(int amount) {
  final sign = amount < 0 ? _minus : '';
  return '$sign${_groupThousands(amount.abs())}${_nbsp}FCFA';
}

/// Montant avec signe explicite pour les listes de transactions :
/// `+ 25 000 FCFA` (entrée) ou `− 8 000 FCFA` (sortie).
String formatFcfaSigned(int amount) {
  final sign = amount < 0 ? _minus : '+';
  return '$sign$_nbsp${_groupThousands(amount.abs())}${_nbsp}FCFA';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
