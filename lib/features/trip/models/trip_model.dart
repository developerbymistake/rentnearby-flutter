import 'trip_plan_model.dart';

class TripStatuses {
  static const String draft = 'Draft';
  static const String planned = 'Planned';
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
  final DateTime createdAt;
  final DateTime updatedAt;

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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPlanned => status == TripStatuses.planned;

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
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
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
  final DateTime updatedAt;

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
    required this.updatedAt,
  });

  bool get isPlanned => status == TripStatuses.planned;

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
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class TripListPage {
  final List<TripSummaryModel> items;
  final bool hasMore;

  const TripListPage({required this.items, required this.hasMore});

  factory TripListPage.fromJson(Map<String, dynamic> json) => TripListPage(
        items: ((json['items'] as List?) ?? const [])
            .map((e) => TripSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] == true,
      );
}
