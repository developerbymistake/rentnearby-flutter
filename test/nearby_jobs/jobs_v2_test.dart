import 'dart:async';
import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/jobs/models/job_lookups_model.dart';
import 'package:bakhli/features/jobs/v2/jobs_city_sheet_v2.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/jobs/v2/jobs_landing_screen_v2.dart';
import 'package:bakhli/features/nearby/data/nearby_repository_base.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../ui_golden/golden_support.dart';

Map<String, dynamic> _json(String id, {double? km = 3, String label = 'near', String? city = 'Nainital', String? state = 'Uttarakhand'}) => {
      'id': id,
      'stayName': 'Stay $id',
      'title': 'Cook $id',
      'roleName': 'Cook',
      'jobTypeName': 'Full time',
      'salaryTypeName': 'Monthly',
      'minSalary': 12000,
      'maxSalary': 18000,
      'createdAt': DateTime.now().toIso8601String(),
      'distanceKm': ?km,
      'labelKey': label,
      'cityName': city,
      'stateName': state,
    };

JobFeedItem _item(String id, {double km = 3, String label = 'near'}) => JobFeedItem.fromJson(_json(id, km: km, label: label));

TripCityModel _city(int k, String n, String state, {bool popular = false, bool ready = true}) => TripCityModel(
      cityKey: k,
      name: n,
      districtName: 'D$k',
      stateName: state,
      latitude: 29,
      longitude: 79,
      isPopularDestination: popular,
      status: ready ? TripCityStatus.ready : TripCityStatus.notReady,
    );

class _Catalog extends TripCityCatalog {
  final list = [
    _city(1, 'Nainital', 'Uttarakhand', popular: true),
    _city(2, 'Almora', 'Uttarakhand'),
    _city(3, 'Manali', 'Himachal Pradesh', popular: true),
    _city(4, 'Hidden', 'Uttarakhand', ready: false),
  ];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  List<String> liveStates() => ['Himachal Pradesh', 'Uttarakhand'];
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => list;
  @override
  List<TripCityModel> search(String q) {
    final found = TripCitySearch.filter(list, q);
    return q.trim().isEmpty ? TripCitySearch.popularFirst(found) : found;
  }
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Call {
  final int? cityKey;
  final double? lat;
  final double? lng;
  final String? token;
  final String? departmentId;
  _Call(this.cityKey, this.lat, this.lng, this.token, this.departmentId);
}

class _Fake {
  final calls = <_Call>[];
  Completer<NearbyPage<JobFeedItem>>? hold;
  NearbyPage<JobFeedItem> Function(_Call c)? answer;

