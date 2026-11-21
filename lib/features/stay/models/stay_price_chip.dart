enum StayPriceChipKind { off }

class StayPriceChip {
  final StayPriceChipKind kind;
  final String text;

  const StayPriceChip({required this.kind, required this.text});

  static StayPriceChip? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final text = raw['text'];
    if (kind != 'Off' || text is! String || text.trim().isEmpty) return null;
    return StayPriceChip(kind: StayPriceChipKind.off, text: text.trim());
  }

  static int? money(Object? v) {
    final n = v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
    return n == null || n <= 0 ? null : n;
  }
}
