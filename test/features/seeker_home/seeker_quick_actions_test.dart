import 'package:bakhli/features/seeker_home/seeker_quick_actions.dart';
import 'package:bakhli/features/seeker_home/strings/seeker_home_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FX-25 Trips module off: no Plan a trip and no My trips tiles', () {
    final on = SeekerQuickActions.defaults(tripsOn: true).map((a) => a.title).toList();
    final off = SeekerQuickActions.defaults(tripsOn: false).map((a) => a.title).toList();
    expect(on, containsAll([SeekerHomeStrings.tilePlanTitle, SeekerHomeStrings.tileTripsTitle]));
    expect(off, isNot(contains(SeekerHomeStrings.tilePlanTitle)));
    expect(off, isNot(contains(SeekerHomeStrings.tileTripsTitle)));
    expect(off, [SeekerHomeStrings.tileBuddyTitle]);
  });

  test('Bug 5: no Add expense tile on Home quick actions', () {
    final on = SeekerQuickActions.defaults(tripsOn: true).map((a) => a.title).toList();
    expect(on, [SeekerHomeStrings.tilePlanTitle, SeekerHomeStrings.tileTripsTitle, SeekerHomeStrings.tileBuddyTitle]);
    expect(on, isNot(contains('Add expense')));
  });

  test('owner 2026-11-27: tile text and icon 5% smaller', () {
    expect(SeekerQuickActions.tileContentScale, 0.95);
  });

  test('no traveller features: no quick actions at all', () {
    expect(SeekerQuickActions.defaults(tripsOn: false, buddyOn: false), isEmpty);
  });
}

