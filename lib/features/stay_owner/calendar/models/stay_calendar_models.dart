import '../../../owner_core/calendar/models/calendar_models.dart';
import '../../../owner_core/json/owner_dates.dart';
import '../../../owner_core/json/owner_json.dart';

abstract final class StayCalendarErrors {
  static const entryEnded = 'EntryEnded';
}

class StayBlockWrite {
  const StayBlockWrite({this.block, this.confirmedInside = 0, this.openEnquiriesInside = 0, this.meters = const []});

  final CalendarBlock? block;
  final int confirmedInside;
  final int openEnquiriesInside;
  final List<Meter> meters;

  factory StayBlockWrite.fromJson(Map<String, dynamic> j) {
    final raw = OwnerJson.mapOrNull(j['block']);
    final b = raw == null ? null : CalendarBlock.fromJson(raw);
    return StayBlockWrite(
      block: b != null && b.valid ? b : null,
      confirmedInside: OwnerJson.integer(j['confirmedInside']),
      openEnquiriesInside: OwnerJson.integer(j['openEnquiriesInside']),
      meters: Meter.listOf(j['meters']),
    );
  }
}

class StayBlockList {
  const StayBlockList({this.items = const [], this.meters = const []});

  final List<CalendarBlock> items;
  final List<Meter> meters;

  factory StayBlockList.fromJson(Map<String, dynamic> j) =>
      StayBlockList(items: CalendarBlock.listOf(j['items']), meters: Meter.listOf(j['meters']));
}

class StayBlockDraft {
  const StayBlockDraft({required this.id, required this.dateFrom, required this.dateTo, this.reason, this.version});

  final String id;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? reason;
  final int? version;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateFrom': OwnerDates.dayText(dateFrom),
        'dateTo': OwnerDates.dayText(dateTo),
        'reason': ?reason,
        'version': ?version,
      };
}

class StayPriceRoom {
  const StayPriceRoom({required this.id, required this.roomName, required this.basePrice});

  final String id;
  final String roomName;
  final int basePrice;

  bool get valid => id.isNotEmpty && roomName.isNotEmpty && basePrice > 0;

  String get shortName {
    const suffix = ' Room';
    return roomName.endsWith(suffix) && roomName.length > suffix.length ? roomName.substring(0, roomName.length - suffix.length) : roomName;
  }

  factory StayPriceRoom.fromJson(Map<String, dynamic> j) => StayPriceRoom(
        id: OwnerJson.str(j['id']),
        roomName: OwnerJson.str(j['roomName']),
        basePrice: OwnerJson.integer(j['basePrice']),
      );

  static List<StayPriceRoom> listOf(Object? raw) => OwnerJson.list(raw, StayPriceRoom.fromJson).where((r) => r.valid).toList();
}

class StaySpecialPricesPage {
  const StaySpecialPricesPage({
    this.items = const [],
    this.meters = const [],
    this.savesLeftToday,
    this.rooms = const [],
    this.paymentEnabled = false,
    this.stateName,
    this.raw = const {},
  });

  final List<SpecialPriceBand> items;
  final List<Meter> meters;
  final int? savesLeftToday;
  final List<StayPriceRoom> rooms;
  final bool paymentEnabled;
  final String? stateName;
  final Map<String, dynamic> raw;

  factory StaySpecialPricesPage.fromJson(Map<String, dynamic> j) {
    final items = SpecialPriceBand.listOf(j['items'])..sort(_order);
    return StaySpecialPricesPage(
      items: items,
      meters: Meter.listOf(j['meters']),
      savesLeftToday: OwnerJson.intOrNull(j['savesLeftToday']),
      rooms: StayPriceRoom.listOf(j['rooms']),
      paymentEnabled: OwnerJson.boolean(j['paymentEnabled']),
      stateName: OwnerJson.strOrNull(j['stateName']),
      raw: j,
    );
  }

  static int _order(SpecialPriceBand a, SpecialPriceBand b) {
    final fa = a.dateFrom;
    final fb = b.dateFrom;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return a.id.compareTo(b.id);
  }
}

class StaySpecialPriceDraft {
  const StaySpecialPriceDraft({
    required this.id,
    required this.dateFrom,
    required this.dateTo,
    required this.lower,
    required this.percent,
    this.festivalDateId,
    this.version,
  });

  final String id;
  final DateTime dateFrom;
  final DateTime dateTo;
  final bool lower;
  final int percent;
  final String? festivalDateId;
  final int? version;

  int get nights => OwnerDates.daysBetween(dateFrom, dateTo) + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateFrom': OwnerDates.dayText(dateFrom),
        'dateTo': OwnerDates.dayText(dateTo),
        'direction': lower ? 'Lower' : 'Higher',
        'percent': percent,
        'festivalDateId': ?festivalDateId,
        'version': ?version,
      };
}

