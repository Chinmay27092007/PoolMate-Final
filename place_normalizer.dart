/// Turns free-text place names into a canonical key so that
/// "Airport", "airport T3" and "IGI Airport" all match each other.
///
/// Extend [aliases] for your campus. Unknown places fall back to the cleaned
/// text itself, so exact (case/punctuation-insensitive) matches still work.
class PlaceNormalizer {
  /// canonical key -> display label
  static const Map<String, String> labels = {
    'campus': 'Campus',
    'airport': 'Airport',
    'noida_airport': 'Noida International Airport',
    'railway_station': 'Railway Station',
    'city_centre': 'City Centre',
    'metro_station': 'Metro Station',
  };

  /// canonical key -> accepted spellings (already cleaned: lowercase, no punctuation)
  static const Map<String, List<String>> aliases = {
    'campus': [
      'campus',
      'bennett',
      'bennett university',
      'bennett campus',
      'university',
      'college',
      'main gate',
      'campus gate',
    ],
    'airport': [
      'airport',
      'igi',
      'igi airport',
      'del',
      'delhi airport',
      'delhi international airport',
      'indira gandhi international airport',
      'airport t3',
      'airport terminal 3',
      't3',
      'terminal 3',
      'airport terminal',
    ],
    'noida_airport': [
      'noida airport',
      'noida international airport',
      'jewar airport',
      'nia',
    ],
    'railway_station': [
      'railway station',
      'railway',
      'station',
      'new delhi railway station',
      'new delhi station',
      'ndls',
      'ghaziabad station',
    ],
    'city_centre': [
      'city centre',
      'city center',
      'city',
      'downtown',
      'noida city centre',
      'noida city center',
    ],
    'metro_station': [
      'metro',
      'metro station',
      'pari chowk metro',
      'knowledge park metro',
    ],
  };

  static Map<String, String>? _reverse;

  static Map<String, String> get _aliasToKey {
    return _reverse ??= {
      for (final e in aliases.entries)
        for (final a in e.value) a: e.key,
    };
  }

  /// Lowercase, punctuation -> spaces, collapse whitespace.
  static String clean(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Canonical comparison key for a place.
  static String key(String raw) {
    final cleaned = clean(raw);
    return _aliasToKey[cleaned] ?? cleaned;
  }

  /// Nice label to store/show: "airport t3" -> "Airport"; unknown -> trimmed input.
  static String label(String raw) {
    final k = key(raw);
    return labels[k] ?? raw.trim();
  }

  static bool samePlace(String a, String b) {
    final ka = key(a);
    return ka.isNotEmpty && ka == key(b);
  }
}
