import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/home/owner_home_api.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_controller.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_grid.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_screen.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_days_off_list.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_avail_fixtures.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(seconds: 4));
  }
}

class _HomeApi implements OwnerHomeApi {
  _HomeApi(this.switchOn);

  final bool switchOn;

  @override
  Future<OwnerResult<OwnerHomeDto>> load() async => OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson({
        'today': '2026-11-26',
        'listing': {'id': 't1', 'status': 'Approved', 'everApproved': true, 'switchOn': switchOn},
      }));
}

List<Map<String, dynamic>> decemberOff() => [for (var d = 1; d <= 31; d++) dayRow('2026-12-${d.toString().padLeft(2, '0')}', d.isEven ? 'Wedding season trip to Almora with the whole family' : null)];

class _Host extends StatelessWidget {
  const _Host(this.controller);

  final TaxiAvailabilityController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => TaxiAvailabilityScreen(controller: controller))),
              child: const Text('open'),
            ),
          ),
        ),
      );
}

Finder _day(int n) => find.byWidgetPredicate((w) => w is TaxiAvailDayBox && w.cell.inMonth && w.cell.date.day == n);

void main() {
  setUpAll(() => initTestStorage('taxi_avail_screen'));
  tearDown(availTearDown);

  Future<AvailHarness> open(WidgetTester t, AvailFake fake, {plan = OwnerPlans.free, bool load = true, Size size = const Size(360, 900), double scale = 1.0}) async {
    final h = await t.runAsync(() => availSetUp(fake, plan: plan, load: load));
    await pumpPhone(t, TaxiAvailabilityScreen(controller: h!.controller), size: size, textScale: scale);
    await settle(t);
    return h;
  }

  group('sizes and rows', () {
    for (final size in ownerSizes) {
      for (final scale in ownerTextScales) {
        for (final rows in [0, 1, 31]) {
          testWidgets('$rows rows at ${ownerSizeLabel(size, scale)}', (t) async {
            final json = switch (rows) {
              0 => availJson(daysOff: const [], plus: true),
              1 => availJson(daysOff: [dayRow('2026-11-27', 'Family function in Almora')], plus: true),
              _ => availJson(daysOff: decemberOff(), plus: true),
            };
            await open(t, AvailFake(read: json), plan: OwnerPlans.plus, size: size, scale: scale);
            expect(t.takeException(), isNull);
            if (rows == 0) {
              await t.scrollUntilVisible(find.text('No days off.'), 300, scrollable: find.byType(Scrollable).first);
              expect(find.text('No days off.'), findsOneWidget);
              expect(find.text('Your days off'), findsNothing);
            } else {
              await t.scrollUntilVisible(find.text('Your days off'), 300, scrollable: find.byType(Scrollable).first);
              expect(find.text('Your days off'), findsOneWidget);
            }
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });

  group('page', () {
    testWidgets('header, legend, list and Save off until a change', (t) async {
      await open(t, AvailFake(read: availJson()));
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Tap the days you are not available'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Booked from app (locked)'), findsOneWidget);
      expect(find.text('Family function in Almora'), findsOneWidget);
      expect(find.text('No reason added'), findsOneWidget);
      expect(find.byType(TaxiDayOffRow), findsNWidgets(2));
      final save = t.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save'));
      expect(save.onPressed, isNull);
    });

    testWidgets('cell states: past has no tap, off is coral, booked gives the toast and no sheet', (t) async {
      await open(t, AvailFake(read: availJson()));
      final past = t.widget<TaxiAvailDayBox>(_day(20));
      expect(find.descendant(of: _day(20), matching: find.byType(InkWell)), findsNothing);
      expect(past.state.name, 'past');
      expect(t.widget<TaxiAvailDayBox>(_day(27)).state.name, 'off');
      expect(t.widget<TaxiAvailDayBox>(_day(28)).state.name, 'booked');
      expect(t.widget<TaxiAvailDayBox>(_day(26)).cell.isToday, isTrue);
      await t.tap(_day(28));
      await settle(t);
      expect(find.text('Not available this day'), findsNothing);
      expect(find.text('This day has a booking'), findsOneWidget);
      await drain(t);
    });

    testWidgets('Free: Plus pill and the locked arrow are shown', (t) async {
      await open(t, AvailFake(read: availJson()));
      expect(find.byKey(GateKeys.softArrow), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('Plus: the arrows walk the months', (t) async {
      await open(t, AvailFake(read: availJson(plus: true, daysOff: [dayRow('2026-12-05', 'Trip')])), plan: OwnerPlans.plus);
      expect(find.byKey(GateKeys.softArrow), findsNothing);
      await t.tap(find.bySemanticsLabel('Next month').first);
      await settle(t);
      expect(find.text('December 2026'), findsOneWidget);
      expect(t.widget<TaxiAvailDayBox>(_day(5)).state.name, 'off');
    });

    testWidgets('offline note when Available now is off; the page still works', (t) async {
      final h = await t.runAsync(() async {
        final h = await availSetUp(AvailFake(read: availJson()));
        final home = Get.put(TaxiDriverHomeController(api: _HomeApi(false), deniedProbe: () async => false, userId: () => 'user-a'));
        await home.reload();
        return h;
      });
      await pumpPhone(t, TaxiAvailabilityScreen(controller: h!.controller));
      await settle(t);
      expect(find.text('You are offline. Taxi is hidden on every day. Switch on Available now on Home.'), findsOneWidget);
      await t.tap(_day(29));
      await settle(t);
      expect(find.text('Mark not available'), findsOneWidget);
    });

    testWidgets('no offline note when the switch is on', (t) async {
      await open(t, AvailFake(read: availJson(switchOn: true)));
      expect(find.byType(TaxiOfflineNote), findsNothing);
    });

    testWidgets('no cache and loading = skeleton, Save hidden', (t) async {
      final fake = AvailFake(read: availJson())..hangRead = true;
      await open(t, fake, load: false);
      expect(find.byType(OwnerSkeletonList), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Save'), findsNothing);
    });

    testWidgets('no cache and failed = Could not load + Try again', (t) async {
      final fake = AvailFake(read: null);
      await open(t, fake, load: false);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      fake.read = availJson();
      await t.tap(find.text('Try again'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.text('Family function in Almora'), findsOneWidget);
    });

    testWidgets('cache and failed refresh = cached page with the stale line', (t) async {
      final fake = AvailFake(read: null);
      await t.runAsync(() async {
        availBase();
        OwnerCache.write('user-a', OwnerCacheKeys.daysOff, availJson());
      });
      final store = await t.runAsync(() async => availStore(fake));
      final c = Get.put(TaxiAvailabilityController(store: store, clock: () => availToday), tag: TaxiAvailabilityController.tag);
      await pumpPhone(t, TaxiAvailabilityScreen(controller: c));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.byType(OwnerStaleLine), findsOneWidget);
      expect(find.text('Family function in Almora'), findsOneWidget);
    });
  });

  group('reason sheet', () {
    testWidgets('free day: counter, Mark not available makes the day off and turns Save on', (t) async {
      final h = await open(t, AvailFake(read: availJson()));
      await t.tap(_day(29));
      await settle(t);
      expect(find.text('Sun, 29 Nov'), findsOneWidget);
      expect(find.text('Not available this day'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.text('Only you see this'), findsOneWidget);
      expect(find.text('0 / 200'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Family function in Almora');
      await t.pump();
      expect(find.text('25 / 200'), findsOneWidget);
      await t.tap(find.text('Mark not available'));
      await settle(t);
      expect(h.controller.stateOf(t.widget<TaxiAvailDayBox>(_day(29)).cell).name, 'off');
      expect(h.controller.reasonOf(DateTime(2026, 11, 29)), 'Family function in Almora');
      expect(t.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save')).onPressed, isNotNull);
      expect(h.fake.count('PUT'), 0);
    });

    testWidgets('typing stops at 200 and the counter turns red', (t) async {
      await open(t, AvailFake(read: availJson()));
      await t.tap(_day(29));
      await settle(t);
      await t.enterText(find.byType(TextField), 'a' * 260);
      await t.pump();
      expect(t.widget<TextField>(find.byType(TextField)).controller?.text.length, 200);
      expect(find.text('200 / 200 · limit reached'), findsOneWidget);
    });

    testWidgets('Hindi text is counted by code points; emoji is refused', (t) async {
      await open(t, AvailFake(read: availJson()));
      await t.tap(_day(29));
      await settle(t);
      await t.enterText(find.byType(TextField), 'शादी');
      await t.pump();
      expect(find.text('4 / 200'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'trip 😀');
      await t.pump();
      expect(t.widget<TextField>(find.byType(TextField)).controller?.text.contains('😀'), isFalse);
    });

    testWidgets('off day: Save reason and Make available', (t) async {
      final h = await open(t, AvailFake(read: availJson()));
      await t.tap(_day(27));
      await settle(t);
      expect(find.text('Marked not available'), findsOneWidget);
      expect(find.text('Family function in Almora'), findsWidgets);
      expect(find.text('25 / 200'), findsOneWidget);
      await t.tap(find.text('Make available'));
      await settle(t);
      expect(h.controller.stateOf(t.widget<TaxiAvailDayBox>(_day(27)).cell).name, 'free');
      expect(h.controller.diff().clear, ['2026-11-27']);
      await t.tap(find.text('No reason added'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Car service');
      await t.tap(find.text('Save reason'));
      await settle(t);
      expect(h.controller.diff().set.single.toJson(), {'date': '2026-11-30', 'reason': 'Car service'});
    });

    testWidgets('a day off that is also booked: Save reason shows the booking toast and changes nothing', (t) async {
      final h = await open(t, AvailFake(read: availJson(daysOff: [dayRow('2026-11-27', 'Family function in Almora'), dayRow('2026-11-28', 'Wedding')], booked: ['2026-11-28'])));
      expect(t.widget<TaxiAvailDayBox>(_day(28)).state.name, 'booked');
      await t.tap(find.text('Wedding'));
      await settle(t);
      expect(find.text('Marked not available'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Wedding in Almora');
      await t.tap(find.text('Save reason'));
      await settle(t);
      expect(find.text('This day has a booking'), findsOneWidget);
      expect(h.controller.pending, isEmpty);
      expect(h.controller.dirty.value, isFalse);
      await drain(t);
    });

    testWidgets('while Save runs, a day tap or a list tap opens nothing', (t) async {
      final fake = AvailFake(read: availJson());
      final h = await open(t, fake);
      await t.tap(_day(29));
      await settle(t);
      await t.tap(find.text('Mark not available'));
      await settle(t);
      fake.hangSave = true;
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.pump();
      expect(h.controller.saving.value, isTrue);
      await t.tap(_day(30));
      await settle(t);
      expect(find.text('Marked not available'), findsNothing);
      await t.tap(find.text('Family function in Almora'));
      await settle(t);
      expect(find.text('Marked not available'), findsNothing);
      expect(h.controller.pending.keys, ['2026-11-29']);
      expect(fake.count('PUT'), 1);
    });

    testWidgets('closing the sheet changes nothing', (t) async {
      final h = await open(t, AvailFake(read: availJson()));
      await t.tap(_day(29));
      await settle(t);
      await t.enterText(find.byType(TextField), 'typed');
      Navigator.of(t.element(find.text('Reason'))).pop();
      await settle(t);
      expect(h.controller.dirty.value, isFalse);
    });

    testWidgets('Save sends one PUT', (t) async {
      final h = await open(t, AvailFake(read: availJson()));
      await t.tap(_day(29));
      await settle(t);
      await t.tap(find.text('Mark not available'));
      await settle(t);
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(h.fake.count('PUT'), 1);
      await drain(t);
    });
  });

  group('save on a pushed page', () {
    Future<(AvailHarness, TaxiDriverHomeController)> openPushed(WidgetTester t, AvailFake fake) async {
      final r = (await t.runAsync(() async {
        final h = await availSetUp(fake);
        final home = Get.put(TaxiDriverHomeController(api: _HomeApi(true), deniedProbe: () async => false, userId: () => 'user-a'));
        await home.reload();
        return (h, home);
      }))!;
      await pumpPhone(t, _Host(r.$1.controller));
      await t.tap(find.text('open'));
      await settle(t);
      await settle(t);
      expect(find.byType(TaxiAvailabilityScreen), findsOneWidget);
      await t.tap(_day(29));
      await settle(t);
      await t.tap(find.text('Mark not available'));
      await settle(t);
      return r;
    }

    testWidgets('success closes the page, shows the toast and patches Home counts', (t) async {
      final saved = availJson(daysOff: [
        dayRow('2026-11-27', 'Family function in Almora'),
        dayRow('2026-11-29'),
        dayRow('2026-11-30'),
      ]);
      final (h, home) = await openPushed(t, AvailFake(read: availJson(), save: (_) async => {'data': saved}));
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      await settle(t);
      expect(h.fake.count('PUT'), 1);
      expect(find.byType(TaxiAvailabilityScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Availability saved'), findsOneWidget);
      final raw = home.data!.raw;
      expect(raw['numbers']['taxi']['availability']['daysOff'], 3);
      await drain(t);
    });

    testWidgets('failure keeps the page, the coral day and Save', (t) async {
      final fake = AvailFake(read: availJson(), save: (_) async => throw refusal(daysOffPath, 500, {'error': {'message': 'down'}}));
      final (h, _) = await openPushed(t, fake);
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(h.fake.count('PUT'), 1);
      expect(find.byType(TaxiAvailabilityScreen), findsOneWidget);
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      expect(t.widget<TaxiAvailDayBox>(_day(29)).state.name, 'off');
      expect(t.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save')).onPressed, isNotNull);
      await drain(t);
    });
  });
}
