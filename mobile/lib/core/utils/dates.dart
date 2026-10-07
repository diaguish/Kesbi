/// Affichage des dates à l'heure de Dakar (règle n°5 : UTC en base).
///
/// Africa/Dakar = UTC+0 toute l'année (pas d'heure d'été) : l'heure de Dakar
/// est l'heure UTC, quel que soit le fuseau réglé sur le téléphone.
library;

DateTime heureDakar(DateTime date) => date.toUtc();

String _deux(int n) => n.toString().padLeft(2, '0');

/// `07/10 à 14:32`
String formatDateHeure(DateTime date) {
  final d = heureDakar(date);
  return '${_deux(d.day)}/${_deux(d.month)} à ${_deux(d.hour)}:${_deux(d.minute)}';
}

/// `07/10/2026`
String formatDate(DateTime date) {
  final d = heureDakar(date);
  return '${_deux(d.day)}/${_deux(d.month)}/${d.year}';
}

/// Même jour calendaire à Dakar.
bool memeJour(DateTime a, DateTime b) {
  final x = heureDakar(a);
  final y = heureDakar(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
