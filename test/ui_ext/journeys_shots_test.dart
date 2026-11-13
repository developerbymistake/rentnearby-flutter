import 'dart:io';

import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:bakhli/features/taxi/journeys/journeys_controller.dart';
import 'package:bakhli/features/taxi/journeys/my_journeys_screen.dart';
import 'package:bakhli/features/taxi/journeys/saved_journey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

class _Journeys extends JourneysController {
  int loads = 0;
  int refreshes = 0;
  final replaced = <String>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> load({bool force = false}) async => loads++;

  @override
  Future<void> refreshOne(String id, {bool silent = false}) async {
    if (!silent) refreshes++;
  }

  @override
  Future<void> replaceDriver(String id, int legIndex, String taxiId) async => replaced.add('$id:$legIndex:$taxiId');
}

_Journeys _ctrl(List<SavedJourney> list, {bool loading = false, bool failed = false, bool offline = false}) {
  final c = _Journeys();
  c.journeys.assignAll(list);
  c.isLoading.value = loading;
  c.loadFailed.value = failed;
  c.isOffline.value = offline;
  Get.put<JourneysController>(c, permanent: true);
  return c;
}

final DateTime _now = DateTime.now();
String _ago(Duration d) => _now.subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _contact(String id, String name, String vehicle, int seats, String plate, {bool phone = true, bool available = true}) => {
      'taxiId': id,
      'driverName': name,
      'vehicleTypeName': vehicle,
      'seats': seats,
      'plateDisplay': plate,
      if (phone) 'phone': '9876500000',
      'available': available,
    };

Map<String, dynamic> _leg(int i, String from, String to, Map<String, dynamic> driver,
        {int? fare,
        List<Map<String, dynamic>> backups = const [],
        String status = 'Unknown',
        Duration? asked,
        int? quoted,
        bool available = true,
        int? previous,
        String? booking,
        int? agreed,
        String? meet}) =>
    {
      'legIndex': i,
      'legKey': 'l$i',
      'fromName': from,
      'toName': to,
      'driver': driver,
      'backups': backups,
      'listedFare': ?fare,
      'lastKnownStatus': status,
      if (asked != null) 'lastKnownAt': _ago(asked),
      'lastQuotedFare': ?quoted,
      'driverAvailable': available,
      'previousFare': ?previous,
      'bookingStatus': ?booking,
      'agreedFare': ?agreed,
      'meetingPlace': ?meet,
    };

SavedJourney _journey(String id, String from, String to, String date, int people, String status, List<Map<String, dynamic>> legs,
        {String? tripId, String? role, int? day, String? title, int? total, Duration? checked}) =>
    SavedJourney.fromJson({
      'id': id,
      'fromName': from,
      'toName': to,
      'date': date,
      'people': people,
      'planKey': 'p-$id',
      'cars': legs.length,
      'status': status,
      'listedTotal': ?total,
      'legs': legs,
      'tripId': ?tripId,
      'tripRole': ?role,
      'tripTravelDay': ?day,
      'tripTitle': ?title,
      if (checked != null) 'lastRefreshedAt': _ago(checked),
    });

final _rakesh = _contact('t1', 'Rakesh Singh', 'Sedan', 4, 'UK04 TA 1111');
final _pradeep = _contact('t2', 'Pradeep Kumar', 'SUV', 7, 'UK01 TB 2222');
final _sunil = _contact('t3', 'Sunil', 'Sedan', 4, 'UK04 TA 3333');
final _harish = _contact('t4', 'Harish', 'SUV', 7, 'UK04 TA 4444');
final _mohan = _contact('t5', 'Mohan', 'Sedan', 4, 'UK04 TA 5555');

List<SavedJourney> _list() => [
      _journey('a', 'Haldwani', 'Almora', '2030-11-14', 2, 'DriverUnavailable', [
        _leg(1, 'Haldwani', 'Bhowali', _contact('t1', 'Rakesh', 'Sedan', 4, 'UK04 TA 1111'), fare: 900, available: false, backups: [_sunil]),
        _leg(2, 'Bhowali', 'Almora', _pradeep, fare: 1400),
      ], tripId: 'trip', role: 'segment', day: 2),
      _journey('b', 'Nainital', 'Kausani', '2030-11-18', 4, 'NotAsked', [_leg(1, 'Nainital', 'Kausani', _pradeep, fare: 2600)]),
      _journey('c', 'Almora', 'Haldwani', '2030-11-20', 2, 'Ready', [_leg(1, 'Almora', 'Haldwani', _rakesh, fare: 1800)]),
      _journey('d', 'Kathgodam', 'Bhimtal', '2030-11-02', 2, 'Completed', [
        _leg(1, 'Kathgodam', 'Bhimtal', _contact('t9', 'Sunil Negi', 'Tempo Traveller', 12, 'UK04 TA 3333'), fare: 800, booking: 'ConfirmedByBoth', agreed: 800),
      ], tripId: 'trip2', role: 'gettingThere'),
    ];

