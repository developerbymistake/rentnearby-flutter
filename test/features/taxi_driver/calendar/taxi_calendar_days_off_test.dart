import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/calendar/calendar_api.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_api.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_models.dart';
import 'package:bakhli/features/taxi_driver/availability/taxi_availability_store.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_bookings_tab.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_month_grid.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_trip_sheet.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_availability_strings.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_calendar_strings.dart';
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

const String _daysOffPath = '/taxis/me/days-off';

Map<String, dynamic> _offJson(List<String> days, {Map<String, String> reasons = const {}}) => {
      'today': '2026-11-21',
      'window': {'monthFrom': '2026-11-01', 'monthTo': '2026-11-30', 'locked': true},
      'monthsAhead': 0,
      'switchOn': true,
      'daysOff': [for (final d in days) {'date': d, 'reason': reasons[d]}],
      'bookedDays': const <String>[],
      'counts': {'month': '2026-11', 'bookings': 2, 'daysOff': days.length},
    };

TaxiAvailabilityStore _offStore(List<String> days, {Map<String, String> reasons = const {}}) {
  final s = Get.put(TaxiAvailabilityStore(userId: () => 'user-a', clock: () => calToday));
  s.apply(TaxiAvailability.fromJson(_offJson(days, reasons: reasons)));
  return s;
}

Finder _box(int day) => find.byWidgetPredicate((w) => w is TaxiDayBox && w.cell.inMonth && w.cell.date.day == day);

