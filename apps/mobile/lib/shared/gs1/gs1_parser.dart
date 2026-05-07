// Parser GS1 DataMatrix pour les boîtes de médicaments FR (#81).
//
// Périmètre AC : AI (01) GTIN-14, (17) péremption, (10) lot, (21) série.
// Les autres AI fixes connus sont consommés silencieusement (pour ne pas
// casser le parsing s'ils sont présents) ; les AI variables inconnues
// sont remontées dans `unknownAis` à des fins de diagnostic.
//
// Tolérance attendue (cf. AC #81) : symbology identifier (`]d2`, `]C1`,
// `]e0`), FNC1 sous formes diverses (0x1D, `~F`, `<GS>`), espaces
// résiduels en début/fin de champ.

class Gs1Parsed {
  const Gs1Parsed({
    this.gtin,
    this.expiry,
    this.lot,
    this.serial,
    this.unknownAis = const [],
  });

  /// AI (01) — 14 chiffres. Pour les médicaments FR, c'est `0` + CIP13.
  final String? gtin;

  /// AI (17) — date de péremption. Le jour `00` GS1 = dernier jour du mois.
  final DateTime? expiry;

  /// AI (10) — numéro de lot, jusqu'à 20 caractères alphanumériques.
  final String? lot;

  /// AI (21) — numéro de série, jusqu'à 20 caractères alphanumériques.
  final String? serial;

  /// AIs reconnues comme variable mais hors périmètre (info diagnostic).
  final List<String> unknownAis;

  /// CIP13 dérivé du GTIN-14 (drop du leading 0). Retourne null si le
  /// GTIN ne ressemble pas à un GTIN FR médicament (préfixe `03400`).
  String? get cip13 {
    final g = gtin;
    if (g == null || g.length != 14) return null;
    if (!g.startsWith('0')) return null;
    return g.substring(1);
  }

  bool get isEmpty =>
      gtin == null && expiry == null && lot == null && serial == null;
}

/// Longueurs fixes des AI standards GS1 que le parser doit savoir
/// "consommer" sans erreur (même si on ne les exploite pas tous).
const Map<String, int> _fixedAiLengths = {
  '00': 18,
  '01': 14,
  '02': 14,
  '03': 14,
  '04': 16,
  '11': 6,
  '12': 6,
  '13': 6,
  '14': 6,
  '15': 6,
  '16': 6,
  '17': 6,
  '18': 6,
  '19': 6,
  '20': 2,
};

/// AIs variables exploitées (les autres tombent dans `unknownAis`).
const Set<String> _knownVariableAis = {'10', '21'};

const String _gs = '\x1d';

/// Normalise les séparateurs FNC1 vers `\x1d` (GS) et retire les
/// préfixes de symbology identifier éventuels.
String _normalize(String input) {
  var s = input;
  for (final prefix in const [']d2', ']C1', ']e0', ']Q3', ']d1']) {
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length);
      break;
    }
  }
  // Variantes textuelles de FNC1 produites par certains scanners.
  s = s.replaceAll('<GS>', _gs).replaceAll('~F', _gs).replaceAll('', _gs);
  return s;
}

/// Parse une chaîne GS1 (DataMatrix d'une boîte FR) et retourne les
/// champs reconnus. Retourne `Gs1Parsed()` vide si rien n'est extrait.
Gs1Parsed parseGs1(String input) {
  if (input.isEmpty) return const Gs1Parsed();
  final s = _normalize(input);

  String? gtin;
  String? lot;
  String? serial;
  DateTime? expiry;
  final unknownAis = <String>[];

  var i = 0;
  while (i < s.length) {
    // Sauter les séparateurs résiduels et les espaces (tolérance AC).
    final c = s.codeUnitAt(i);
    if (c == 0x1d || c == 0x20) {
      i++;
      continue;
    }

    if (i + 2 > s.length) break;
    final ai = s.substring(i, i + 2);
    if (!_isDigit(ai.codeUnitAt(0)) || !_isDigit(ai.codeUnitAt(1))) {
      // Donnée non-GS1 résiduelle, on s'arrête proprement.
      break;
    }
    i += 2;

    final fixedLen = _fixedAiLengths[ai];
    if (fixedLen != null) {
      if (i + fixedLen > s.length) break;
      final value = s.substring(i, i + fixedLen);
      i += fixedLen;
      switch (ai) {
        case '01':
          gtin = value;
          break;
        case '17':
          expiry = _parseExpiryYymmdd(value);
          break;
      }
    } else {
      // AI variable : on lit jusqu'au prochain FNC1 ou fin.
      final end = s.indexOf(_gs, i);
      final stop = end == -1 ? s.length : end;
      final value = s.substring(i, stop).trim();
      i = stop;
      if (ai == '10') {
        lot = value;
      } else if (ai == '21') {
        serial = value;
      } else if (!_knownVariableAis.contains(ai)) {
        unknownAis.add(ai);
      }
    }
  }

  return Gs1Parsed(
    gtin: gtin,
    expiry: expiry,
    lot: lot,
    serial: serial,
    unknownAis: List.unmodifiable(unknownAis),
  );
}

bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

/// AI 17 : `YYMMDD`. Règle GS1 — `DD == 00` désigne le dernier jour
/// du mois (utilisé par les fabricants quand seule l'année/le mois
/// importent pour la péremption).
DateTime? _parseExpiryYymmdd(String value) {
  if (value.length != 6) return null;
  for (var k = 0; k < 6; k++) {
    if (!_isDigit(value.codeUnitAt(k))) return null;
  }
  final yy = int.parse(value.substring(0, 2));
  final mm = int.parse(value.substring(2, 4));
  final dd = int.parse(value.substring(4, 6));
  // Pour les médicaments la péremption est toujours future : on
  // mappe systématiquement vers 20YY (la règle GS1 stricte 50/99 →
  // 19YY ne s'applique pas au cas d'usage).
  final year = 2000 + yy;
  if (mm < 1 || mm > 12) return null;
  if (dd == 0) {
    final firstOfNext = DateTime(year, mm + 1, 1);
    return firstOfNext.subtract(const Duration(days: 1));
  }
  if (dd < 1 || dd > 31) return null;
  final d = DateTime(year, mm, dd);
  if (d.year != year || d.month != mm || d.day != dd) return null;
  return d;
}
