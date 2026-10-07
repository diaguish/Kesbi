import 'package:flutter/material.dart';

/// Palette Kës Bi. Source unique des couleurs : ne jamais écrire un hex ailleurs.
///
/// Règle de contraste (docs/design/README.md) : [accent] n'est JAMAIS une couleur
/// de texte sur fond clair, ni un fond sous du texte blanc. Sur fond [accent],
/// le texte est [textDark].
abstract final class AppColors {
  static const primary = Color(0xFF1B5E3B);
  static const accent = Color(0xFFD4A017);
  static const background = Color(0xFFF2EDE3);
  static const surface = Color(0xFFFAFAF5);
  static const textDark = Color(0xFF0D2E1C);
  static const error = Color(0xFFC0392B);

  /// Montants entrants (encaissements) et sortants (dépenses).
  static const incoming = primary;
  static const outgoing = error;
}