class SpecialPriceOverlapInfo {
  const SpecialPriceOverlapInfo({required this.id, required this.label, this.dateFrom, this.dateTo});

  final String id;
  final String label;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  static SpecialPriceOverlapInfo? maybe(Map<String, dynamic> j) {
    final id = OwnerJson.str(j['id']);
    if (id.isEmpty) return null;
    return SpecialPriceOverlapInfo(
      id: id,
      label: OwnerJson.str(j['label']),
      dateFrom: OwnerDates.day(j['dateFrom']),
      dateTo: OwnerDates.day(j['dateTo']),
    );
  }
}

class PlanVisiblePhoto {
  const PlanVisiblePhoto({required this.id, this.url = '', this.order = 0});

  final String id;
  final String url;
  final int order;

  factory PlanVisiblePhoto.fromJson(Map<String, dynamic> j) =>
      PlanVisiblePhoto(id: OwnerJson.str(j['id']), url: OwnerJson.str(j['url']), order: OwnerJson.integer(j['photoOrder']));

  static List<PlanVisiblePhoto> listOf(Object? raw) => OwnerJson.list(raw, PlanVisiblePhoto.fromJson).where((p) => p.id.isNotEmpty).toList();
}

class PlanVisibleRoom {
  const PlanVisibleRoom({required this.id, this.name = '', this.price = 0, this.index = 0});

  final String id;
  final String name;
  final int price;
  final int index;

  factory PlanVisibleRoom.fromJson(Map<String, dynamic> j) => PlanVisibleRoom(
        id: OwnerJson.str(j['id']),
        name: OwnerJson.str(j['roomName']),
        price: OwnerJson.integer(j['pricePerNight']),
        index: OwnerJson.integer(j['roomIndex']),
      );

  static List<PlanVisibleRoom> listOf(Object? raw) => OwnerJson.list(raw, PlanVisibleRoom.fromJson).where((r) => r.id.isNotEmpty).toList();
}

class StayPlanVisibleState {
  const StayPlanVisibleState({
    this.photos = const [],
    this.rooms = const [],
    this.visiblePhotoIds = const [],
    this.visibleRoomIds = const [],
    this.hiddenPhotoIds = const [],
    this.hiddenRoomIds = const [],
    this.photoLimit = 2,
    this.roomLimit = 2,
    this.limitsFromServer = false,
  });

  final List<PlanVisiblePhoto> photos;
  final List<PlanVisibleRoom> rooms;
  final List<String> visiblePhotoIds;
  final List<String> visibleRoomIds;
  final List<String> hiddenPhotoIds;
  final List<String> hiddenRoomIds;
  final int photoLimit;
  final int roomLimit;
  final bool limitsFromServer;

  int get photoTarget => photos.length < photoLimit ? photos.length : photoLimit;
  int get roomTarget => rooms.length < roomLimit ? rooms.length : roomLimit;

  // Mirror of the server's choice rule: stored hidden rows, or rows over the plan limit.
  bool get somethingHidden =>
      hiddenPhotoIds.isNotEmpty || hiddenRoomIds.isNotEmpty || photos.length > photoLimit || rooms.length > roomLimit;

  factory StayPlanVisibleState.fromJson(Map<String, dynamic> j, {required int photoLimit, required int roomLimit}) {
    final shownPhotos = PlanVisiblePhoto.listOf(j['photos'])..sort((a, b) => a.order.compareTo(b.order));
    final hiddenPhotos = PlanVisiblePhoto.listOf(j['hiddenPhotos'])..sort((a, b) => a.order.compareTo(b.order));
    final shownRooms = PlanVisibleRoom.listOf(j['rooms'])..sort((a, b) => a.index.compareTo(b.index));
    final hiddenRooms = PlanVisibleRoom.listOf(j['hiddenRooms'])..sort((a, b) => a.index.compareTo(b.index));
    final meters = Meter.listOf(j['meters']);
    final pm = Meter.find(meters, 'Photos');
    final rm = Meter.find(meters, 'RoomTypes');
    return StayPlanVisibleState(
      photos: [...shownPhotos, ...hiddenPhotos].take(8).toList(),
      rooms: [...shownRooms, ...hiddenRooms],
      visiblePhotoIds: [for (final p in shownPhotos) p.id],
      visibleRoomIds: [for (final r in shownRooms) r.id],
      hiddenPhotoIds: [for (final p in hiddenPhotos) p.id],
      hiddenRoomIds: [for (final r in hiddenRooms) r.id],
      photoLimit: pm != null && pm.limit > 0 ? pm.limit : photoLimit,
      roomLimit: rm != null && rm.limit > 0 ? rm.limit : roomLimit,
      limitsFromServer: (pm != null && pm.limit > 0) || (rm != null && rm.limit > 0),
    );
  }
}
