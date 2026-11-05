import '../config/app_constants.dart';
import '../utils/area_format.dart';
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

  factory BrowseItem.fromRoomJson(Map<String, dynamic> j) => BrowseItem.room(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String?,
        type: j['roomTypeName'] as String?,
        furnishedStatus: j['furnishedStatus'] as String?,
        isAc: j['isAc'] as bool?,
        priceMonthly: (j['priceMonthly'] as num?) ?? 0,
        city: j['cityName'] as String?,
        district: j['districtName'] as String?,
        isFeatured: j['isFeatured'] == true,
      );

  factory BrowseItem.fromPlotJson(Map<String, dynamic> j) => BrowseItem.plot(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String?,
        type: j['plotTypeName'] as String?,
        areaValue: (j['areaValue'] as num?)?.toDouble() ?? 0,
        areaUnit: j['areaUnit'] as String? ?? '',
        city: j['cityName'] as String?,
        district: j['districtName'] as String?,
        isFeatured: j['isFeatured'] == true,
      );

  factory BrowseItem.room({
    required String id,
    required String userId,
    String? thumbnailUrl,
    String? type,
    String? furnishedStatus,
    bool? isAc,
    required num priceMonthly,
    String? city,
    String? district,
    bool isFeatured = false,
  }) =>
      BrowseItem(
        id: id,
        userId: userId,
        thumbnailUrl: thumbnailUrl,
        tagLabel: 'FOR RENT',
        title: '${type ?? 'Room'} Room',
        locationLabel: _join(city, district),
        facts: [
          CardFact(furnishedLabel(furnishedStatus)),
          if (isAc != null) CardFact(AcStatus.label(isAc), tone: isAc ? FactTone.cyan : FactTone.slate),
        ],
        priceCaption: 'MONTHLY RENT',
        priceValue: inr(priceMonthly),
        priceUnit: '/mo',
        isFeatured: isFeatured,
      );

  factory BrowseItem.plot({
    required String id,
    required String userId,
    String? thumbnailUrl,
    String? type,
    required double areaValue,
    required String areaUnit,
    String? city,
    String? district,
    bool isFeatured = false,
  }) {
    return BrowseItem(
      id: id,
      userId: userId,
      thumbnailUrl: thumbnailUrl,
      tagLabel: 'FOR SALE',
      title: '${type ?? 'Plot'} Plot',
      locationLabel: _join(city, district),
      facts: [
        if (type != null && type.isNotEmpty) CardFact(type),
      ],
      priceCaption: 'PLOT AREA',
      priceValue: AreaFormat.label(areaValue, areaUnit),
      priceUnit: '',
      isFeatured: isFeatured,
    );
  }

  static String _join(String? city, String? district) =>
      [city, district].where((s) => s != null && s.isNotEmpty).join(', ');

  static String furnishedLabel(String? v) => switch (v) {
        'Semi' => 'Semi furnished',
        'Full' => 'Full furnished',
        null || '' || 'None' => 'Unfurnished',
        _ => '$v furnished',
      };

  static String? acLabel(bool? v) => v == null ? null : AcStatus.label(v);

  static String depositLabel(int v) => v == 0 ? 'None' : inr(v);

  static String inr(num v) => Money.exact(v);
}

class BrowsePage {
  final List<BrowseItem> items;
  final bool hasMore;
  final String? nextCursor;

  const BrowsePage({required this.items, required this.hasMore, required this.nextCursor});
}
