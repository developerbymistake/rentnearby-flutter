import '../../../design/design.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StayGateStringsCalendar {
  static String bookingsYouAdd(int n) => n == 1 ? '1 booking you add' : '$n bookings you add';
  static String blockedRanges(int n) => n == 1 ? '1 blocked range' : '$n blocked ranges';
  static String specialPrices(int n) => n == 1 ? '1 special price' : '$n special prices';

  static String g10Title(int used) => 'You have $used active entries';
  static String g10Body(int free, int plus) => 'Free keeps $free bookings you add yourself. Plus keeps $plus.';
  static String entryInactive(int free) => 'Inactive: the Free plan keeps ${bookingsYouAdd(free)}.';
  static const g10Tip = 'A slot frees up when a booking date passes, or delete one you do not need.';

  static String g11Title(int free) => 'Free allows ${blockedRanges(free)}';
  static String g11Body(int plus) => 'Plus lets you block up to $plus. You can change or remove your current block at any time.';

  static String g12Title(int free) => '${specialPrices(free)} on Free';
  static String g12Body(int plus, DateTime? endsOn) {
    final base = 'Plus keeps $plus at a time.';
    if (endsOn == null) return base;
    return '$base Your current one ends on ${OwnerSharedStrings.dayMonth(endsOn)}. You can change or remove it now.';
  }

  static int _plus(PlanKey key) => PlanKeys.plusSeed[key] ?? PlanGate.limit(key);

  static GateSpec g10({int? used}) {
    final free = PlanGate.limit(PlanKey.calendarEntries);
    final plus = _plus(PlanKey.calendarEntries);
    return GateSpec(
      id: 'G10',
      title: g10Title(used ?? free),
      body: g10Body(free, plus),
      taxi: false,
      art: ListingArt.calendar,
      tip: g10Tip,
      rows: [
        GateRow(label: OwnerSharedStrings.free, value: bookingsYouAdd(free)),
        GateRow(label: OwnerSharedStrings.plus, value: bookingsYouAdd(plus), highlight: true),
      ],
    );
  }

  static GateSpec g11() {
    final free = PlanGate.limit(PlanKey.blockedRanges);
    final plus = _plus(PlanKey.blockedRanges);
    return GateSpec(
      id: 'G11',
      title: g11Title(free),
      body: g11Body(plus),
      taxi: false,
      art: ListingArt.locked,
      rows: [
        GateRow(label: OwnerSharedStrings.free, value: blockedRanges(free)),
        GateRow(label: OwnerSharedStrings.plus, value: blockedRanges(plus), highlight: true),
      ],
    );
  }

  static GateSpec g12({DateTime? endsOn}) {
    final free = PlanGate.limit(PlanKey.specialPrices);
    final plus = _plus(PlanKey.specialPrices);
    return GateSpec(
      id: 'G12',
      title: g12Title(free),
      body: g12Body(plus, endsOn),
      taxi: false,
      art: ListingArt.diyaLamp,
      rows: [
        GateRow(label: OwnerSharedStrings.free, value: specialPrices(free)),
        GateRow(label: OwnerSharedStrings.plus, value: specialPrices(plus), highlight: true),
      ],
    );
  }

  static GateSpec fromRefusal(String key, int limit) {
    if (key == PlanKey.blockedRanges.wire) return g11();
    if (key == PlanKey.specialPrices.wire) return g12();
    return g10();
  }
}
