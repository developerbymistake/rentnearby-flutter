class TripWarningCodes {
  static const String overLimit = 'OverLimit';
  static const String estimate = 'Estimate';
  static const String closedDay = 'ClosedDay';
  static const String routeMissing = 'RouteMissing';
  static const String osrmUnavailable = 'OsrmUnavailable';
  static const String tooManyDays = 'TooManyDays';
}

class TripLeg {
  final String fromId;
  final String toId;
  final int minutes;
  final double km;
  final bool isEstimate;

  const TripLeg({
    required this.fromId,
    required this.toId,
    required this.minutes,
    required this.km,
    required this.isEstimate,
  });

  factory TripLeg.fromJson(Map<String, dynamic> json) => TripLeg(
        fromId: json['fromId'] as String? ?? '',
        toId: json['toId'] as String? ?? '',
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        km: (json['km'] as num?)?.toDouble() ?? 0,
        isEstimate: json['isEstimate'] == true,
      );
}

class TripWarning {
  final String code;
  final String message;
  final String? spotId;
  final int? day;

  const TripWarning({required this.code, required this.message, this.spotId, this.day});

  factory TripWarning.fromJson(Map<String, dynamic> json) => TripWarning(
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
        spotId: json['spotId'] as String?,
        day: (json['day'] as num?)?.toInt(),
      );
}

class TripPlanDay {
  final int day;
  final List<String> spotIds;
  final int visitMinutes;
  final int driveMinutes;
  final int totalMinutes;
  final double km;
  final bool overLimit;
  final bool isEstimate;
  final List<TripLeg> legs;
  final Map<String, dynamic>? routeGeoJson;

  const TripPlanDay({
    required this.day,
    required this.spotIds,
    required this.visitMinutes,
    required this.driveMinutes,
    required this.totalMinutes,
    required this.km,
    required this.overLimit,
    required this.isEstimate,
    required this.legs,
    this.routeGeoJson,
  });

  TripLeg? legFrom(String fromId) {
    for (final l in legs) {
      if (l.fromId == fromId) return l;
    }
    return null;
  }

  factory TripPlanDay.fromJson(Map<String, dynamic> json) => TripPlanDay(
        day: (json['day'] as num).toInt(),
        spotIds: ((json['spotIds'] as List?) ?? const []).map((e) => e as String).toList(),
        visitMinutes: (json['visitMinutes'] as num?)?.toInt() ?? 0,
        driveMinutes: (json['driveMinutes'] as num?)?.toInt() ?? 0,
        totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
        km: (json['km'] as num?)?.toDouble() ?? 0,
        overLimit: json['overLimit'] == true,
        isEstimate: json['isEstimate'] == true,
        legs: ((json['legs'] as List?) ?? const [])
            .map((e) => TripLeg.fromJson(e as Map<String, dynamic>))
            .toList(),
        routeGeoJson: json['routeGeoJson'] is Map<String, dynamic> ? json['routeGeoJson'] as Map<String, dynamic> : null,
      );
}

class TripPlanResult {
  final List<TripPlanDay> days;
  final double? centreLatitude;
  final double? centreLongitude;
  final List<TripWarning> warnings;
  final bool osrmAvailable;
  final int dayLimitMinutes;

  const TripPlanResult({
    required this.days,
    this.centreLatitude,
    this.centreLongitude,
    required this.warnings,
    required this.osrmAvailable,
    required this.dayLimitMinutes,
  });

  TripPlanDay? dayAt(int day) {
    for (final d in days) {
      if (d.day == day) return d;
    }
    return null;
  }

  List<TripWarning> warningsFor(int day) => warnings.where((w) => w.day == day).toList();

  bool hasWarning(int day, String code) => warnings.any((w) => w.day == day && w.code == code);

  factory TripPlanResult.fromJson(Map<String, dynamic> json) => TripPlanResult(
        days: ((json['days'] as List?) ?? const [])
            .map((e) => TripPlanDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        centreLatitude: (json['centreLatitude'] as num?)?.toDouble(),
        centreLongitude: (json['centreLongitude'] as num?)?.toDouble(),
        warnings: ((json['warnings'] as List?) ?? const [])
            .map((e) => TripWarning.fromJson(e as Map<String, dynamic>))
            .toList(),
        osrmAvailable: json['osrmAvailable'] == true,
        dayLimitMinutes: (json['dayLimitMinutes'] as num?)?.toInt() ?? 450,
      );
}
