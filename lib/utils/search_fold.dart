class SearchFold {
  static const _groups = <String, String>{
    'a': 'àáâãäåāăąǎªȧ',
    'c': 'çćĉċč',
    'd': 'ď',
    'e': 'èéêëēĕėęěȩ',
    'g': 'ĝğġģǧ',
    'h': 'ĥ',
    'i': 'ìíîïĩīĭį',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľ',
    'n': 'ñńņňǹ',
    'o': 'òóôõöōŏőºǒ',
    'r': 'ŕŗř',
    's': 'śŝşšſ',
    't': 'ţť',
    'u': 'ùúûüũūŭůűųǔ',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };

  // Inclusive code point ranges of Latin Extended Additional (IAST, Vietnamese).
  static const _ranges = <List<Object>>[
    [0x1E00, 0x1E01, 'a'],
    [0x1E02, 0x1E07, 'b'],
    [0x1E08, 0x1E09, 'c'],
    [0x1E0A, 0x1E13, 'd'],
    [0x1E14, 0x1E1D, 'e'],
    [0x1E1E, 0x1E1F, 'f'],
    [0x1E20, 0x1E21, 'g'],
    [0x1E22, 0x1E2B, 'h'],
    [0x1E2C, 0x1E2F, 'i'],
    [0x1E30, 0x1E35, 'k'],
    [0x1E36, 0x1E3D, 'l'],
    [0x1E3E, 0x1E43, 'm'],
    [0x1E44, 0x1E4B, 'n'],
    [0x1E4C, 0x1E53, 'o'],
    [0x1E54, 0x1E57, 'p'],
    [0x1E58, 0x1E5F, 'r'],
    [0x1E60, 0x1E69, 's'],
    [0x1E6A, 0x1E71, 't'],
    [0x1E72, 0x1E7B, 'u'],
    [0x1E7C, 0x1E7F, 'v'],
    [0x1E80, 0x1E89, 'w'],
    [0x1E8A, 0x1E8D, 'x'],
    [0x1E8E, 0x1E8F, 'y'],
    [0x1E90, 0x1E95, 'z'],
    [0x1E96, 0x1E96, 'h'],
    [0x1E97, 0x1E97, 't'],
    [0x1E98, 0x1E98, 'w'],
    [0x1E99, 0x1E99, 'y'],
    [0x1E9A, 0x1E9A, 'a'],
    [0x1E9B, 0x1E9B, 's'],
    [0x1EA0, 0x1EB7, 'a'],
    [0x1EB8, 0x1EC7, 'e'],
    [0x1EC8, 0x1ECB, 'i'],
    [0x1ECC, 0x1EE3, 'o'],
    [0x1EE4, 0x1EF1, 'u'],
    [0x1EF2, 0x1EF9, 'y'],
  ];

  static final Map<int, String> _table = _build();

  static Map<int, String> _build() {
    final m = <int, String>{};
    _groups.forEach((base, chars) {
      for (final r in chars.runes) {
        m[r] = base;
      }
    });
    m[0x01A1] = 'o';
    m[0x01B0] = 'u';
    m[0x0219] = 's';
    m[0x021B] = 't';
    m[0x00B2] = '2';
    m[0x00B3] = '3';
    m[0x00B9] = '1';
    for (final r in _ranges) {
      for (var c = r[0] as int; c <= (r[1] as int); c++) {
        m[c] = r[2] as String;
      }
    }
    return m;
  }

  static String fold(String? value) {
    if (value == null || value.isEmpty) return '';
    final out = StringBuffer();
    var pendingSep = false;
    void emit(String ch) {
      if (pendingSep && out.isNotEmpty) out.write(' ');
      pendingSep = false;
      out.write(ch);
    }

    for (final rune in value.toLowerCase().runes) {
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      String? ch = _table[rune];
      if (ch == null) {
        if (rune >= 0xFF10 && rune <= 0xFF19) {
          ch = String.fromCharCode(0x30 + rune - 0xFF10);
        } else if (rune >= 0xFF41 && rune <= 0xFF5A) {
          ch = String.fromCharCode(0x61 + rune - 0xFF41);
        } else if ((rune >= 0x61 && rune <= 0x7A) || (rune >= 0x30 && rune <= 0x39)) {
          ch = String.fromCharCode(rune);
        }
      }
      if (ch == null) {
        pendingSep = true;
      } else {
        emit(ch);
      }
    }
    return out.toString();
  }

  static bool startsWith(String text, String foldedQuery) => fold(text).startsWith(foldedQuery);

  static bool contains(String text, String foldedQuery) => fold(text).contains(foldedQuery);
}
