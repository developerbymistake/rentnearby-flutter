import 'trip_enquiry_model.dart' show tripDate;

String? _name(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? _int(Object? v) {
  if (v is! num) return null;
  final n = v.toInt();
  return n < 0 ? null : n;
}

List<String> _names(Object? raw, {int? cap}) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final v in raw) {
    final n = _name(v);
    if (n == null) continue;
    out.add(n);
    if (cap != null && out.length >= cap) break;
  }
  return out;
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TripArchiveCity {
  static const int maxSpots = 6;

  final String name;
  final int nights;
  final List<String> spots;
  final int? spotCount;
  final List<String> stays;

  const TripArchiveCity({required this.name, this.nights = 0, this.spots = const [], this.spotCount, this.stays = const []});

  int get moreSpots {
    final total = spotCount;
    if (total == null || total <= spots.length) return 0;
    return total - spots.length;
  }

  static TripArchiveCity? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = _name(raw['name']);
    if (name == null) return null;
    return TripArchiveCity(
      name: name,
      nights: _int(raw['nights']) ?? 0,
      spots: _names(raw['spots'], cap: maxSpots),
      spotCount: _int(raw['spotCount']),
      stays: _names(raw['stays']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'nights': nights,
        'spots': spots,
        if (spotCount != null) 'spotCount': spotCount,
        'stays': stays,
      };
}

// The small record the server keeps for a trip whose plan was removed 3 months after it ended.
class TripArchiveSummary {
  final int version;
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? dayCount;
  final int? spotCount;
  final List<TripArchiveCity> cities;
  final bool taxiBooked;
  final int? memberCount;
  final int? expensesTotal;

  const TripArchiveSummary({
    this.version = 1,
    this.title,
    this.startDate,
    this.endDate,
    this.dayCount,
    this.spotCount,
    this.cities = const [],
    this.taxiBooked = false,
    this.memberCount,
    this.expensesTotal,
  });

  static TripArchiveSummary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final cities = raw['cities'] is List
        ? [
            for (final c in raw['cities'] as List)
              if (TripArchiveCity.tryParse(c) case final city?) city,
          ]
        : const <TripArchiveCity>[];
    return TripArchiveSummary(
      version: _int(raw['version']) ?? 1,
      title: _name(raw['title']),
      startDate: tripDate(raw['startDate']),
      endDate: tripDate(raw['endDate']),
      dayCount: _int(raw['dayCount']),
      spotCount: _int(raw['spotCount']),
      cities: cities,
      taxiBooked: raw['taxiBooked'] == true,
      memberCount: _int(raw['memberCount']),
      expensesTotal: _int(raw['expensesTotal']),
    );
  }

  // Used when the server says archived but sends no summary: only the trip's own columns are shown.
  factory TripArchiveSummary.fallback({
    String? title,
    List<String> legCities = const [],
    DateTime? startDate,
    DateTime? endDate,
    int? dayCount,
    int? spotCount,
  }) =>
      TripArchiveSummary(
        title: _name(title),
        startDate: startDate,
        endDate: endDate,
        dayCount: dayCount != null && dayCount > 0 ? dayCount : null,
        spotCount: spotCount != null && spotCount > 0 ? spotCount : null,
        cities: [
          for (final c in legCities)
            if (_name(c) case final n?) TripArchiveCity(name: n),
        ],
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        if (title != null) 'title': title,
        if (startDate != null) 'startDate': _date(startDate!),
        if (endDate != null) 'endDate': _date(endDate!),
        if (dayCount != null) 'dayCount': dayCount,
        if (spotCount != null) 'spotCount': spotCount,
        'cities': cities.map((c) => c.toJson()).toList(),
        if (taxiBooked) 'taxiBooked': true,
        if (memberCount != null) 'memberCount': memberCount,
        if (expensesTotal != null) 'expensesTotal': expensesTotal,
      };
}