Map<String, dynamic>? _lastBody(CalFake fake, String call) {
  for (var i = fake.calls.length - 1; i >= 0; i--) {
    if (fake.calls[i] == call) return fake.bodies[i];
  }
  return null;
}

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

  group('bookings calendar', () {
    testWidgets('a day off is drawn in the same calendar with the legend and the rule line', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-27', '2026-11-29']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(27)).off, isTrue);
      expect(tester.widget<TaxiDayBox>(_box(26)).off, isFalse);
      expect(find.text('OFF'), findsNothing);
      final off = tester.widget<TaxiDayBox>(_box(27));
      expect(TaxiDayBox.semanticsOf(off.cell, off: off.off), startsWith('27 November, Day off'));
      expect(find.text('Day off'), findsOneWidget, reason: 'legend');
      expect(find.text('Booked and day-off days are hidden from travellers.'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('tapping a day off opens its sheet with Save, Change to Booked and Remove day off', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-27'], reasons: {'2026-11-27': 'Family function'});
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.tap(_box(27));
      await settle(tester);
      expect(find.text(TaxiAvailabilityStrings.sheetTitle(DateTime(2026, 11, 27))), findsOneWidget);
      expect(find.text("Travellers won't see your taxi this day."), findsOneWidget);
      expect(find.text('Family function'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Change to Booked'), findsOneWidget);
      expect(find.text('Remove day off'), findsOneWidget);
      expect(find.text('This day is off. Change it on Home.'), findsNothing);
      await drain(tester);
    });

    testWidgets('Remove day off sends one clear key', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      _offStore(['2026-11-27']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c), toastHost: true);
      await settle(tester);
      await tester.tap(_box(27));
      await settle(tester);
      await tester.tap(find.text('Remove day off'));
      await settle(tester);
      expect(fake.count('PUT $_daysOffPath'), 1);
      expect(_lastBody(fake, 'PUT $_daysOffPath'), {'set': const <Map<String, dynamic>>[], 'clear': ['2026-11-27']});
      await drain(tester);
    });

    testWidgets('a free future day asks Booked or Day off; Day off saves one set row with the reason', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      _offStore(const []);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c), toastHost: true);
      await settle(tester);
      await tester.tap(_box(24));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 24))), findsOneWidget);
      expect(find.text('What is on this day?'), findsOneWidget);
      expect(find.text('A trip you got by phone or WhatsApp'), findsOneWidget);
      expect(find.text('You are not driving this day'), findsOneWidget);
      await tester.tap(find.text('You are not driving this day'));
      await settle(tester);
      expect(find.text(TaxiAvailabilityStrings.sheetTitle(DateTime(2026, 11, 24))), findsOneWidget);
      expect(find.text('Remove day off'), findsNothing);
      expect(find.text('Change to Booked'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Wedding');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(_lastBody(fake, 'PUT $_daysOffPath'), {
        'set': [
          {'date': '2026-11-24', 'reason': 'Wedding'},
        ],
        'clear': const <String>[],
      });
      await drain(tester);
    });

    testWidgets('Booked opens Add trip on that day with the switch off; turned on, the trip is sent with keepVisible', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      _offStore(const []);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.tap(_box(24));
      await settle(tester);
      await tester.tap(find.text('A trip you got by phone or WhatsApp'));
      await settle(tester);
      expect(find.text('Save trip'), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.dateField(DateTime(2026, 11, 24))), findsOneWidget);
      expect(find.text('Still take bookings this day'), findsOneWidget);
      expect(find.text('Turn on for a short trip, like an airport drop'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Airport drop');
      await tester.ensureVisible(find.text('Still take bookings this day'));
      await tester.tap(find.text('Still take bookings this day'));
      await settle(tester);
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      final body = _lastBody(fake, 'POST /taxis/me/calendar/entries');
      expect(body?['dateFrom'], '2026-11-24');
      expect(body?['keepVisible'], isTrue);
      await drain(tester);
    });

    testWidgets('Change to Booked opens Add trip for the day off and saves with no day-off refusal; the days off reload', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      _offStore(['2026-11-27']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.tap(_box(27));
      await settle(tester);
      await tester.tap(find.text('Change to Booked'));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.dateField(DateTime(2026, 11, 27))), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Mehra family');
      final reads = fake.count('GET $_daysOffPath');
      await tester.tap(find.text('Save trip'));
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(tester);
      expect(fake.count('POST /taxis/me/calendar/entries'), 1);
      expect(find.text('Save trip'), findsNothing, reason: 'saved and closed');
      expect(_lastBody(fake, 'POST /taxis/me/calendar/entries')?['keepVisible'], isFalse);
      expect(fake.count('GET $_daysOffPath'), greaterThan(reads), reason: 'the server cleared the day off, so the app reads the days off again');
      await drain(tester);
    });

    testWidgets('a past day opens the day sheet', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-27']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      await tester.tap(_box(19));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.daySheetTitle(DateTime(2026, 11, 19))), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.tripsOnDay(1)), findsOneWidget);
      expect(find.text('What is on this day?'), findsNothing);
      expect(find.widgetWithText(SecondaryButton, 'Day off'), findsNothing);
      await drain(tester);
    });

    testWidgets('a future day with a trip can still be set as a day off from its day sheet', (tester) async {
      final fake = CalFake(months: {'2026-11': monthJson(entries: novEntries())});
      final c = calSetUp(fake);
      _offStore(const []);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c), toastHost: true);
      await settle(tester);
      await tester.tap(_box(25));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.tripsOnDay(1)), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsOneWidget);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Day off'));
      await settle(tester);
      expect(find.text(TaxiAvailabilityStrings.sheetTitle(DateTime(2026, 11, 25))), findsOneWidget);
      expect(find.text('Remove day off'), findsNothing);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(_lastBody(fake, 'PUT $_daysOffPath'), {
        'set': [
          {'date': '2026-11-25', 'reason': null},
        ],
        'clear': const <String>[],
      });
      await drain(tester);
    });

    testWidgets('a day past the trip window but inside the days-off window still offers Day off', (tester) async {
      final month = monthJson(entries: novEntries());
      month['window'] = {...month['window'] as Map<String, dynamic>, 'manualTo': '2026-11-26'};
      final c = calSetUp(CalFake(months: {'2026-11': month}));
      _offStore(const []);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(c.canAddOn(DateTime(2026, 11, 27)), isFalse);
      await tester.tap(_box(27));
      await settle(tester);
      expect(find.text('What is on this day?'), findsOneWidget);
      expect(find.text('You are not driving this day'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('a day off that also has a trip opens its trips with Add trip and a Day off button', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      _offStore(['2026-11-25']);
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(25)).off, isTrue);
      await tester.tap(_box(25));
      await settle(tester);
      expect(find.text(TaxiCalendarStrings.tripsOnDay(1)), findsOneWidget);
      expect(find.text(TaxiCalendarStrings.addTripOnDay), findsOneWidget);
      await tester.tap(find.widgetWithText(SecondaryButton, 'Day off'));
      await settle(tester);
      expect(find.text(TaxiAvailabilityStrings.sheetTitle(DateTime(2026, 11, 25))), findsOneWidget);
      expect(find.text('Remove day off'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('no store = no day off', (tester) async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await pumpPhone(tester, TaxiBookingsTab(root: true, controller: c));
      await settle(tester);
      expect(tester.widget<TaxiDayBox>(_box(27)).off, isFalse);
    });
  });

  group('trip sheet', () {
    test('the form starts on the given day even when it is off', () async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await c.open(DateTime(2026, 11));
      _offStore(['2026-11-21', '2026-11-22']);
      final form = TaxiTripForm(controller: c, date: DateTime(2026, 11, 21));
      expect(form.date, DateTime(2026, 11, 21));
      form.label.text = 'Airport drop';
      expect(form.validate(), isTrue);
      form.setDate(DateTime(2026, 11, 22));
      expect(form.errors[TaxiTripField.date], isNull);
      form.dispose();
    });

    test('keepVisible: off by default, the switch sends true, an edit keeps the saved value', () async {
      final c = calSetUp(CalFake(months: {'2026-11': monthJson(entries: novEntries())}));
      await c.open(DateTime(2026, 11));
      final form = TaxiTripForm(controller: c, date: DateTime(2026, 11, 24))..label.text = 'Airport drop';
      expect(form.keepVisible, isFalse);
      expect(form.draft().toJson()['keepVisible'], isFalse);
      form.setKeepVisible(true);
      expect(form.dirty, isTrue);
      expect(form.draft().toJson()['keepVisible'], isTrue);
      form.dispose();
      final saved = CalendarEntry.fromJson({...tripJson('m24', from: '2026-11-24', label: 'Short drop'), 'keepVisible': true});
      expect(saved.keepVisible, isTrue);
      final edit = TaxiTripForm(controller: c, editing: saved);
      expect(edit.keepVisible, isTrue);
      expect(edit.dirty, isFalse);
      expect(edit.draft().toJson()['keepVisible'], isTrue);
      edit.dispose();
      expect(CalendarEntry.fromJson(tripJson('m25', from: '2026-11-25')).keepVisible, isFalse);
    });
  });

  test('stays are unchanged: a draft without keepVisible sends no key and an entry without it reads false', () {
    final draft = CalendarEntryDraft(id: 's1', label: 'Guest', dateFrom: DateTime(2026, 11, 24), dateTo: DateTime(2026, 11, 25));
    expect(draft.toJson().containsKey('keepVisible'), isFalse);
    expect(CalendarEntry.fromJson(tripJson('s1', from: '2026-11-24')).keepVisible, isFalse);
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