  Future<NearbyPage<JobFeedItem>> call({
    int? cityKey,
    double? lat,
    double? lng,
    String? departmentId,
    int? minExperience,
    int? maxExperience,
    int? minSalary,
    String? pageToken,
    int pageSize = 20,
  }) {
    final c = _Call(cityKey, lat, lng, pageToken, departmentId);
    calls.add(c);
    final h = hold;
    if (h != null) return h.future;
    return Future.value(answer?.call(c) ?? NearbyPage<JobFeedItem>(items: [_item('a')]));
  }
}

JobsFeedController _ctrl(_Fake f, {({double lat, double lng})? gps = (lat: 29.4, lng: 79.4)}) => JobsFeedController(
      fetch: f.call,
      gps: () => gps,
      lookupsLoader: () async => JobLookups.fromJson(const {}),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });
  tearDown(Get.reset);

  group('parse', () {
    test('item keeps job and distance', () {
      final i = JobFeedItem.fromJson(_json('x', km: 420, label: 'far', city: 'Haldwani'));
      expect(i.id, 'x');
      expect(i.distance!.km, 420);
      expect(i.distance!.label, NearbyLabel.far);
      expect(i.distance!.city, 'Haldwani');
      expect(i.job.title, 'Cook x');
    });

    test('missing distance gives null, village has no city', () {
      final i = JobFeedItem.fromJson(_json('y', km: null, city: null));
      expect(i.distance, isNull);
      final v = JobFeedItem.fromJson(_json('z', km: 4, city: null));
      expect(v.distance!.city, isNull);
    });

    test('label never says near beyond 15 km', () {
      final i = JobFeedItem.fromJson(_json('w', km: 40, label: 'near'));
      expect(i.distance!.label, NearbyLabel.far);
    });

    test('page parse from response', () {
      final p = NearbyRepositoryBase.pageFromResponse<JobFeedItem>({
        'data': {
          'items': [_json('a'), _json('b')],
          'featured': [],
          'hasMore': true,
          'nextToken': 't1',
          'header': {'farAway': true},
        },
      }, JobFeedItem.fromJson);
      expect(p.items.length, 2);
      expect(p.nextToken, 't1');
      expect(p.header.farAway, isTrue);
    });
  });

  group('controller', () {
    test('GPS path sends lat and lng, no cityKey', () async {
      final f = _Fake();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.first.cityKey, isNull);
      expect(f.calls.first.lat, 29.4);
      expect(f.calls.first.lng, 79.4);
      expect(c.items.length, 1);
    });

    test('city pick reloads with cityKey and no lat or lng', () async {
      final f = _Fake();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      c.pickCity(_city(3, 'Manali', 'Himachal Pradesh'));
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.length, 2);
      expect(f.calls.last.cityKey, 3);
      expect(f.calls.last.lat, isNull);
      c.useMyLocation();
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.last.cityKey, isNull);
      expect(f.calls.last.lat, 29.4);
    });

    test('same city again does not reload', () async {
      final f = _Fake();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      c.pickCity(_city(3, 'Manali', 'Himachal Pradesh'));
      c.pickCity(_city(3, 'Manali', 'Himachal Pradesh'));
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.length, 2);
    });

    test('stale response is dropped', () async {
      final f = _Fake();
      f.hold = Completer();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      final first = f.hold!;
      f.hold = null;
      f.answer = (_) => NearbyPage(items: [_item('new')]);
      c.pickCity(_city(2, 'Almora', 'Uttarakhand'));
      await Future<void>.delayed(Duration.zero);
      first.complete(NearbyPage(items: [_item('old')]));
      await Future<void>.delayed(Duration.zero);
      expect(c.items.map((e) => e.id), ['new']);
    });

    test('pagination uses nextToken and dedupes', () async {
      final f = _Fake();
      f.answer = (call) => call.token == null
          ? NearbyPage(items: [_item('a'), _item('b')], hasMore: true, nextToken: 'p2')
          : NearbyPage(items: [_item('b'), _item('c')]);
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      expect(c.hasMore.value, isTrue);
      c.loadNextPage();
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.last.token, 'p2');
      expect(c.items.map((e) => e.id), ['a', 'b', 'c']);
      expect(c.hasMore.value, isFalse);
    });

    test('filter change reloads with department', () async {
      final f = _Fake();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      c.setDepartment('d1');
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.last.departmentId, 'd1');
    });

    test('failure on first load shows loadFailed, retry recovers', () async {
      var fail = true;
      final f = _Fake();
      f.answer = (_) {
        if (fail) throw StateError('x');
        return NearbyPage(items: [_item('a')]);
      };
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      expect(c.loadFailed.value, isTrue);
      fail = false;
      c.retry();
      await Future<void>.delayed(Duration.zero);
      expect(c.loadFailed.value, isFalse);
      expect(c.items.length, 1);
    });

    test('invalidate refetches a registered controller', () async {
      final f = _Fake();
      Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      JobsFeedController.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.length, 2);
    });

    test('invalidate is safe when not registered', () {
      JobsFeedController.invalidate();
    });
  });

  group('city sheet', () {
    for (final w in [300.0, 560.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('search and state filter @${w.toInt()} x$scale', (t) async {
          Get.put<TripCityCatalog>(_Catalog(), permanent: true);
          setGoldenView(t, Size(w, 900));
          await t.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'WorkSans'),
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, 900), textScaler: TextScaler.linear(scale)),
              child: const Scaffold(body: JobsCitySheetV2()),
            ),
          ));
          await t.pumpAndSettle();
          expect(find.text('Nainital'), findsOneWidget);
          expect(find.text('Hidden'), findsNothing);
          await t.tap(find.text('Himachal Pradesh').first);
          await t.pumpAndSettle();
          expect(find.text('Manali'), findsOneWidget);
          expect(find.text('Nainital'), findsNothing);
          await t.tap(find.text('All'));
          await t.pumpAndSettle();
          await t.enterText(find.byType(TextField), 'alm');
          await t.pumpAndSettle();
          expect(find.text('Almora'), findsOneWidget);
          expect(find.text('Manali'), findsNothing);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('state chips are one horizontal row', (t) async {
      Get.put<TripCityCatalog>(_Catalog(), permanent: true);
      setGoldenView(t, const Size(300, 900));
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: JobsCitySheetV2())));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byType(JobsCitySheetV2), matching: find.byType(Wrap)), findsNothing);
      final scroll = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
      expect(scroll, findsOneWidget);
      expect(find.descendant(of: scroll, matching: find.text('All')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('tapping a city returns it', (t) async {
      Get.put<TripCityCatalog>(_Catalog(), permanent: true);
      setGoldenView(t, const Size(360, 900));
      TripCityModel? got;
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => got = await JobsCitySheetV2.show(c),
            child: const Text('open'),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Almora'));
      await t.pumpAndSettle();
      expect(got?.cityKey, 2);
    });

    test('sheet source has no Photon and no hardcoded colour', () {
      final src = File('lib/features/jobs/v2/jobs_city_sheet_v2.dart').readAsStringSync();
      expect(src.contains('Photon'), isFalse);
      expect(src.contains('Color(0x'), isFalse);
      expect(src.contains('noEmojiInputFormatters'), isTrue);
    });
  });

  group('search pin', () {
    test('pickPin fetches around the pin and cancel returns to gps', () async {
      final f = _Fake();
      final c = _ctrl(f);
      Get.put(c, tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      c.pickPin(30.1, 78.2, 'Rishikesh');
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.last.cityKey, isNull);
      expect(f.calls.last.lat, 30.1);
      expect(f.calls.last.lng, 78.2);
      c.useMyLocation();
      await Future<void>.delayed(Duration.zero);
      expect(c.searchPin.value, isNull);
      expect(f.calls.last.lat, 29.4);
    });

    testWidgets('header has the old Search button, no extra search chip', (t) async {
      Get.put<TabConfigController>(_Tabs());
      final f = _Fake();
      final c = _ctrl(f);
      Get.put(c, tag: JobsFeedController.tag);
      setGoldenView(t, const Size(360, 760));
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 760), textScaler: TextScaler.linear(1.3)),
          child: const JobsLandingScreenV2(),
        ),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Search'), findsOneWidget);
      expect(find.textContaining('Search any place'), findsNothing);
      expect(find.textContaining('Showing near you'), findsNothing);
      c.pickPin(30.1, 78.2, 'Rishikesh');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Rishikesh'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 600));
      expect(c.searchPin.value, isNull);
      expect(t.takeException(), isNull);
    });
  });

  group('screen', () {
    for (final w in [300.0, 560.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('list with far label @${w.toInt()} x$scale', (t) async {
          Get.put<TabConfigController>(_Tabs());
          final f = _Fake();
          f.answer = (_) => NearbyPage(
                items: [
                  JobFeedItem.fromJson(_json('a', km: 420, label: 'far', city: 'Haldwani')),
                  JobFeedItem.fromJson(_json('b', km: 3, label: 'near', city: 'Nainital')),
                ],
                header: const NearbyHeader(farAway: true),
              );
          Get.put(_ctrl(f), tag: JobsFeedController.tag);
          setGoldenView(t, Size(w, 900));
          await t.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'WorkSans'),
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, 900), textScaler: TextScaler.linear(scale)),
              child: const JobsLandingScreenV2(),
            ),
          ));
          await t.pump(const Duration(milliseconds: 600));
          expect(find.text('Nearest jobs'), findsOneWidget);
          expect(find.text('Haldwani, Uttarakhand. About 420 km away'), findsOneWidget);
          expect(find.textContaining('near you'), findsNothing);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('empty state', (t) async {
      Get.put<TabConfigController>(_Tabs());
      final f = _Fake()..answer = (_) => const NearbyPage<JobFeedItem>();
      Get.put(_ctrl(f), tag: JobsFeedController.tag);
      setGoldenView(t, const Size(360, 900));
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: const JobsLandingScreenV2(),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('No jobs listed yet'), findsOneWidget);
    });

    testWidgets('thin state shows the closing line', (t) async {
      Get.put<TabConfigController>(_Tabs());
      final f = _Fake();
      Get.put(_ctrl(f), tag: JobsFeedController.tag);
      setGoldenView(t, const Size(360, 900));
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: const JobsLandingScreenV2(),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('That is all we have for now.'), findsOneWidget);
    });

    testWidgets('error state offers retry', (t) async {
      Get.put<TabConfigController>(_Tabs());
      final f = _Fake()..answer = (_) => throw StateError('x');
      Get.put(_ctrl(f), tag: JobsFeedController.tag);
      setGoldenView(t, const Size(360, 900));
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: const JobsLandingScreenV2(),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Could not load the list'), findsOneWidget);
    });

    test('v2 files carry no Ask for a price and no hardcoded colour', () {
      for (final n in ['jobs_feed_repository', 'jobs_feed_controller', 'jobs_city_sheet_v2', 'jobs_filter_sheet_v2', 'jobs_landing_screen_v2']) {
        final src = File('lib/features/jobs/v2/$n.dart').readAsStringSync();
        expect(src.contains('Ask for a price'), isFalse, reason: n);
        expect(src.contains('Color(0x'), isFalse, reason: n);
      }
    });
  });
}