SavedJourney _saved({String which = 'main'}) {
  final legA = switch (which) {
    'booked' => _leg(1, 'Haldwani', 'Bhowali', _rakesh, fare: 900, booking: 'BookedByYou', agreed: 900),
    'un' => _leg(1, 'Haldwani', 'Bhowali', _rakesh, fare: 900, available: false, backups: [_sunil, _mohan]),
    'pick' => _leg(1, 'Haldwani', 'Bhowali', _rakesh, fare: 900, available: false),
    _ => _leg(1, 'Haldwani', 'Bhowali', _rakesh, fare: 900, status: 'Free', asked: const Duration(hours: 2), quoted: 950, backups: [_sunil]),
  };
  final legB = switch (which) {
    'pick' => _leg(2, 'Bhowali', 'Almora', _contact('t2', 'Pradeep Kumar', 'SUV', 7, 'UK01 TB 2222', phone: false), fare: 1400, backups: [_harish], meet: 'Bhowali taxi stand'),
    _ => _leg(2, 'Bhowali', 'Almora', _pradeep, fare: 1400, status: 'NoAnswer', asked: const Duration(hours: 1), previous: 1300, backups: [_harish], meet: 'Bhowali taxi stand'),
  };
  return _journey('s', 'Haldwani', 'Almora', '2030-11-14', 2, which == 'un' || which == 'pick' ? 'DriverUnavailable' : 'Ready', [legA, legB],
      tripId: which == 'main' || which == 'booked' ? 'trip' : null, role: which == 'main' || which == 'booked' ? 'segment' : null, day: 2, title: 'Nainital to Almora', total: 2300, checked: const Duration(minutes: 5));
}

SavedJourney _done() => _journey('s', 'Kathgodam', 'Bhimtal', '2030-11-02', 2, 'Completed', [
      _leg(1, 'Kathgodam', 'Bhimtal', _sunil, fare: 800, booking: 'ConfirmedByBoth', agreed: 800),
    ], total: 800, checked: const Duration(days: 10));

const _cases = [(Size(360, 800), 1.0, '360'), (Size(360, 800), 1.3, '360x13'), (Size(300, 640), 1.0, '300')];

Future<void> _scroll(WidgetTester t, double y) async {
  final s = t.state<ScrollableState>(find.byType(Scrollable).first);
  for (var i = 0; i < 3; i++) {
    s.position.jumpTo(y.clamp(0, s.position.maxScrollExtent));
    await t.pump(const Duration(milliseconds: 200));
  }
  await settlePhone(t);
}

void main() {
  shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\journeys';
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    Get.testMode = true;
    debugDisableShadows = false;
  });
  tearDown(() => Get.reset(clearRouteBindings: true));

  group('my journeys', () {
    for (final (size, scale, tag) in _cases) {
      testWidgets('list $tag', (t) async {
        final c = _ctrl(_list());
        await pumpPhone(t, const MyJourneysScreen(), size: size, textScale: scale);
        await settlePhone(t);
        await shot(t, 'list_$tag');
        expect(find.text('Replace with Sunil'), findsOneWidget);
        await t.tap(find.text('Replace with Sunil'));
        expect(c.replaced, ['a:1:t3']);
        await _scroll(t, 3000);
        await shot(t, 'list_end_$tag');
        expect(find.text('Completed'), findsOneWidget);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    for (final (name, loading, failed, offline, list) in [
      ('list_empty', false, false, false, <SavedJourney>[]),
      ('list_load', true, false, false, <SavedJourney>[]),
      ('list_err', false, true, true, <SavedJourney>[]),
      ('list_fail', false, true, false, <SavedJourney>[]),
    ]) {
      testWidgets(name, (t) async {
        final c = _ctrl(list, loading: loading, failed: failed, offline: offline);
        await pumpPhone(t, const MyJourneysScreen());
        await settlePhone(t);
        await shot(t, name);
        if (failed) {
          final before = c.loads;
          await t.tap(find.text('Retry'));
          expect(c.loads, before + 1);
        }
        debugDisableShadows = true;
      });
    }
  });

  group('saved journey', () {
    for (final (size, scale, tag) in _cases) {
      testWidgets('saved $tag', (t) async {
        final c = _ctrl([_saved()]);
        await pumpPhone(t, const SavedJourneyScreen(journeyId: 's'), size: size, textScale: scale);
        await settlePhone(t);
        await shot(t, 'saved_$tag');
        await t.tap(find.text('Refresh'));
        expect(c.refreshes, 1);
        await _scroll(t, 3000);
        await shot(t, 'saved_end_$tag');
        expect(find.text('Mark done'), findsOneWidget);
        expect(find.text('Delete journey'), findsOneWidget);
        expect(find.text('WhatsApp'), findsNothing);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    for (final which in ['booked', 'un', 'pick']) {
      testWidgets('saved_$which', (t) async {
        _ctrl([_saved(which: which)], offline: which == 'un');
        await pumpPhone(t, const SavedJourneyScreen(journeyId: 's'));
        await settlePhone(t);
        await shot(t, 'saved_$which');
        await _scroll(t, 420);
        await shot(t, 'saved_${which}_y420');
        debugDisableShadows = true;
      });
    }

    testWidgets('saved_done', (t) async {
      _ctrl([_done()]);
      await pumpPhone(t, const SavedJourneyScreen(journeyId: 's'));
      await settlePhone(t);
      await shot(t, 'saved_done');
      expect(find.text('Mark done'), findsNothing);
      expect(find.text('Change driver'), findsNothing);
      await _scroll(t, 3000);
      await shot(t, 'saved_done_end');
      debugDisableShadows = true;
    });

    testWidgets('saved_del', (t) async {
      _ctrl([_saved()]);
      await pumpPhone(t, const SavedJourneyScreen(journeyId: 's'));
      await settlePhone(t);
      await _scroll(t, 3000);
      await t.tap(find.text('Delete journey'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await settlePhone(t);
      await shot(t, 'saved_del');
      expect(find.text('Cancel'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 400));
      debugDisableShadows = true;
    });

    for (final (name, loading) in [('saved_nf', false), ('saved_load', true)]) {
      testWidgets(name, (t) async {
        _ctrl([], loading: loading);
        await pumpPhone(t, const SavedJourneyScreen(journeyId: 'x'));
        await settlePhone(t);
        await shot(t, name);
        debugDisableShadows = true;
      });
    }
  });
}
