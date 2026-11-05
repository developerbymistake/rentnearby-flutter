import '../utils/money_format.dart';
import 'card_fact.dart';

class BrowseItem {
  final String id;
  final String userId;
  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<CardFact> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isFeatured;

  BrowseItem({
    required this.id,
    required this.userId,
    required this.thumbnailUrl,
    required this.tagLabel,
    required this.title,
    required this.locationLabel,
    required this.facts,
    required this.priceCaption,
    required this.priceValue,
    required this.priceUnit,
    this.isFeatured = false,
  });

  static String inr(num v) => Money.exact(v);
}

class BrowsePage {
  final List<BrowseItem> items;
  final bool hasMore;
  final String? nextCursor;

  const BrowsePage({required this.items, required this.hasMore, required this.nextCursor});
}
