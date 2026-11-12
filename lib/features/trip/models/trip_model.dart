import '../trip_strings_mca_a4.dart';
import '../widgets/trip_status.dart';
import 'trip_enquiry_model.dart';
import 'trip_journey_model.dart';
import 'trip_plan_model.dart';

class TripStatuses {
  static const String draft = 'Draft';
  static const String planned = 'Planned';
  static const String completed = 'Completed';
}

DateTime? _instant(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

List<String>? _legCitiesOf(Object? raw) {
  if (raw is! List) return null;
  final out = raw.whereType<String>().where((c) => c.isNotEmpty).toList();
  return out.isEmpty ? null : out;
}

int _legCountOf(Object? raw, List<String>? cities) {
  final n = raw is num ? raw.toInt() : (cities?.length ?? 1);
  return n < 1 ? 1 : n;
}

class TripModel {
  final String id;
  final String title;
  final String status;
  final int cityKey;
  final String? districtId;
  final String cityName;
  final double cityLatitude;
  final double cityLongitude;
  final int dayCount;
  final int spotCount;
  final TripPlan plan;
  final List<TripEnquiryModel> enquiries;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? mutedAt;
  final DateTime? completedAt;
  final String bookingState;
  final List<TripJourney> journeys;
  final bool journeysKnown;
  final int legCount;
  final List<String>? _legCities;
  final Map<String, dynamic>? raw;
  final TripProgress? progress;

  const TripModel({
    required this.id,
    required this.title,
    required this.status,
    required this.cityKey,
    this.districtId,
    required this.cityName,
    required this.cityLatitude,
    required this.cityLongitude,
    required this.dayCount,
    required this.spotCount,
    required this.plan,
    this.enquiries = const [],
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.mutedAt,
    this.completedAt,
    this.bookingState = 'draft',
    this.journeys = const [],
    this.journeysKnown = false,
    this.legCount = 1,
    List<String>? legCities,
    this.raw,
    this.progress,
  }) : _legCities = legCities;

  List<String> get legCities => _legCities ?? [cityName];
  String get routeLine => legCount > 1 ? TripStringsMcaA4.routeOf(legCities) : cityName;

  bool get isPlanned => status == TripStatuses.planned;
  bool get isCompleted => status == TripStatuses.completed;
  bool get isMuted => mutedAt != null;

  bool get stepsKnown {
    final p = raw?['plan'];
    return p is Map && p.containsKey('steps');
  }

  TripJourney? journeyById(String? id) {
    if (id == null) return null;
    for (final j in journeys) {
      if (j.id == id) return j;
    }
    return null;
  }

  TripModel copyWith({
    String? title,
    String? status,
    String? districtId,
    TripPlan? plan,
    List<TripEnquiryModel>? enquiries,
    DateTime? startDate,
    DateTime? endDate,
    int? dayCount,
    int? spotCount,
    DateTime? updatedAt,
    DateTime? mutedAt,
    DateTime? completedAt,
    String? bookingState,
    List<TripJourney>? journeys,
    bool? journeysKnown,
  }) =>
      TripModel(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
        cityKey: cityKey,
        districtId: districtId ?? this.districtId,
        cityName: cityName,
        cityLatitude: cityLatitude,
        cityLongitude: cityLongitude,
        dayCount: dayCount ?? this.dayCount,
        spotCount: spotCount ?? this.spotCount,
        plan: plan ?? this.plan,
        enquiries: enquiries ?? this.enquiries,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        mutedAt: mutedAt ?? this.mutedAt,
        completedAt: completedAt ?? this.completedAt,
        bookingState: bookingState ?? this.bookingState,
        journeys: journeys ?? this.journeys,
        journeysKnown: journeysKnown ?? this.journeysKnown,
        legCount: legCount,
        legCities: _legCities,
        raw: raw,
        progress: progress,
      );

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? TripStatuses.draft,
        cityKey: (json['cityKey'] as num).toInt(),
        districtId: json['districtId'] as String?,
        cityName: json['cityName'] as String? ?? '',
        cityLatitude: (json['cityLatitude'] as num?)?.toDouble() ?? 0,
        cityLongitude: (json['cityLongitude'] as num?)?.toDouble() ?? 0,
        dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
        spotCount: (json['spotCount'] as num?)?.toInt() ?? 0,
        plan: TripPlan.fromJson(json['plan'] as Map<String, dynamic>),
        enquiries: ((json['enquiries'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripEnquiryModel.fromJson)
            .toList(),
        startDate: tripDate(json['startDate']),
        endDate: tripDate(json['endDate']),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        mutedAt: _instant(json['mutedAt']),
        completedAt: _instant(json['completedAt']),
        bookingState: json['bookingState'] as String? ?? 'draft',
        journeys: ((json['journeys'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripJourney.fromJson)
            .where((j) => j.id.isNotEmpty)
            .toList(),
        journeysKnown: json['journeys'] is List,
        legCount: _legCountOf(json['legCount'], _legCitiesOf(json['legCities'])),
        legCities: _legCitiesOf(json['legCities']),
        raw: json,
        progress: TripProgress.tryParse(json['progress']),
      );
}

int _count(Object? raw) {
  final n = raw is num ? raw.toInt() : 0;
  return n < 0 ? 0 : n;
}

class TripNextRow {
  final String kind;
  final int? legIndex;
  final String key;

  const TripNextRow({required this.kind, this.legIndex, required this.key});

  TripEasyRowKey? get rowKey => TripEasyRowKey.parse(key);

  static TripNextRow? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final kind = raw['kind'];
    if (key is! String || key.isEmpty) return null;
    return TripNextRow(
      kind: kind is String ? kind : key.split(':').first,
      legIndex: (raw['legIndex'] as num?)?.toInt(),
      key: key,
    );
  }
}

class TripEasyRowModel {
  final TripEasyRowKey key;
  final TripRowState state;
  final bool needsYou;
  final int askedCount;
  final int? nightsTotal;
  final int? nightsCovered;

  const TripEasyRowModel({
    required this.key,
    this.state = TripRowState.todo,
    this.needsYou = false,
    this.askedCount = 0,
    this.nightsTotal,
    this.nightsCovered,
  });

  TripEasyRowKind get kind => key.kind;

  int? get legIndex => key.legIndex;

  static TripEasyRowModel? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['key'];
    final key = TripEasyRowKey.parse(id is String ? id : null);
    if (key == null) return null;
    return TripEasyRowModel(
      key: key,
      state: TripRowState.parse(raw['state']),
      needsYou: raw['needsYou'] == true,
      askedCount: _count(raw['askedCount']),
      nightsTotal: (raw['nightsTotal'] as num?)?.toInt(),
      nightsCovered: (raw['nightsCovered'] as num?)?.toInt(),
    );
  }
}

String? _guideStep(Object? raw) => raw is String && TripGuide.stepPattern.hasMatch(raw) ? raw : null;

class TripProgress {
  final int total;
  final int done;
  final int inProgress;
  final int attention;
  final int percent;
  final bool needsYou;
  final TripNextRow? next;
  final String? guideStep;
  final DateTime? lastEventAt;
  final List<TripEasyRowModel> rows;

  const TripProgress({
    this.total = 0,
    this.done = 0,
    this.inProgress = 0,
    this.attention = 0,
    this.percent = 0,
    this.needsYou = false,
    this.next,
    this.guideStep,
    this.lastEventAt,
    this.rows = const [],
  });

  bool get isReady => total > 0 && done >= total;

  static TripProgress? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final total = _count(raw['total']);
    final done = _count(raw['done']);
    final pct = raw['percent'] is num ? _count(raw['percent']) : (total == 0 ? 100 : done * 100 ~/ total);
    final rows = raw['rows'] is List
        ? [
            for (final r in raw['rows'] as List)
              if (TripEasyRowModel.tryParse(r) case final m?) m,
          ]
        : const <TripEasyRowModel>[];
    return TripProgress(
      total: total,
      done: done > total ? total : done,
      inProgress: _count(raw['inProgress']),
      attention: _count(raw['attention']),
      percent: pct > 100 ? 100 : pct,
      needsYou: raw['needsYou'] == true,
      next: TripNextRow.tryParse(raw['next']),
      guideStep: _guideStep(raw['guideStep']),
      lastEventAt: _instant(raw['lastEventAt']),
      rows: rows,
    );
  }
}

class TripSummaryModel {
  final String id;
  final String title;
  final String status;
  final String cityName;
  final int dayCount;
  final int spotCount;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? adults;
  final int? kids;
  final DateTime updatedAt;
  final String bookingState;
  final int agreedTotal;
  final DateTime? mutedAt;
  final DateTime? completedAt;
  final int legCount;
  final List<String>? _legCities;
  final TripProgress progress;

  const TripSummaryModel({
    required this.id,
    required this.title,
    required this.status,
    required this.cityName,
    required this.dayCount,
    required this.spotCount,
    required this.category,
    this.startDate,
    this.endDate,
    this.adults,
    this.kids,
    required this.updatedAt,
    this.bookingState = 'draft',
    this.agreedTotal = 0,
    this.mutedAt,
    this.completedAt,
    this.legCount = 1,
    List<String>? legCities,
    this.progress = const TripProgress(),
  }) : _legCities = legCities;

  List<String> get legCities => _legCities ?? [cityName];
  String get routeLine => legCount > 1 ? TripStringsMcaA4.routeOf(legCities) : cityName;

  bool isRunningOn(DateTime today) {
    final s = startDate;
    if (s == null || isCompleted) return false;
    final end = endDate ?? DateTime(s.year, s.month, s.day + (dayCount < 1 ? 0 : dayCount - 1));
    final t = DateTime(today.year, today.month, today.day);
    final tomorrow = DateTime(t.year, t.month, t.day + 1);
    return (!t.isBefore(s) && !t.isAfter(end)) || s == tomorrow;
  }

  DateTime? get checkOutDate {
    final s = startDate;
    final end = endDate ?? (s == null ? null : DateTime(s.year, s.month, s.day + (dayCount < 1 ? 0 : dayCount - 1)));
    return end == null ? null : DateTime(end.year, end.month, end.day + 1);
  }

  bool isCheckOutDay(DateTime today) {
    final out = checkOutDate;
    if (out == null || isCompleted) return false;
    return out.year == today.year && out.month == today.month && out.day == today.day;
  }

  int? dayNumberOn(DateTime today) {
    final s = startDate;
    if (s == null) return null;
    final n = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(s.year, s.month, s.day)).inDays + 1;
    return n >= 1 && n <= dayCount ? n : null;
  }

  bool get isPlanned => status == TripStatuses.planned;
  bool get isCompleted => status == TripStatuses.completed;
  TripBookingState get state => TripBookingState.parse(bookingState);

  TripSummaryModel _with({String? status, String? bookingState, DateTime? mutedAt, DateTime? completedAt}) => TripSummaryModel(
        id: id,
        title: title,
        status: status ?? this.status,
        cityName: cityName,
        dayCount: dayCount,
        spotCount: spotCount,
        category: category,
        startDate: startDate,
        endDate: endDate,
        adults: adults,
        kids: kids,
        updatedAt: updatedAt,
        bookingState: bookingState ?? this.bookingState,
        agreedTotal: agreedTotal,
        mutedAt: mutedAt,
        completedAt: completedAt ?? this.completedAt,
        legCount: legCount,
        legCities: _legCities,
        progress: progress,
      );

  TripSummaryModel withMuted(DateTime? at) => _with(mutedAt: at, completedAt: completedAt);

  TripSummaryModel asCompleted(DateTime? at) =>
      _with(status: TripStatuses.completed, bookingState: 'completed', mutedAt: mutedAt, completedAt: at);

  factory TripSummaryModel.fromJson(Map<String, dynamic> json) => TripSummaryModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? TripStatuses.draft,
        cityName: json['cityName'] as String? ?? '',
        dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
        spotCount: (json['spotCount'] as num?)?.toInt() ?? 0,
        category: json['category'] as String? ?? 'attraction',
        startDate: tripDate(json['startDate']),
        endDate: tripDate(json['endDate']),
        adults: (json['adults'] as num?)?.toInt(),
        kids: (json['kids'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        bookingState: json['bookingState'] as String? ?? 'draft',
        agreedTotal: (json['agreedTotal'] as num?)?.toInt() ?? 0,
        mutedAt: _instant(json['mutedAt']),
        completedAt: _instant(json['completedAt']),
        legCount: _legCountOf(json['legCount'], _legCitiesOf(json['legCities'])),
        legCities: _legCitiesOf(json['legCities']),
        progress: TripProgress.tryParse(json['progress']) ?? const TripProgress(),
      );
}

class TripListCounts {
  final int upcoming;
  final int completed;

  const TripListCounts({this.upcoming = 0, this.completed = 0});

  factory TripListCounts.fromJson(Map<String, dynamic> json) => TripListCounts(
        upcoming: (json['upcoming'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
      );
}

class TripListPage {
  final List<TripSummaryModel> items;
  final bool hasMore;
  final TripListCounts counts;

  const TripListPage({required this.items, required this.hasMore, this.counts = const TripListCounts()});

  factory TripListPage.fromJson(Map<String, dynamic> json) => TripListPage(
        items: ((json['items'] as List?) ?? const [])
            .map((e) => TripSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] == true,
        counts: json['counts'] is Map<String, dynamic>
            ? TripListCounts.fromJson(json['counts'] as Map<String, dynamic>)
            : const TripListCounts(),
      );
}
