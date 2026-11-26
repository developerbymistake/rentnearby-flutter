import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_api.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_store.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_calendar_controller.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_month_grid.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_calendar_strings.dart';
import 'package:bakhli/features/taxi_driver/taxi_driver_deps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'taxi_cal_fixtures.dart';

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

Map<String, dynamic> _offJson(List<String> days) => {
      'today': '2026-11-21',
      'window': {'monthFrom': '2026-11-01', 'monthTo': '2026-11-30', 'locked': true},
      'monthsAhead': 0,
      'switchOn': true,
      'daysOff': [for (final d in days) {'date': d, 'reason': null}],
      'bookedDays': const <String>[],
      'counts': {'month': '2026-11', 'bookings': 2, 'daysOff': days.length},
    };

TaxiAvailabilityStore _offStore(List<String> days) {
  final s = Get.put(TaxiAvailabilityStore(userId: () => 'user-a', clock: () => calToday));
  s.apply(TaxiAvailability.fromJson(_offJson(days)));
  TaxiDriverDeps.isDayOff = (d) => s.isOff(d);
  return s;
}

Finder _box(int day) => find.byWidgetPredicate((w) => w is TaxiDayBox && w.cell.inMonth && w.cell.date.day == day);

Map<String, dynamic> _bucketBody(int seconds) => {
      'status': '429',
      'code': 429,
      'data': {'retryAfterSeconds': seconds, 'bucket': 'bookings', 'limit': 3},
      'error': {'message': 'You can change this 3 times an hour.', 'type': 'TooManyRequests'},
    };

