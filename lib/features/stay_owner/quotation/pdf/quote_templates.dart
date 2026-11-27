import '../../strings/stay_quote_strings.dart';

class QuoteTemplateInfo {
  const QuoteTemplateInfo({required this.id, required this.name, required this.sub, required this.thumb});

  final String id;
  final String name;
  final String sub;
  final String thumb;
}

abstract final class QuoteTemplates {
  static const int version = 1;
  static const String classic = 'classic';
  static const String band = 'band';
  static const String modern = 'modern';
  static const String folder = 'assets/quote_templates';

  static const List<QuoteTemplateInfo> all = [
    QuoteTemplateInfo(id: classic, name: StayQuoteStrings.classic, sub: StayQuoteStrings.classicSub, thumb: '$folder/thumbs/classic.png'),
    QuoteTemplateInfo(id: band, name: StayQuoteStrings.band, sub: StayQuoteStrings.bandSub, thumb: '$folder/thumbs/band.png'),
    QuoteTemplateInfo(id: modern, name: StayQuoteStrings.modern, sub: StayQuoteStrings.modernSub, thumb: '$folder/thumbs/modern.png'),
  ];

  static bool isKnown(String id) => all.any((t) => t.id == id);

  static String safe(String id) => isKnown(id) ? id : classic;

  static QuoteTemplateInfo of(String id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static bool canDownload(int minTemplateVersion) => version >= minTemplateVersion;
}
