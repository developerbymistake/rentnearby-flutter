class BrowseItem {
  final String id;
  final String userId;
  final String? thumbnailUrl;
  final String badgeLabel;
  final String priceLabel;
  final String title;
  final String locationLabel;

  BrowseItem({
    required this.id,
    required this.userId,
    required this.thumbnailUrl,
    required this.badgeLabel,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
  });

  factory BrowseItem.fromRoomJson(Map<String, dynamic> j) {
    final type = j['roomTypeName'] as String?;
    final furnished = j['furnishedStatus'] as String? ?? 'None';
    return BrowseItem(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? '',
      thumbnailUrl: j['thumbnailUrl'] as String?,
      badgeLabel: type ?? 'Room',
      priceLabel: '₹${(j['priceMonthly'] as num?)?.toInt() ?? 0}/mo',
      title: '${type ?? 'Room'}${furnished != 'None' ? ' · $furnished' : ''}',
      locationLabel: _location(j),
    );
  }

  factory BrowseItem.fromPlotJson(Map<String, dynamic> j) {
    final type = j['plotTypeName'] as String?;
    final area = (j['areaValue'] as num?)?.toDouble() ?? 0;
    final unit = j['areaUnit'] as String? ?? '';
    return BrowseItem(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? '',
      thumbnailUrl: j['thumbnailUrl'] as String?,
      badgeLabel: type ?? 'Plot',
      priceLabel: '${area.toStringAsFixed(area.truncateToDouble() == area ? 0 : 1)} $unit',
      title: type ?? 'Plot',
      locationLabel: _location(j),
    );
  }

  static String _location(Map<String, dynamic> j) => [j['cityName'] as String?, j['districtName'] as String?]
      .where((s) => s != null && s.isNotEmpty)
      .join(', ');
}

class BrowsePage {
  final List<BrowseItem> items;
  final bool hasMore;
  final String? nextCursor;

  const BrowsePage({required this.items, required this.hasMore, required this.nextCursor});
}
