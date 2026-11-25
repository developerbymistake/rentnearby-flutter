import '../../../design/design.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiGateStringsCalendar {
  static String title(int limit) => 'You have $limit active entries';
  static String body(int free, int plus) => 'Free keeps $free trips you add yourself. Plus keeps $plus.';
  static String freeRow(int free) => '$free trips you add';
  static String plusRow(int plus) => '$plus trips, reminder, month summary';
  static String entryInactive(int free) => 'Inactive on Free. Free keeps $free trips you add. Delete it or get Plus.';
  static String plusFull(int n) => 'You can keep up to $n trips you add.';
  static const tip ='A slot frees up when a trip date passes, or delete one you do not need.';

  static int get freeEntries => PlanGate.limit(PlanKey.calendarEntries);
  static int get plusEntries => PlanKeys.plusSeed[PlanKey.calendarEntries] ?? freeEntries;

  static GateSpec g10({int? limit}) {
    final free = limit ?? freeEntries;
    final plus = plusEntries;
    return GateSpec(
      id: 'G10',
      title: title(free),
      body: body(free, plus),
      taxi: true,
      art: ListingArt.calendar,
      rows: [
        GateRow(label: OwnerSharedStrings.free, value: freeRow(free)),
        GateRow(label: OwnerSharedStrings.plus, value: plusRow(plus), highlight: true),
      ],
      tip: tip,
    );
  }

  static GateSpec fromRefusal(String key, int limit) => g10(limit: limit);
}