void main() {
  setUpAll(() => initTestStorage('taxi_cal_days_off'));
  tearDown(() {
    TaxiHourlyLimit.reset();
    calTearDown();
  });

  group('bookings tab', () {
    testWidgets('an OFF day is grey with OFF; tap = toast and no sheet', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-27', '2026-11-29']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(27)).off, isTrue);
      expect(tester.widget<TaxiDayBox>(_box(26)).off, isFalse);
      expect(find.descendant(of: _box(27), matching: find.text('OFF')), findsOneWidget);
      final off = tester.widget<TaxiDayBox>(_box(27));
      expect(TaxiDayBox.semanticsOf(off.cell, off: off.off), startsWith('27 November, Not available'));
      await tester.tap(_box(27));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 27))), findsNothing);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsNothing);
      await drain(tester);
    });

    testWidgets('a past day stays tappable and opens the day sheet', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-27']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(19)).off, isFalse);
      await tester.tap(_box(19));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 19))), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.tripsOnDay(1)), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsOneWidget);
      await drain(tester);
    });

    testWidgets('an off day with an app booking or an older own trip is drawn booked and opens its trips', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-23', '2026-11-25', '2026-11-27']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      final auto = tester.widget<TaxiDayBox>(_box(23));
      expect(auto.off, isFalse);
      expect(auto.cell.appCount, 1);
      expect(find.descendant(of: _box(23), matching: find.text('OFF')), findsNothing);
      expect(tester.widget<TaxiDayBox>(_box(25)).off, isFalse);
      expect(tester.widget<TaxiDayBox>(_box(27)).off, isTrue);
      await tester.tap(_box(23));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 23))), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.tripsOnDay(1)), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsNothing, reason: 'adding on an off day stays blocked');
      Navigator.of(tester.element(find.text(TaxiCalendarStrings.tripsOnDay(1)))).pop();
      await settle(tester);
      await tester.tap(_box(25));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 25))), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsNothing);
      await drain(tester);
    });

    testWidgets('a store today behind the calendar today: the past off day is not OFF and its tap opens the day sheet', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      final s = Get.put(TaxiAvailabilityStore(userId: () => 'user-a', clock: () => DateTime(2026, 11, 20)));
      s.apply(TaxiAvailability.fromJson({..._offJson(['2026-11-20', '2026-11-27']), 'today': '2026-11-20'}));
      TaxiDriverDeps.isDayOff = (d) => s.isOff(d);
      expect(s.isOff(DateTime(2026, 11, 20)), isTrue);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(20)).off, isFalse);
      await tester.tap(_box(20));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 20))), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.nothingOnDay), findsOneWidget);
      await drain(tester);
    });

    testWidgets('no store = no OFF day', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(find.text('OFF'), findsNothing);
    });
  });

  group('trip sheet', () {
    Future<TaxiCalendarController> openSheet(WidgetTester tester, CalFake fake, {DateTime? date, CalendarEntry? editing}) async {
      final c = calSetUp(fake);
      await c.open(DateTime(2026, 11));
      _offStore(['2026-11-21', '2026-11-22', '2026-11-27']);
      await pumpPhone(
        tester,
        Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c, date: date, editing: editing), child: const Text('open')))),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      return c;
    }

    test('Add trip with today off starts on the next free day', () {
      TaxiDriverDeps.isDayOff = (d) => d.day == 21 || d.day == 22;
      expect(TaxiTripForm.firstFreeDay(DateTime(2026, 11, 21)), DateTime(2026, 11, 23));
      expect(TaxiTripForm.firstFreeDay(DateTime(2026, 11, 24)), DateTime(2026, 11, 24));
      TaxiDriverDeps.debugReset();
    });

    testWidgets('the form opens on the first day that is not off', (tester) async {
      await openSheet(tester, CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      expect(find.textContaining('23 Nov'), findsWidgets);
    });

    testWidgets('picking an off day shows the Date error at once and Save sends nothing', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      await openSheet(tester, fake);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
      await tester.tap(find.text(TaxiCalendarStrings.dateField(DateTime(2026, 11, 23))));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(TemplateCalendarPopup), matching: find.text('27')).last);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await settle(tester);
      expect(find.byType(TemplateCalendarPopup), findsNothing);
      expect(find.text(TaxiCalendarStrings.dateField(DateTime(2026, 11, 27))), findsOneWidget);
      expect(find.text('This day is off. Change it on Home.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsOneWidget);
      expect(find.text('Save trip'), findsOneWidget);
      expect(fake.count('POST'), 0);
      await tester.tap(find.text(TaxiCalendarStrings.dateField(DateTime(2026, 11, 27))));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(TemplateCalendarPopup), matching: find.text('24')).last);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await settle(tester);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
    });

    testWidgets('server DayIsOff maps to the Date error', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = await openSheet(tester, fake);
      final form = TaxiTripForm(controller: c, date: DateTime(2026, 11, 24));
      form.applyRefusal(const OwnerRefused<void>(type: 'DayIsOff', statusCode: 409, data: {'date': '2026-11-24'}));
      expect(form.errors[TaxiTripField.date], 'This day is off. Change it on Home.');
      form.dispose();
    });

    testWidgets('a server DayIsOff on Save shows the Date error and reloads the days off', (tester) async {
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries())},
        writeRefusal: {
          'status': 409,
          'body': {
            'data': {'date': '2026-11-23'},
            'error': {'type': 'DayIsOff', 'message': 'This day is off.'},
          },
        },
      );
      await openSheet(tester, fake);
      final store = Get.find<TaxiAvailabilityStore>();
      var refreshed = 0;
      final sub = store.load.listen((l) {
        if (l is OwnerLoadData<TaxiAvailability> && l.stale) refreshed++;
      });
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(tester);
      expect(fake.count('POST'), 1);
      expect(find.text('This day is off. Change it on Home.'), findsOneWidget);
      expect(find.text('Save trip'), findsOneWidget);
      expect(refreshed, 1, reason: 'the store refreshed once (the fake has no days-off read, so it keeps the value and marks it stale)');
      await sub.cancel();
      await drain(tester);
    });

    testWidgets('an old entry on an off day can still save amounts (date not moved)', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = await openSheet(tester, fake);
      final old = CalendarEntry.fromJson(tripJson('m27', from: '2026-11-27', label: 'Old trip', finalAmount: 900));
      final form = TaxiTripForm(controller: c, editing: old);
      expect(form.date, DateTime(2026, 11, 27));
      expect(form.validate(), isTrue);
      form.setDate(DateTime(2026, 11, 22));
      expect(form.validate(), isFalse);
      form.dispose();
    });
  });

  group('bucket B (bookings) 429', () {
    test('a create 429 with the bucket holds further writes and the message carries the minutes', () async {
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries())},
        writeRefusal: {'status': 429, 'body': _bucketBody(130)},
      );
      final c = calSetUp(fake);
      await c.open(DateTime(2026, 11));
      final draft = TaxiTripForm(controller: c, date: DateTime(2026, 11, 24))..label.text = 'Airport drop';
      final r = await c.create(draft.draft());
      expect(r, isA<OwnerRefused<dynamic>>());
      expect((r as OwnerRefused<dynamic>).message, 'You can change this 3 times an hour. Try again in 3 min.');
      expect(fake.count('POST'), 1);
      final again = await c.delete('m03');
      expect(again, isA<OwnerRefused<void>>());
      expect((again as OwnerRefused<void>).statusCode, 429);
      expect(fake.count('DELETE'), 0);
      draft.dispose();
    });

    test('a 429 without the bucket keeps the old handling and sets no hold', () async {
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries())},
        writeRefusal: {
          'status': 429,
          'body': {
            'error': {'type': 'TooManyRequests', 'message': 'Too many tries. Please wait.'},
          },
        },
      );
      final c = calSetUp(fake);
      await c.open(DateTime(2026, 11));
      final r = await c.delete('m03');
      expect((r as OwnerRefused<void>).message, 'Too many tries. Please wait.');
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.bookings), isNull);
    });

    test('the availability bucket and the bookings bucket are separate', () {
      TaxiHourlyLimit.hold(TaxiHourlyLimit.availability, 600);
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.bookings), isNull);
      expect(TaxiHourlyLimit.heldSeconds(TaxiHourlyLimit.availability), isNotNull);
    });

    testWidgets('trip sheet shows the hourly toast with minutes for a bucket 429', (tester) async {
      final fake = CalFake(
        months: {'2026-11': monthJson(entries: novEntries())},
        writeRefusal: {'status': 429, 'body': _bucketBody(61)},
      );
      final c = calSetUp(fake);
      await c.open(DateTime(2026, 11));
      await pumpPhone(tester, Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => TaxiTripSheet.show(ctx, controller: c), child: const Text('open')))));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      expect(find.text('You can change this 3 times an hour. Try again in 2 min.'), findsOneWidget);
      expect(find.text('Save trip'), findsOneWidget);
      await drain(tester);
    });
  });
}
