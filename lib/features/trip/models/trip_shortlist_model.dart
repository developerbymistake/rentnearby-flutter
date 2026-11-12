class ShortlistKinds {
  static const String stay = 'Stay';
  static const String taxi = 'Taxi';
  static const String car = 'Car';
}

class ShortlistStates {
  static const String active = 'Active';
  static const String sent = 'Sent';
  static const String closed = 'Closed';
  static const String booked = 'Booked';
}

class ShortlistClosedReasons {
  static const String noReply = 'NoReply';
}

class ShortlistItem {
  const ShortlistItem({
    required this.stepKey,
    required this.kind,
    required this.listingId,
    required this.name,
    this.journeyId,
    this.legIndex,
    this.state = ShortlistStates.active,
    this.closedReason,
    this.addedAt,
    this.closesAt,
  });

  final String stepKey;
  final String kind;
  final String listingId;
  final String name;
  final String? journeyId;
  final int? legIndex;
  final String state;
  final String? closedReason;
  final DateTime? addedAt;
  final DateTime? closesAt;

  bool get isActive => state == ShortlistStates.active;

  bool get isNoReply => state == ShortlistStates.closed && closedReason == ShortlistClosedReasons.noReply;

  factory ShortlistItem.fromJson(Map<String, dynamic> j, {String? stepKey}) => ShortlistItem(
        stepKey: j['stepKey'] as String? ?? stepKey ?? '',
        kind: j['kind'] as String? ?? ShortlistKinds.stay,
        listingId: j['listingId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        journeyId: j['journeyId'] as String?,
        legIndex: (j['legIndex'] as num?)?.toInt(),
        state: j['state'] as String? ?? ShortlistStates.active,
        closedReason: j['closedReason'] as String?,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? ''),
        closesAt: DateTime.tryParse(j['closesAt'] as String? ?? ''),
      );

  Map<String, dynamic> toBody() => {
        'kind': kind,
        'name': name,
        'journeyId': journeyId,
        'legIndex': legIndex,
      };
}

class TripShortlist {
  const TripShortlist({this.max = 3, this.items = const []});

  final int max;
  final List<ShortlistItem> items;

  static List<ShortlistItem> parseItems(Object? raw, {String? stepKey}) => [
        for (final m in ((raw as List?) ?? const []).whereType<Map<String, dynamic>>())
          if ((m['listingId'] as String?)?.isNotEmpty ?? false) ShortlistItem.fromJson(m, stepKey: stepKey),
      ];

  factory TripShortlist.fromJson(Map<String, dynamic> j) =>
      TripShortlist(max: (j['max'] as num?)?.toInt() ?? 3, items: parseItems(j['items']));
}

class MarkBookedResult {
  const MarkBookedResult({this.closedEnquiries = 0, this.closedShortlist = 0});

  final int closedEnquiries;
  final int closedShortlist;

  factory MarkBookedResult.fromJson(Map<String, dynamic> j) => MarkBookedResult(
        closedEnquiries: (j['closedEnquiries'] as num?)?.toInt() ?? 0,
        closedShortlist: (j['closedShortlist'] as num?)?.toInt() ?? 0,
      );
}

class ShortlistOrder {
  static List<T> noReplyLast<T>(List<T> rows, String Function(T) idOf, Set<String> noReply) {
    if (noReply.isEmpty) return rows;
    return [
      for (final r in rows)
        if (!noReply.contains(idOf(r))) r,
      for (final r in rows)
        if (noReply.contains(idOf(r))) r,
    ];
  }
}
