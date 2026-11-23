import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/tour_registry.dart';
import 'package:bakhli/navigation/tour_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry has one entry: Trips tab, seeker shell, key tour_trips_seen_v1', () {
    expect(tourRegistry.keys, [AppTabs.trips]);
    final tour = tourRegistry[AppTabs.trips]!;
    expect(tour.tabIndex, AppTabs.trips);
    expect(tour.shell, ShellKind.seeker);
    expect(tour.storageKey, 'tour_trips_seen_v1');
    expect(tour.label, 'Trips Tour');
  });

  test('exactly two steps: Where to next, then Find a buddy', () {
    final steps = tourRegistry[AppTabs.trips]!.steps;
    expect(steps.length, 2);
    expect(steps[0].key, TourKeys.tripsWhereTile);
    expect(steps[0].title, 'Where to next?');
    expect(steps[0].body, 'Tap here to pick a city and plan your journey.');
    expect(steps[1].key, TourKeys.tripsBuddyTile);
    expect(steps[1].title, 'Find a buddy');
    expect(steps[1].body, 'Tap here to find people going your way.');
  });

  test('tourForTab is null for every other tab and for owner shells', () {
    for (final tab in [AppTabs.home, AppTabs.stays, AppTabs.taxi, AppTabs.profile]) {
      for (final shell in ShellKind.values) {
        expect(tourForTab(tab, shell), isNull, reason: 'tab $tab $shell');
      }
    }
    expect(tourForTab(AppTabs.trips, ShellKind.stayOwner), isNull);
    expect(tourForTab(AppTabs.trips, ShellKind.taxiDriver), isNull);
    expect(tourForTab(AppTabs.trips, ShellKind.seeker), same(tourRegistry[AppTabs.trips]));
  });
}
