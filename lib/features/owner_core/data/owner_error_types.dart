import '../json/owner_json.dart';
import 'owner_result.dart';

abstract final class OwnerErrorTypes {
  static const listingNotFound = 'ListingNotFound';
  static const planPhotoLimit = 'PlanPhotoLimit';
  static const planRoomTypeLimit = 'PlanRoomTypeLimit';
  static const taxiRouteLimit = 'TaxiRouteLimit';
  static const stayJobLimit = 'StayJobLimit';
  static const calendarEntryLimit = 'CalendarEntryLimit';
  static const calendarOutsideWindow = 'CalendarOutsideWindow';
  static const entryNotManual = 'EntryNotManual';
  static const blockedRangeLimit = 'BlockedRangeLimit';
  static const blockedRangeOverlap = 'BlockedRangeOverlap';
  static const blockedRangeNeedsConfirm = 'BlockedRangeNeedsConfirm';
  static const blockedRangeInvalid = 'BlockedRangeInvalid';
  static const specialPriceLimit = 'SpecialPriceLimit';
  static const specialPriceOverlap = 'SpecialPriceOverlap';
  static const specialPriceSavesLimit = 'SpecialPriceSavesLimit';
  static const specialPriceInvalid = 'SpecialPriceInvalid';
  static const planVisibleLimit = 'PlanVisibleLimit';
  static const planVisibleInvalid = 'PlanVisibleInvalid';
  static const planVisibleNotNeeded = 'PlanVisibleNotNeeded';
  static const planFeatureLocked = 'PlanFeatureLocked';
  static const moneyNoteInvalid = 'MoneyNoteInvalid';
  static const phoneNotAllowed = 'PhoneNotAllowed';
  static const staleEdit = 'StaleEdit';
  static const idTaken = 'IdTaken';
  static const stayFullOnDates = 'StayFullOnDates';
  static const changeTouchesBlock = 'ChangeTouchesBlock';
  static const roomTypeDuplicate = 'RoomTypeDuplicate';
  static const stayNeedsPhoto = 'StayNeedsPhoto';
  static const stayEditGone = 'StayEditGone';
  static const stayEditChanged = 'StayEditChanged';
  static const planValueBelowFree = 'PlanValueBelowFree';
  static const announceTooSoon = 'AnnounceTooSoon';
  static const tabInactive = 'TabInactive';
  static const roleMismatch = 'RoleMismatch';
  static const planRowInactive = 'PlanRowInactive';
  static const dayOffBooked = 'DayOffBooked';
  static const dayOffPast = 'DayOffPast';
  static const dayOffReasonTooLong = 'DayOffReasonTooLong';
  static const dayIsOff = 'DayIsOff';

  static const Set<String> limitTypes = {
    planPhotoLimit,
    planRoomTypeLimit,
    taxiRouteLimit,
    stayJobLimit,
    calendarEntryLimit,
    blockedRangeLimit,
    specialPriceLimit,
  };

  static const Set<String> all = {
    listingNotFound, planPhotoLimit, planRoomTypeLimit, taxiRouteLimit, stayJobLimit, calendarEntryLimit,
    calendarOutsideWindow, entryNotManual, blockedRangeLimit, blockedRangeOverlap, blockedRangeNeedsConfirm,
    blockedRangeInvalid, specialPriceLimit, specialPriceOverlap, specialPriceSavesLimit, specialPriceInvalid,
    planVisibleLimit, planVisibleInvalid, planVisibleNotNeeded, planFeatureLocked, moneyNoteInvalid,
    phoneNotAllowed, staleEdit, idTaken, stayFullOnDates, changeTouchesBlock, roomTypeDuplicate, stayNeedsPhoto,
    stayEditGone, stayEditChanged, planValueBelowFree, announceTooSoon, dayOffBooked, dayOffPast, dayOffReasonTooLong,
    dayIsOff,
  };
}

typedef OwnerLimitInfo = ({String key, int limit, int used, bool canUpgrade});

abstract final class OwnerRefusal {
  static bool isType(OwnerRefused<dynamic> r, String type) => r.type == type;

  static OwnerLimitInfo? limit(OwnerRefused<dynamic> r) {
    final type = r.type;
    if (type == null || !OwnerErrorTypes.limitTypes.contains(type)) return null;
    final d = r.data;
    final key = OwnerJson.strOrNull(d['key']);
    final limit = OwnerJson.intOrNull(d['limit']);
    if (key == null || limit == null) return null;
    return (key: key, limit: limit, used: OwnerJson.integer(d['used']), canUpgrade: OwnerJson.boolean(d['canUpgrade']));
  }

  static String? lockedKey(OwnerRefused<dynamic> r) =>
      r.statusCode == 403 && r.type == OwnerErrorTypes.planFeatureLocked ? OwnerJson.strOrNull(r.data['key']) : null;

  static bool paused(OwnerRefused<dynamic> r) => r.statusCode == 403 && r.type == OwnerErrorTypes.tabInactive;

  static bool stale(OwnerRefused<dynamic> r) => r.type == OwnerErrorTypes.staleEdit;
}
