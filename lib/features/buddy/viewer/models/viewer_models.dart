import '../../shared/buddy_json.dart';
import '../../sharing/models/sharing_models.dart';

class TripOwnerRef {
  const TripOwnerRef({required this.name, this.username, this.photoUrl});

  final String name;
  final String? username;
  final String? photoUrl;

  factory TripOwnerRef.fromJson(Map<String, dynamic> j) =>
      TripOwnerRef(name: BuddyJson.str(j['name']), username: BuddyJson.strOrNull(j['username']), photoUrl: BuddyJson.photo(j['photoUrl']));

  Map<String, dynamic> toJson() => {'name': name, 'username': username, 'photoUrl': photoUrl};
}

class InvitePreview {
  const InvitePreview({
    required this.memberId,
    this.tripId,
    required this.owner,
    required this.title,
    required this.legCities,
    this.startDate,
    this.endDate,
    required this.dayCount,
    required this.cityCount,
    required this.travellerCount,
    this.expiresAt,
    required this.alreadyMember,
  });

  final String memberId;
  final String? tripId;
  final TripOwnerRef owner;
  final String title;
  final List<String> legCities;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
  final int cityCount;
  final int travellerCount;
  final DateTime? expiresAt;
  final bool alreadyMember;

  factory InvitePreview.fromJson(Map<String, dynamic> j) => InvitePreview(
        memberId: BuddyJson.str(j['memberId']),
        tripId: BuddyJson.strOrNull(j['tripId']),
        owner: TripOwnerRef.fromJson(BuddyJson.map(j['owner'])),
        title: BuddyJson.str(j['title']),
        legCities: BuddyJson.strings(j['legCities']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        dayCount: BuddyJson.integer(j['dayCount']),
        cityCount: BuddyJson.integer(j['cityCount']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        expiresAt: BuddyJson.time(j['expiresAt']),
        alreadyMember: BuddyJson.boolean(j['alreadyMember']),
      );
}

class InviteEnded {
  const InviteEnded({required this.reason, this.title, this.ownerName});

  final String reason;
  final String? title;
  final String? ownerName;

  factory InviteEnded.fromJson(Map<String, dynamic> j) =>
      InviteEnded(reason: BuddyJson.str(j['reason'], 'Unknown'), title: BuddyJson.strOrNull(j['title']), ownerName: BuddyJson.strOrNull(j['ownerName']));
}

class ViewerLeg {
  const ViewerLeg({
    required this.index,
    required this.cityName,
    this.cityKey,
    this.latitude,
    this.longitude,
    required this.firstDay,
    required this.lastDay,
    required this.nights,
    required this.spotCount,
  });

  final int index;
  final String cityName;
  final int? cityKey;
  final double? latitude;
  final double? longitude;
  final int firstDay;
  final int lastDay;
  final int nights;
  final int spotCount;

  factory ViewerLeg.fromJson(Map<String, dynamic> j) => ViewerLeg(
        index: BuddyJson.integer(j['index']),
        cityName: BuddyJson.str(j['cityName']),
        cityKey: BuddyJson.intOrNull(j['cityKey']),
        latitude: BuddyJson.doubleOrNull(j['latitude']),
        longitude: BuddyJson.doubleOrNull(j['longitude']),
        firstDay: BuddyJson.integer(j['firstDay'], 1),
        lastDay: BuddyJson.integer(j['lastDay'], 1),
        nights: BuddyJson.integer(j['nights']),
        spotCount: BuddyJson.integer(j['spotCount']),
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'cityName': cityName,
        'cityKey': cityKey,
        'latitude': latitude,
        'longitude': longitude,
        'firstDay': firstDay,
        'lastDay': lastDay,
        'nights': nights,
        'spotCount': spotCount,
      };
}

class ViewerSpot {
  const ViewerSpot({
    required this.id,
    required this.name,
    this.category,
    this.latitude,
    this.longitude,
    required this.visitMinutes,
    this.startTime,
    this.travelMinutesToNext,
  });

  final String id;
  final String name;
  final String? category;
  final double? latitude;
  final double? longitude;
  final int visitMinutes;
  final String? startTime;
  final int? travelMinutesToNext;

  factory ViewerSpot.fromJson(Map<String, dynamic> j) => ViewerSpot(
        id: BuddyJson.str(j['id']),
        name: BuddyJson.str(j['name']),
        category: BuddyJson.strOrNull(j['category']),
        latitude: BuddyJson.doubleOrNull(j['latitude']),
        longitude: BuddyJson.doubleOrNull(j['longitude']),
        visitMinutes: BuddyJson.integer(j['visitMinutes']),
        startTime: BuddyJson.strOrNull(j['startTime']),
        travelMinutesToNext: BuddyJson.intOrNull(j['travelMinutesToNext']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'visitMinutes': visitMinutes,
        'startTime': startTime,
        'travelMinutesToNext': travelMinutesToNext,
      };
}

class ViewerDay {
  const ViewerDay({
    required this.day,
    required this.leg,
    required this.restDay,
    this.date,
    required this.totalMinutes,
    required this.placeCount,
    this.routeGeoJson,
    required this.spots,
  });

  final int day;
  final int leg;
  final bool restDay;
  final DateTime? date;
  final int totalMinutes;
  final int placeCount;
  final Object? routeGeoJson;
  final List<ViewerSpot> spots;

  factory ViewerDay.fromJson(Map<String, dynamic> j) => ViewerDay(
        day: BuddyJson.integer(j['day'], 1),
        leg: BuddyJson.integer(j['leg'], 1),
        restDay: BuddyJson.boolean(j['restDay']),
        date: BuddyJson.date(j['date']),
        totalMinutes: BuddyJson.integer(j['totalMinutes']),
        placeCount: BuddyJson.integer(j['placeCount']),
        routeGeoJson: j['routeGeoJson'],
        spots: BuddyJson.list(j['spots'], ViewerSpot.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'leg': leg,
        'restDay': restDay,
        'date': BuddyJson.dateText(date),
        'totalMinutes': totalMinutes,
        'placeCount': placeCount,
        'routeGeoJson': routeGeoJson,
        'spots': [for (final s in spots) s.toJson()],
      };
}

abstract final class ViewerBookingState {
  static const String notAdded = 'NotAdded';
  static const String arranging = 'Arranging';
  static const String booked = 'Booked';
  static const String completed = 'Completed';
}

class ViewerStayItem {
  const ViewerStayItem({required this.leg, required this.cityName, required this.stayName, required this.nights, this.checkIn, this.checkOut});

  final int leg;
  final String cityName;
  final String stayName;
  final int nights;
  final DateTime? checkIn;
  final DateTime? checkOut;

  factory ViewerStayItem.fromJson(Map<String, dynamic> j) => ViewerStayItem(
        leg: BuddyJson.integer(j['leg'], 1),
        cityName: BuddyJson.str(j['cityName']),
        stayName: BuddyJson.str(j['stayName']),
        nights: BuddyJson.integer(j['nights']),
        checkIn: BuddyJson.date(j['checkIn']),
        checkOut: BuddyJson.date(j['checkOut']),
      );

  Map<String, dynamic> toJson() => {
        'leg': leg,
        'cityName': cityName,
        'stayName': stayName,
        'nights': nights,
        'checkIn': BuddyJson.dateText(checkIn),
        'checkOut': BuddyJson.dateText(checkOut),
      };
}

class ViewerStay {
  const ViewerStay({required this.state, required this.items});

  final String state;
  final List<ViewerStayItem> items;

  factory ViewerStay.fromJson(Map<String, dynamic> j) =>
      ViewerStay(state: BuddyJson.str(j['state'], ViewerBookingState.notAdded), items: BuddyJson.list(j['items'], ViewerStayItem.fromJson));

  Map<String, dynamic> toJson() => {'state': state, 'items': [for (final i in items) i.toJson()]};
}

class ViewerTaxi {
  const ViewerTaxi({required this.state, this.vehicleType, this.driverFirstName, this.pickupDate, this.pickupTime});

  final String state;
  final String? vehicleType;
  final String? driverFirstName;
  final DateTime? pickupDate;
  final String? pickupTime;

  factory ViewerTaxi.fromJson(Map<String, dynamic> j) => ViewerTaxi(
        state: BuddyJson.str(j['state'], ViewerBookingState.notAdded),
        vehicleType: BuddyJson.strOrNull(j['vehicleType']),
        driverFirstName: BuddyJson.strOrNull(j['driverFirstName']),
        pickupDate: BuddyJson.date(j['pickupDate']),
        pickupTime: BuddyJson.strOrNull(j['pickupTime']),
      );

  Map<String, dynamic> toJson() => {
        'state': state,
        'vehicleType': vehicleType,
        'driverFirstName': driverFirstName,
        'pickupDate': BuddyJson.dateText(pickupDate),
        'pickupTime': pickupTime,
      };
}

class ViewerTrip {
  const ViewerTrip({
    required this.tripId,
    required this.title,
    required this.status,
    required this.role,
    required this.owner,
    required this.legCities,
    required this.dayCount,
    required this.spotCount,
    this.startDate,
    this.endDate,
    required this.travellerCount,
    required this.firstTravellers,
    required this.legs,
    required this.days,
    required this.stay,
    required this.taxi,
    required this.progressPercent,
    required this.expenses,
    this.updatedAt,
    this.detailsLocked = false,
  });

  final String tripId;
  final String title;
  final String status;
  final String role;
  final bool detailsLocked;
  final TripOwnerRef owner;
  final List<String> legCities;
  final int dayCount;
  final int spotCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travellerCount;
  final List<TravellerDot> firstTravellers;
  final List<ViewerLeg> legs;
  final List<ViewerDay> days;
  final ViewerStay stay;
  final ViewerTaxi taxi;
  final int progressPercent;
  final TripExpenseCard expenses;
  final DateTime? updatedAt;

  bool get isOwner => role == TripRoles.owner;

  factory ViewerTrip.fromJson(Map<String, dynamic> j) => ViewerTrip(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        status: BuddyJson.str(j['status']),
        role: BuddyJson.str(j['role'], TripRoles.viewer),
        owner: TripOwnerRef.fromJson(BuddyJson.map(j['owner'])),
        legCities: BuddyJson.strings(j['legCities']),
        dayCount: BuddyJson.integer(j['dayCount']),
        spotCount: BuddyJson.integer(j['spotCount']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        firstTravellers: BuddyJson.list(j['firstTravellers'], TravellerDot.fromJson),
        legs: BuddyJson.list(j['legs'], ViewerLeg.fromJson),
        days: BuddyJson.list(j['days'], ViewerDay.fromJson),
        stay: ViewerStay.fromJson(BuddyJson.map(j['stay'])),
        taxi: ViewerTaxi.fromJson(BuddyJson.map(j['taxi'])),
        progressPercent: BuddyJson.integer(j['progressPercent']),
        expenses: TripExpenseCard.fromJson(BuddyJson.map(j['expenses'])),
        updatedAt: BuddyJson.time(j['updatedAt']),
        detailsLocked: BuddyJson.boolean(j['detailsLocked']),
      );

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'title': title,
        'status': status,
        'role': role,
        'owner': owner.toJson(),
        'legCities': legCities,
        'dayCount': dayCount,
        'spotCount': spotCount,
        'startDate': BuddyJson.dateText(startDate),
        'endDate': BuddyJson.dateText(endDate),
        'travellerCount': travellerCount,
        'firstTravellers': [for (final t in firstTravellers) t.toJson()],
        'legs': [for (final l in legs) l.toJson()],
        'days': [for (final d in days) d.toJson()],
        'stay': stay.toJson(),
        'taxi': taxi.toJson(),
        'progressPercent': progressPercent,
        'expenses': expenses.toJson(),
        'updatedAt': BuddyJson.timeText(updatedAt),
        'detailsLocked': detailsLocked,
      };
}

class ViewerTripResponse {
  const ViewerTripResponse({required this.notModified, this.etag, this.trip});

  final bool notModified;
  final String? etag;
  final ViewerTrip? trip;
}

class NotOnTripInfo {
  const NotOnTripInfo({required this.hasShare, this.title, this.ownerName, this.startDate, this.endDate, this.endedHow});

  final bool hasShare;
  final String? title;
  final String? ownerName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? endedHow;

  bool get removed => endedHow == 'Removed';

  factory NotOnTripInfo.fromJson(Map<String, dynamic> j) => NotOnTripInfo(
        hasShare: BuddyJson.boolean(j['hasShare']),
        title: BuddyJson.strOrNull(j['title']),
        ownerName: BuddyJson.strOrNull(j['ownerName']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        endedHow: BuddyJson.strOrNull(j['endedHow']),
      );
}

class SharedTripCard {
  const SharedTripCard({
    required this.tripId,
    required this.title,
    required this.role,
    required this.ownerName,
    required this.legCities,
    required this.dayCount,
    required this.spotCount,
    this.startDate,
    this.endDate,
    required this.travellerCount,
    required this.progressPercent,
    required this.stayState,
    required this.taxiState,
    required this.planState,
    this.joinedAt,
    required this.expenses,
  });

  final String tripId;
  final String title;
  final String role;
  final String ownerName;
  final List<String> legCities;
  final int dayCount;
  final int spotCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travellerCount;
  final int progressPercent;
  final String stayState;
  final String taxiState;
  final String planState;
  final DateTime? joinedAt;
  final TripExpenseCard expenses;

  factory SharedTripCard.fromJson(Map<String, dynamic> j) => SharedTripCard(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        role: BuddyJson.str(j['role'], TripRoles.viewer),
        ownerName: BuddyJson.str(j['ownerName']),
        legCities: BuddyJson.strings(j['legCities']),
        dayCount: BuddyJson.integer(j['dayCount']),
        spotCount: BuddyJson.integer(j['spotCount']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        travellerCount: BuddyJson.integer(j['travellerCount'], 1),
        progressPercent: BuddyJson.integer(j['progressPercent']),
        stayState: BuddyJson.str(j['stayState'], 'notAdded'),
        taxiState: BuddyJson.str(j['taxiState'], 'notAdded'),
        planState: BuddyJson.str(j['planState'], 'Saved'),
        joinedAt: BuddyJson.time(j['joinedAt']),
        expenses: TripExpenseCard.fromJson(BuddyJson.map(j['expenses'])),
      );
}

class SharedInvite {
  const SharedInvite({
    required this.memberId,
    required this.title,
    required this.ownerName,
    this.startDate,
    this.endDate,
    required this.dayCount,
    required this.cityCount,
    this.expiresAt,
  });

  final String memberId;
  final String title;
  final String ownerName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
  final int cityCount;
  final DateTime? expiresAt;

  factory SharedInvite.fromJson(Map<String, dynamic> j) => SharedInvite(
        memberId: BuddyJson.str(j['memberId']),
        title: BuddyJson.str(j['title']),
        ownerName: BuddyJson.str(j['ownerName']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        dayCount: BuddyJson.integer(j['dayCount']),
        cityCount: BuddyJson.integer(j['cityCount']),
        expiresAt: BuddyJson.time(j['expiresAt']),
      );
}

class FormerTripCard {
  const FormerTripCard({
    required this.tripId,
    required this.title,
    required this.ownerName,
    this.startDate,
    this.endDate,
    required this.endedHow,
    required this.myNet,
    this.owesToName,
    required this.sharedCount,
  });

  final String tripId;
  final String title;
  final String ownerName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String endedHow;
  final int myNet;
  final String? owesToName;
  final int sharedCount;

  factory FormerTripCard.fromJson(Map<String, dynamic> j) => FormerTripCard(
        tripId: BuddyJson.str(j['tripId']),
        title: BuddyJson.str(j['title']),
        ownerName: BuddyJson.str(j['ownerName']),
        startDate: BuddyJson.date(j['startDate']),
        endDate: BuddyJson.date(j['endDate']),
        endedHow: BuddyJson.str(j['endedHow'], 'Left'),
        myNet: BuddyJson.integer(j['myNet']),
        owesToName: BuddyJson.strOrNull(j['owesToName']),
        sharedCount: BuddyJson.integer(j['sharedCount']),
      );
}

class SharedTripCounts {
  const SharedTripCounts({this.upcoming = 0, this.past = 0});

  final int upcoming;
  final int past;

  factory SharedTripCounts.fromJson(Map<String, dynamic> j) =>
      SharedTripCounts(upcoming: BuddyJson.integer(j['upcoming']), past: BuddyJson.integer(j['past']));
}

class SharedTrips {
  const SharedTrips({required this.items, required this.invites, required this.former, this.nextCursor, required this.counts});

  final List<SharedTripCard> items;
  final List<SharedInvite> invites;
  final List<FormerTripCard> former;
  final String? nextCursor;
  final SharedTripCounts counts;

  bool get isEmpty => items.isEmpty && invites.isEmpty && former.isEmpty;

  factory SharedTrips.fromJson(Map<String, dynamic> j) => SharedTrips(
        items: BuddyJson.list(j['items'], SharedTripCard.fromJson),
        invites: BuddyJson.list(j['invites'], SharedInvite.fromJson),
        former: BuddyJson.list(j['former'], FormerTripCard.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
        counts: SharedTripCounts.fromJson(BuddyJson.map(j['counts'])),
      );
}

class LeaveResult {
  const LeaveResult({required this.status, required this.hasShare});

  final String status;
  final bool hasShare;

  factory LeaveResult.fromJson(Map<String, dynamic> j) =>
      LeaveResult(status: BuddyJson.str(j['status']), hasShare: BuddyJson.boolean(j['hasShare']));
}
