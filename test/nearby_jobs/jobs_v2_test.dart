import 'dart:async';
import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/jobs/models/job_lookups_model.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/jobs/v2/jobs_landing_screen_v2.dart';
import 'package:bakhli/features/nearby/data/nearby_repository_base.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
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

    test('stale response is dropped', () async {
      final f = _Fake();
      f.hold = Completer();
      final c = Get.put(_ctrl(f), tag: JobsFeedController.tag);
      await Future<void>.delayed(Duration.zero);
      final first = f.hold!;
      f.hold = null;
      f.answer = (_) => NearbyPage(items: [_item('new')]);
      c.pickPin(30.1, 78.2, 'Almora');
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

    testWidgets('header is one Stays-style place pill with a clear X, no Search or Cancel button', (t) async {
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
      expect(find.text('Search a place'), findsOneWidget);
      expect(find.text('Search'), findsNothing);
      expect(find.bySemanticsLabel('Back to my location'), findsNothing);
      expect(find.textContaining('Search any place'), findsNothing);
      expect(find.textContaining('Showing near you'), findsNothing);
      c.pickPin(30.1, 78.2, 'Rishikesh');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Rishikesh'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Back to my location'));
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
      for (final n in ['jobs_feed_repository', 'jobs_feed_controller', 'jobs_filter_sheet_v2', 'jobs_landing_screen_v2']) {
        final src = File('lib/features/jobs/v2/$n.dart').readAsStringSync();
        expect(src.contains('Ask for a price'), isFalse, reason: n);
        expect(src.contains('Color(0x'), isFalse, reason: n);
      }
    });
  });
}
