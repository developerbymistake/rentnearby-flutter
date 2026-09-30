class BrowseItem {
  final String id;
  final String userId;
  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<String> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;

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
  });

  factory BrowseItem.fromRoomJson(Map<String, dynamic> j) => BrowseItem.room(
        id: j['id'] as String,
        userId: j['userId'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String?,
        type: j['roomTypeName'] as String?,
        furnishedStatus: j['furnishedStatus'] as String?,
        priceMonthly: (j['priceMonthly'] as num?) ?? 0,
        city: j['cityName'] as String?,
        district: j['districtName'] as String?,
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
      );

  factory BrowseItem.room({
    required String id,
    required String userId,
    String? thumbnailUrl,
    String? type,
    String? furnishedStatus,
    required num priceMonthly,
    String? city,
    String? district,
  }) =>
      BrowseItem(
        id: id,
        userId: userId,
        thumbnailUrl: thumbnailUrl,
        tagLabel: 'FOR RENT',
        title: '${type ?? 'Room'} Room',
        locationLabel: _join(city, district),
        facts: [furnishedLabel(furnishedStatus)],
        priceCaption: 'MONTHLY RENT',
        priceValue: inr(priceMonthly),
        priceUnit: '/mo',
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
  }) {
    return BrowseItem(
      id: id,
      userId: userId,
      thumbnailUrl: thumbnailUrl,
      tagLabel: 'FOR SALE',
      title: '${type ?? 'Plot'} Plot',
      locationLabel: _join(city, district),
      facts: [
        if (type != null && type.isNotEmpty) type,
      ],
      priceCaption: 'PLOT AREA',
      priceValue: '${areaValue.toStringAsFixed(areaValue.truncateToDouble() == areaValue ? 0 : 1)} $areaUnit'.trim(),
      priceUnit: '',
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

  static String inr(num v) {
    final s = v.toInt().toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '₹${parts.join(',')},$last3';
  }
}

class BrowsePage {
  final List<BrowseItem> items;
  final bool hasMore;
  final String? nextCursor;

  const BrowsePage({required this.items, required this.hasMore, required this.nextCursor});
}
