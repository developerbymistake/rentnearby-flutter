import '../../../design/design.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import 'stay_gate_strings_calendar.dart';

abstract final class StayGateStrings {
  static const free = OwnerSharedStrings.free;
  static const plus = OwnerSharedStrings.plus;

  static String photosCount(int n) => n == 1 ? '1 photo' : '$n photos';
  static String roomsCount(int n) => n == 1 ? '1 room type' : '$n room types';

  static String photoTitle(int free) => 'Free plan allows ${photosCount(free)}';
  static String photoBody(int plus) => 'Plus stays can show ${photosCount(plus)}.';
  static String roomTitle(int free) => '${roomsCount(free)} on Free';
  static String roomBody(int plus) => 'Get Plus to list up to $plus.';
  static String roomBanner(int free, int plus) => '${roomsCount(free)} on Free. Plus lists up to $plus.';
  static const photoHint = 'Clear day-time photos help guests choose.';
  static const addPhoto = 'Add photo';
  static const addRoomType = 'Add room type';
  static const roomsPage = 'Rooms and prices';
  static String roomsUsed(int n, int max) => '$n of $max room types used';
  static String roomInactive(int free) => 'Inactive: the Free plan allows ${roomsCount(free)}.';
  static String photoInactive(int free) => 'Inactive: the Free plan allows ${photosCount(free)}.';
  static String specialStrip(int free, int plus) => 'Free plan: ${StayGateStringsCalendar.specialPrices(free)}. Plus gives up to $plus.';
  static String specialInactive(int free) => 'Inactive: the Free plan allows ${StayGateStringsCalendar.specialPrices(free)}.';

  static GateSpec photoGate() {
    final free = PlanGate.limit(PlanKey.photos);
    final plus = PlanKeys.plusSeed[PlanKey.photos] ?? free;
    return GateSpec(
      id: 'G5',
      title: photoTitle(free),
      body: photoBody(plus),
      taxi: false,
      art: ListingArt.framedPicture,
      rows: [GateRow(label: OwnerSharedStrings.free, value: photosCount(free)), GateRow(label: OwnerSharedStrings.plus, value: photosCount(plus), highlight: true)],
    );
  }

  static GateSpec roomGate() {
    final free = PlanGate.limit(PlanKey.roomTypes);
    final plus = PlanKeys.plusSeed[PlanKey.roomTypes] ?? free;
    return GateSpec(
      id: 'G6',
      title: roomTitle(free),
      body: roomBody(plus),
      taxi: false,
      art: ListingArt.bed,
      rows: [GateRow(label: OwnerSharedStrings.free, value: roomsCount(free)), GateRow(label: OwnerSharedStrings.plus, value: roomsCount(plus), highlight: true)],
    );
  }

  static GateSpec fromRefusal(String key, int limit) => key == PlanKey.photos.wire ? photoGate() : roomGate();
}
