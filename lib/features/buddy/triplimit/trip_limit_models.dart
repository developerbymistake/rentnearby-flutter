import '../shared/buddy_json.dart';

class TripSlotTrip {
  const TripSlotTrip({required this.id, required this.title, required this.isOwner, this.startDate, this.endDate, this.ownerName});

  final String id;
  final String title;
  final bool isOwner;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? ownerName;

  factory TripSlotTrip.fromJson(Map<String, dynamic> j) => TripSlotTrip(
        id: BuddyJson.str(j['id']),
        title: BuddyJson.str(j['title']),
        isOwner: BuddyJson.str(j['role']).toLowerCase() == 'owner',
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        ownerName: BuddyJson.strOrNull(j['ownerName']),
      );

  bool endedBy(DateTime today) {
    final e = endDate;
    return e != null && e.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class TripSlots {
  const TripSlots({required this.limit, required this.count, required this.trips});

  static const int fallbackLimit = 3;

  final int limit;
  final int count;
  final List<TripSlotTrip> trips;

  bool get isFull => count >= limit;

  factory TripSlots.fromRefusal(Map<String, dynamic> data) {
    final trips = BuddyJson.list(data['trips'], TripSlotTrip.fromJson);
    final limit = BuddyJson.integer(data['limit'], fallbackLimit);
    return TripSlots(limit: limit < 1 ? fallbackLimit : limit, count: BuddyJson.integer(data['count'], trips.length), trips: trips);
  }

  TripSlots without(String tripId) {
    final left = [for (final t in trips) if (t.id != tripId) t];
    return TripSlots(limit: limit, count: left.length < trips.length ? count - 1 : count, trips: left);
  }
}
