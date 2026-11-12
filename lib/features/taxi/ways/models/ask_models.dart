import '../../../trip/models/trip_enquiry_model.dart';
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
  final String? clientRequestId;
  final String? stepKey;

  const AskDriversRequest({
    required this.date,
    required this.people,
    required this.journeyId,
    required this.fromName,
    required this.toName,
    required this.legs,
    this.clientRequestId,
    this.stepKey,
  });

  AskDriversRequest guided({required String clientRequestId, required String stepKey, required List<String> taxiIds}) {
    final first = legs.first;
    return AskDriversRequest(
      date: date,
      people: people,
      journeyId: journeyId,
      fromName: fromName,
      toName: toName,
      clientRequestId: clientRequestId,
      stepKey: stepKey,
      legs: [
        AskLegRequest(
          legIndex: first.legIndex,
          legKey: first.legKey,
          fromName: first.fromName,
          toName: first.toName,
          listedFare: first.listedFare,
          taxiIds: taxiIds,
          carOf: first.carOf,
          comesFrom: first.comesFrom,
        ),
      ],
    );
  }

  int get driverCount => legs.fold(0, (sum, l) => sum + l.taxiIds.length);

  Map<String, dynamic> toJson() => {
        'date': _isoDate(date),
        'people': people,
        'journeyId': journeyId,
        'fromName': fromName,
        'toName': toName,
        'legs': legs.map((l) => l.toJson()).toList(),
        'clientRequestId': ?clientRequestId,
        'stepKey': ?stepKey,
      };

  /// Chosen driver (or the seat cover's cars) first, then backups from the leg's top drivers; null when a leg has no driver.
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
      final manual = chosen[leg.index];
      final pick = leg.driverFor(manual);
      if (pick == null) return null;
      final ids = WayCover.askIds(pick.taxiId, leg.coverOthersFor(manual), leg.topDrivers.map((d) => d.taxiId), cap);
      legs.add(AskLegRequest(
        legIndex: leg.index,
        legKey: leg.legKey,
        fromName: _clip(wayNameOr(leg.from.name, leg.from.key, start: leg.index == 1, end: false)),
        toName: _clip(wayNameOr(leg.to.name, leg.to.key, start: false, end: leg.index == plan.legs.length)),
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
      fromName: _clip(wayNameOr(fromName, plan.from.key, start: true, end: false)),
      toName: _clip(wayNameOr(toName, plan.to.key, start: false, end: true)),
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
  final List<TripSendResult> results;

  const AskResult({required this.items, required this.skipped, required this.veryShortNotice, this.results = const []});

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
        results: TripSendResult.parseList(j['results']),
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
