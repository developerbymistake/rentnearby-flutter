import 'taxi_ways_models.dart';

class AskLimits {
  static const int perRequest = 6;
  static const int perLeg = 3;
  static const int nameMax = 80;

  static int perLegFor(int legCount) {
    final share = legCount <= 0 ? perLeg : perRequest ~/ legCount;
    return share < 1 ? 1 : (share > perLeg ? perLeg : share);
  }
}

String _clip(String s) => s.length > AskLimits.nameMax ? s.substring(0, AskLimits.nameMax) : s;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int? _fare(WayDriver d) => d.listedFare > 0 ? d.listedFare : null;

class AskLegRequest {
  final int legIndex;
  final String legKey;
  final String fromName;
  final String toName;
  final int? listedFare;
  final List<String> taxiIds;
  final int carOf;
  final String? comesFrom;

  const AskLegRequest({
    required this.legIndex,
    required this.legKey,
    required this.fromName,
    required this.toName,
    required this.listedFare,
    required this.taxiIds,
    required this.carOf,
    this.comesFrom,
  });

  Map<String, dynamic> toJson() => {
        'legIndex': legIndex,
        'legKey': legKey,
        'fromName': fromName,
        'toName': toName,
        'listedFare': ?listedFare,
        'taxiIds': taxiIds,
        'carOf': carOf,
        'comesFrom': ?comesFrom,
      };
}

class AskDriversRequest {
  final DateTime date;
  final int people;
  final String journeyId;
  final String fromName;
  final String toName;
  final List<AskLegRequest> legs;

  const AskDriversRequest({
    required this.date,
    required this.people,
    required this.journeyId,
    required this.fromName,
    required this.toName,
    required this.legs,
  });

  int get driverCount => legs.fold(0, (sum, l) => sum + l.taxiIds.length);

  Map<String, dynamic> toJson() => {
        'date': _isoDate(date),
        'people': people,
        'journeyId': journeyId,
        'fromName': fromName,
        'toName': toName,
        'legs': legs.map((l) => l.toJson()).toList(),
      };

  /// Chosen driver first, then backups from the leg's top drivers; null when a leg has no driver.
  static AskDriversRequest? fromPlan({
    required WayPlan plan,
    required Map<int, WayDriver> chosen,
    required DateTime date,
    required int people,
    required String journeyId,
    required String fromName,
    required String toName,
  }) {
    if (plan.legs.isEmpty || plan.legs.length > 3) return null;
    final cap = AskLimits.perLegFor(plan.legs.length);
    final legs = <AskLegRequest>[];
    for (final leg in plan.legs) {
      final pick = chosen[leg.index] ?? (leg.topDrivers.isNotEmpty ? leg.topDrivers.first : null);
      if (pick == null) return null;
      final ids = <String>[pick.taxiId];
      for (final d in leg.topDrivers) {
        if (ids.length >= cap) break;
        if (!ids.contains(d.taxiId)) ids.add(d.taxiId);
      }
      legs.add(AskLegRequest(
        legIndex: leg.index,
        legKey: leg.legKey,
        fromName: _clip(leg.from.name),
        toName: _clip(leg.to.name),
        listedFare: _fare(pick),
        taxiIds: ids,
        carOf: plan.legs.length,
        comesFrom: leg.index > 1 && legs.isNotEmpty ? _clip(legs.last.fromName) : null,
      ));
    }
    return AskDriversRequest(
      date: date,
      people: people,
      journeyId: journeyId,
      fromName: _clip(fromName),
      toName: _clip(toName),
      legs: legs,
    );
  }
}

class AskItem {
  final int legIndex;
  final String taxiId;
  final String enquiryId;
  final String status;

  const AskItem({required this.legIndex, required this.taxiId, required this.enquiryId, required this.status});

  factory AskItem.fromJson(Map<String, dynamic> j) => AskItem(
        legIndex: (j['legIndex'] as num?)?.toInt() ?? 0,
        taxiId: j['taxiId'] as String? ?? '',
        enquiryId: j['enquiryId'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );
}

class AskSkipped {
  final int legIndex;
  final String taxiId;
  final String reason;

  const AskSkipped({required this.legIndex, required this.taxiId, required this.reason});

  factory AskSkipped.fromJson(Map<String, dynamic> j) => AskSkipped(
        legIndex: (j['legIndex'] as num?)?.toInt() ?? 0,
        taxiId: j['taxiId'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
      );
}

class AskResult {
  final List<AskItem> items;
  final List<AskSkipped> skipped;
  final bool veryShortNotice;

  const AskResult({required this.items, required this.skipped, required this.veryShortNotice});

  factory AskResult.fromJson(Map<String, dynamic> j) => AskResult(
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AskItem.fromJson)
            .toList(),
        skipped: ((j['skipped'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AskSkipped.fromJson)
            .toList(),
        veryShortNotice: j['veryShortNotice'] == true,
      );

  int get askedCount => items.map((i) => i.taxiId).toSet().length;

  /// The lead id the journey keeps for a leg: the first created row of that leg.
  String? firstEnquiryFor(int legIndex) {
    for (final i in items) {
      if (i.legIndex == legIndex && i.enquiryId.isNotEmpty) return i.enquiryId;
    }
    return null;
  }
}
