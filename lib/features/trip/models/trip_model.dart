import '../widgets/trip_status.dart';
import 'trip_enquiry_model.dart';
import 'trip_plan_model.dart';

class TripStatuses {
  static const String draft = 'Draft';
  static const String planned = 'Planned';
  static const String completed = 'Completed';
}

DateTime? _instant(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

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
  final Map<String, dynamic>? raw;

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
    this.raw,
  });

  bool get isPlanned => status == TripStatuses.planned;
  bool get isCompleted => status == TripStatuses.completed;
  bool get isMuted => mutedAt != null;

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
        raw: raw,
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
        raw: json,
      );
}

class TripSummaryModel {
  final String id;
  final String title;
  final String status;
  final String cityName;
  final int dayCount;
  final int spotCount;
  final int taxiDays;
  final int stayDays;
  final String? stayName;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? adults;
  final int? kids;
  final DateTime updatedAt;
  final String bookingState;
  final int staysConfirmed;
  final int staysTotal;
  final int taxisConfirmed;
  final int taxisTotal;
  final int agreedTotal;
  final DateTime? mutedAt;
  final DateTime? completedAt;

  const TripSummaryModel({
    required this.id,
    required this.title,
    required this.status,
    required this.cityName,
    required this.dayCount,
    required this.spotCount,
    required this.taxiDays,
    required this.stayDays,
    this.stayName,
    required this.category,
    this.startDate,
    this.endDate,
    this.adults,
    this.kids,
    required this.updatedAt,
    this.bookingState = 'draft',
    this.staysConfirmed = 0,
    this.staysTotal = 0,
    this.taxisConfirmed = 0,
    this.taxisTotal = 0,
    this.agreedTotal = 0,
    this.mutedAt,
    this.completedAt,
  });

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
        taxiDays: taxiDays,
        stayDays: stayDays,
        stayName: stayName,
        category: category,
        startDate: startDate,
        endDate: endDate,
        adults: adults,
        kids: kids,
        updatedAt: updatedAt,
        bookingState: bookingState ?? this.bookingState,
        staysConfirmed: staysConfirmed,
        staysTotal: staysTotal,
        taxisConfirmed: taxisConfirmed,
        taxisTotal: taxisTotal,
        agreedTotal: agreedTotal,
        mutedAt: mutedAt,
        completedAt: completedAt ?? this.completedAt,
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
        taxiDays: (json['taxiDays'] as num?)?.toInt() ?? 0,
        stayDays: (json['stayDays'] as num?)?.toInt() ?? 0,
        stayName: json['stayName'] as String?,
        category: json['category'] as String? ?? 'attraction',
        startDate: tripDate(json['startDate']),
        endDate: tripDate(json['endDate']),
        adults: (json['adults'] as num?)?.toInt(),
        kids: (json['kids'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        bookingState: json['bookingState'] as String? ?? 'draft',
        staysConfirmed: (json['staysConfirmed'] as num?)?.toInt() ?? 0,
        staysTotal: (json['staysTotal'] as num?)?.toInt() ?? 0,
        taxisConfirmed: (json['taxisConfirmed'] as num?)?.toInt() ?? 0,
        taxisTotal: (json['taxisTotal'] as num?)?.toInt() ?? 0,
        agreedTotal: (json['agreedTotal'] as num?)?.toInt() ?? 0,
        mutedAt: _instant(json['mutedAt']),
        completedAt: _instant(json['completedAt']),
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
