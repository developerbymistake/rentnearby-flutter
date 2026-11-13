import 'dart:async';
import 'dart:ui' as ui;

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/jobs/controllers/my_jobs_controller.dart';
import 'package:bakhli/features/jobs/controllers/post_job_controller.dart';
import 'package:bakhli/features/jobs/models/job_experience_bucket.dart';
import 'package:bakhli/features/jobs/models/job_lookups_model.dart';
import 'package:bakhli/features/jobs/models/my_job_model.dart';
import 'package:bakhli/features/jobs/screens/job_detail_screen.dart';
import 'package:bakhli/features/jobs/screens/my_jobs_screen.dart';
import 'package:bakhli/features/jobs/screens/post_job_screen.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/jobs/v2/jobs_landing_screen_v2.dart';
import 'package:bakhli/features/jobs/widgets/my_job_card.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\jobs';

final _ago = DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();

Map<String, dynamic> _job(String id, String title, String role, String stay, String city, int min, int max,
        {int years = 0, String type = 'Full time', String salaryType = 'Monthly', double km = 2, String label = 'near', Duration age = const Duration(hours: 2)}) =>
    {
      'id': id,
      'stayName': stay,
      'title': title,
      'roleName': role,
      'jobTypeName': type,
      'salaryTypeName': salaryType,
      'minimumExperienceYears': years,
      'minSalary': min,
      'maxSalary': max,
      'createdAt': DateTime.now().subtract(age).toIso8601String(),
      'distanceKm': km,
      'labelKey': label,
      'cityName': city,
      'stateName': 'Uttarakhand',
    };

List<JobFeedItem> _feed() => [
      JobFeedItem.fromJson(_job('a', 'Cook for homestay', 'Cook', 'Deodar Cottage', 'Nainital', 12000, 15000, label: 'inCity')),
      JobFeedItem.fromJson(_job('b', 'Front desk executive', 'Receptionist', 'Lakeside Rooms', 'Nainital', 15000, 20000, years: 2, age: const Duration(days: 1))),
      JobFeedItem.fromJson(_job('c', 'Housekeeping staff', 'Housekeeper', 'Pine Ridge Stay', 'Bhimtal', 10000, 12000, years: 1, type: 'Seasonal', km: 9, age: const Duration(days: 3))),
    ];

final _lookups = JobLookups.fromJson({
  'departments': [
    for (final (i, n) in ['Kitchen', 'Housekeeping', 'Front office', 'Maintenance', 'Garden', 'Driver', 'Security'].indexed) {'id': 'd$i', 'name': n},
  ],
  'roles': [
    {'id': 'r0', 'name': 'Cook', 'jobDepartmentId': 'd0'},
  ],
  'jobTypes': [
    {'id': 't0', 'name': 'Full time'},
    {'id': 't1', 'name': 'Part time'},
    {'id': 't2', 'name': 'Seasonal'},
  ],
  'shiftTypes': [
    {'id': 's0', 'name': 'Day Shift'},
    {'id': 's1', 'name': 'Night Shift'},
    {'id': 's2', 'name': 'Rotational'},
  ],
  'salaryTypes': [
    {'id': 'm0', 'name': 'Monthly'},
    {'id': 'm1', 'name': 'Daily'},
    {'id': 'm2', 'name': 'Hourly'},
  ],
});

TripCityModel _city(int k, String n, String d, String state) =>
    TripCityModel(cityKey: k, name: n, districtName: d, stateName: state, latitude: 29.4, longitude: 79.4, status: TripCityStatus.ready);

class _Catalog extends TripCityCatalog {
  _Catalog({this.data = true, this.fail = false, this.hold = false});
  final bool data;
  final bool fail;
  final bool hold;
  final list = [
    _city(1, 'Nainital', 'Nainital', 'Uttarakhand'),
    _city(2, 'Bhimtal', 'Nainital', 'Uttarakhand'),
    _city(3, 'Almora', 'Almora', 'Uttarakhand'),
    _city(4, 'Mukteshwar', 'Nainital', 'Uttarakhand'),
    _city(5, 'Kausani', 'Bageshwar', 'Uttarakhand'),
    _city(6, 'Ranikhet', 'Almora', 'Uttarakhand'),
    _city(7, 'Manali', 'Kullu', 'Himachal Pradesh'),
  ];
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => data;
  @override
  List<String> liveStates() => ['Uttarakhand', 'Himachal Pradesh'];
  @override
  Future<List<TripCityModel>> load({bool force = false}) {
    if (hold) return Completer<List<TripCityModel>>().future;
    if (fail) return Future.error(StateError('x'));
    return Future.value(list);
  }

  @override
  List<TripCityModel> ready(String q, {String? stateName}) =>
      [for (final c in list) if ((stateName == null || c.stateName == stateName) && c.name.toLowerCase().contains(q.trim().toLowerCase())) c];
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get paymentEnabled => true;
}

class _Report extends ReportController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _MyJobs extends MyJobsController {
  _MyJobs(this.initial, {this.fail = false, this.holding = false});
  final MyJobsPage? initial;
  final bool fail;
  final bool holding;
  @override
  // ignore: must_call_super
  void onInit() {
    if (holding) {
      isLoading.value = true;
      return;
    }
    page.value = initial;
    hasLoaded.value = initial != null;
    loadFailed.value = fail;
  }

  @override
  Future<void> load() async {}
}

MyJobModel _mine(String id, String title, String role, int min, int max, {int years = 0, bool active = true, Duration age = const Duration(hours: 2), String salaryType = 'Monthly'}) =>
    MyJobModel.fromJson({
      'id': id,
      'title': title,
      'roleName': role,
      'minimumExperienceYears': years,
      'salaryTypeName': salaryType,
      'stayName': 'Deodar Cottage',
      'minSalary': min,
      'maxSalary': max,
      'status': active ? 'Active' : 'Closed',
      'createdAt': DateTime.now().subtract(age).toIso8601String(),
    });

final _three = [
  _mine('a', 'Cook for homestay', 'Cook', 12000, 15000),
  _mine('b', 'Front desk executive', 'Receptionist', 15000, 20000, years: 2, age: const Duration(days: 1)),
  _mine('c', 'Housekeeping staff', 'Housekeeper', 10000, 12000, years: 1, active: false, age: const Duration(days: 21)),
];

Future<ui.Image> _photo() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 400, 300), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 300), const [Color(0xFF7FB6D9), Color(0xFFD9E6EE), Color(0xFF2B7FA3)], const [0, 0.5, 0.55]));
  return rec.endRecording().toImage(400, 300);
}

Map<String, dynamic> _detailJson({bool active = true, bool reported = false, bool owner = false, String? photo}) => {
      'id': 'j1',
      'stayListingId': 's1',
      'stayName': active ? 'Deodar Cottage' : 'Pine Ridge Stay',
      'coverPhotoUrl': photo,
      'title': active ? 'Cook for homestay' : 'Housekeeping staff',
      'roleName': active ? 'Cook' : 'Housekeeper',
      'jobTypeName': active ? 'Full time' : 'Seasonal',
      'shiftTypeName': 'Day Shift',
      'salaryTypeName': 'Monthly',
      'minimumExperienceYears': active ? 0 : 1,
      'minSalary': active ? 12000 : 10000,
      'maxSalary': active ? 15000 : 12000,
      'cityName': active ? 'Nainital' : 'Bhimtal',
      'districtName': active ? 'Nainital' : 'Nainital',
      'createdAt': _ago,
      'description': active
          ? 'Cook simple North Indian meals for up to 20 guests. Breakfast and dinner. Food and a shared room are given. Two days off a month.'
          : 'Clean rooms and common areas. Change linen daily. Season job from March to June.',
      'contactPhone': '9876543210',
      'whatsAppNumber': '9876543210',
      'status': active ? 'Active' : 'Closed',
      'ownerUserId': 'o1',
      'isOwner': owner,
      'hasReportedStay': reported,
    };

const _sizes = <(String, Size, double)>[
  ('1.0_360', Size(360, 800), 1.0),
  ('1.3_360', Size(360, 800), 1.3),
  ('1.0_300', Size(300, 800), 1.0),
];

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
}

JobsFeedController _feedCtrl({NearbyPage<JobFeedItem> Function()? answer, Completer<NearbyPage<JobFeedItem>>? hold, bool fail = false}) =>
    JobsFeedController(
      fetch: ({int? cityKey, double? lat, double? lng, String? departmentId, int? minExperience, int? maxExperience, int? minSalary, String? pageToken, int pageSize = 20}) {
        if (hold != null) return hold.future;
        if (fail) return Future.error(StateError('x'));
        return Future.value(answer?.call() ?? NearbyPage(items: _feed(), hasMore: true));
      },
      gps: () => (lat: 29.4, lng: 79.4),
      lookupsLoader: () async => _lookups,
    );

Future<void> _tapv(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(f);
}

Future<void> _toast(WidgetTester t, String msg) async {
  await t.pump(const Duration(milliseconds: 300));
  toastification.dismissAll(delayForAnimation: false);
  expect(ToastLane.showInHost(ToastKind.error, msg), isTrue);
  await t.pump(const Duration(milliseconds: 400));
  expect(find.text(msg), findsOneWidget);
}

Future<void> _toTop(WidgetTester t) async {
  await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 3000));
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void _base() {
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth());
  Get.put<PlanController>(_Plan());
  Get.put<ReportController>(_Report());
}

void main() {
  setUpAll(() async {
    shotsDir = _dir;
    await loadRealFonts();
  });
  tearDown(Get.reset);

  group('landing', () {
    Future<JobsFeedController> open(WidgetTester t, {Size size = const Size(360, 800), double scale = 1, JobsFeedController? ctrl, bool city = true, _Catalog? catalog}) async {
      _base();
      Get.put<TripCityCatalog>(catalog ?? _Catalog(), permanent: true);
      final c = Get.put(ctrl ?? _feedCtrl(), tag: JobsFeedController.tag);
      await pumpPhone(t, const JobsLandingScreenV2(), size: size, textScale: scale);
      if (city) c.pickCity(_city(1, 'Nainital', 'Nainital', 'Uttarakhand'));
      await t.pump(const Duration(milliseconds: 300));
      return c;
    }

    for (final (tag, size, scale) in _sizes) {
      testWidgets('land $tag', (t) async {
        debugDisableShadows = false;
        final c = await open(t, size: size, scale: scale);
        c.isLoadingMore.value = true;
        await _snap(t, 'land_$tag');
        expect(find.text('Cook for homestay'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    testWidgets('land_pin', (t) async {
      debugDisableShadows = false;
      final c = await open(t, ctrl: _feedCtrl(answer: () => NearbyPage(items: _feed().sublist(1, 3), header: const NearbyHeader(centreCityName: 'Nainital', centreCityKm: 3))));
      c.pickPin(29.39, 79.45, 'Mall Road, Nainital');
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'land_pin');
      expect(find.text('Cancel'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 300));
      expect(c.searchPin.value, isNull);
      debugDisableShadows = true;
    });

    testWidgets('land_filt', (t) async {
      debugDisableShadows = false;
      final c = await open(t);
      c.applyFilters(departmentId: 'd0', experience: JobExperienceBucket.all.first, minSalary: 10000);
      await t.pump(const Duration(milliseconds: 300));
      c.loadMoreFailed.value = true;
      await _snap(t, 'land_filt');
      expect(find.text('Kitchen'), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('land_load', (t) async {
      debugDisableShadows = false;
      await open(t, ctrl: _feedCtrl(hold: Completer()), city: false);
      await _snap(t, 'land_load');
      expect(find.text('My location'), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('land_empty', (t) async {
      debugDisableShadows = false;
      await open(t, ctrl: _feedCtrl(answer: () => const NearbyPage<JobFeedItem>()));
      await _snap(t, 'land_empty');
      expect(find.text('No jobs listed yet'), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('land_error', (t) async {
      debugDisableShadows = false;
      final c = await open(t, ctrl: _feedCtrl(fail: true));
      await _snap(t, 'land_error');
      expect(find.text('Could not load the list'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(c.loadFailed.value, isTrue);
      debugDisableShadows = true;
    });

    testWidgets('sh_opt and pick', (t) async {
      debugDisableShadows = false;
      final c = await open(t);
      await t.tap(find.text('Department'));
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'sh_opt');
      await t.tap(find.text('Kitchen'));
      await t.pump(const Duration(milliseconds: 600));
      expect(c.selectedDepartmentId.value, 'd0');
      debugDisableShadows = true;
    });

    testWidgets('sh_filter', (t) async {
      debugDisableShadows = false;
      final c = await open(t);
      await t.tap(find.text('Filter'));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 1200));
      await t.tap(find.descendant(of: find.byType(Sheet3D), matching: find.text('Fresher')));
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'sh_filter');
      await t.tap(find.text('Apply'));
      await t.pump(const Duration(milliseconds: 600));
      expect(c.selectedExperience.value, isNotNull);
      debugDisableShadows = true;
    });

    for (final (name, cat, query) in [
      ('sh_city', _Catalog(), null),
      ('sh_city_load', _Catalog(data: false, hold: true), null),
      ('sh_city_none', _Catalog(), 'Nanital xyz'),
      ('sh_city_fail', _Catalog(data: false, fail: true), null),
    ]) {
      testWidgets(name, (t) async {
        debugDisableShadows = false;
        await open(t, catalog: cat);
        await t.tap(find.text('Nainital, Uttarakhand'));
        await t.pump(const Duration(milliseconds: 600));
        if (query != null) {
          await t.enterText(find.byType(TextField), query);
          await t.pump(const Duration(milliseconds: 300));
        }
        await _snap(t, name);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }
  });

  group('detail', () {
    Future<void> open(WidgetTester t, Map<String, dynamic>? json, {Size size = const Size(360, 800), double scale = 1, int code = 200, bool hold = false}) async {
      _base();
      installFakeApi([
        FakeRoute('GET', '/stay-jobs/{id}', (_) => json, code: code),
      ]);
      await pumpPhone(t, const SizedBox(), size: size, textScale: scale);
      Get.to(() => const JobDetailScreen(), arguments: {'id': 'j1'});
      await t.pump();
      if (!hold) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 600));
      }
    }

    for (final (tag, size, scale) in _sizes) {
      testWidgets('detail $tag', (t) async {
        debugDisableShadows = false;
        await open(t, _detailJson(), size: size, scale: scale);
        await _snap(t, 'detail_$tag');
        expect(find.text('Call'), findsOneWidget);
        expect(find.text('Report this stay'), findsOneWidget);
        expect(find.text('Fresher. No experience needed'), findsNothing);
        debugDisableShadows = true;
      });
    }

    for (final (tag, size, scale) in _sizes) {
      testWidgets('detail_photo_screen $tag', (t) async {
        debugDisableShadows = false;
        final img = (await t.runAsync(_photo))!;
        JobDetailScreen.photoOverride = (_) => RawImage(key: const ValueKey('job-photo'), image: img, fit: BoxFit.cover);
        addTearDown(() => JobDetailScreen.photoOverride = null);
        await open(t, _detailJson(photo: 'https://x/p.jpg'), size: size, scale: scale);
        await _snap(t, 'detail_photo_screen_$tag');
        expect(find.byKey(const ValueKey('job-photo')), findsOneWidget);
        expect(find.textContaining('₹12K - 15K', findRichText: true), findsOneWidget);
        expect(find.text('Call'), findsOneWidget);
        expect(t.takeException(), isNull);
        debugDisableShadows = true;
      });
    }

    testWidgets('detail_scroll', (t) async {
      debugDisableShadows = false;
      await open(t, _detailJson());
      await scrollShots(t, find.byType(JobDetailScreen), 'detail_scroll', [0, 260, 900]);
      debugDisableShadows = true;
    });

    testWidgets('detail_closed', (t) async {
      debugDisableShadows = false;
      await open(t, _detailJson(active: false));
      await _snap(t, 'detail_closed');
      expect(find.text('This job is closed'), findsOneWidget);
      expect(find.text('Call'), findsNothing);
      debugDisableShadows = true;
    });

    testWidgets('detail_reported', (t) async {
      debugDisableShadows = false;
      await open(t, _detailJson(reported: true));
      await _snap(t, 'detail_reported');
      debugDisableShadows = true;
    });

    testWidgets('detail_owner', (t) async {
      debugDisableShadows = false;
      await open(t, _detailJson(owner: true));
      await _snap(t, 'detail_owner');
      expect(find.text('Report this stay'), findsNothing);
      debugDisableShadows = true;
    });

    testWidgets('detail_load', (t) async {
      debugDisableShadows = false;
      await open(t, _detailJson(), hold: true);
      await shot(t, 'detail_load');
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 600));
      debugDisableShadows = true;
    });

    testWidgets('detail_404', (t) async {
      debugDisableShadows = false;
      await open(t, null, code: 404);
      await _snap(t, 'detail_404');
      expect(find.text('Job not found'), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('detail_err', (t) async {
      debugDisableShadows = false;
      await open(t, null, code: 500);
      await _snap(t, 'detail_err');
      expect(find.text('Retry'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });
  });

  group('my jobs', () {
    Future<void> open(WidgetTester t, _MyJobs ctrl, {Size size = const Size(360, 800), double scale = 1}) async {
      _base();
      Get.put<MyJobsController>(ctrl);
      await pumpPhone(t, const MyJobsScreen(), size: size, textScale: scale);
      await t.pump(const Duration(milliseconds: 300));
    }

    for (final (tag, size, scale) in _sizes) {
      testWidgets('my $tag', (t) async {
        debugDisableShadows = false;
        await open(t, _MyJobs(MyJobsPage(items: _three, activeCount: 2, maxActive: 3, stayStatus: 'Approved', canPost: true)), size: size, scale: scale);
        await _snap(t, 'my_$tag');
        expect(find.text('2 of 3 active'), findsOneWidget);
        expect(find.byKey(const ValueKey('jobs_content')), findsOneWidget);
        debugDisableShadows = true;
      });
    }

    testWidgets('my_close dialog', (t) async {
      debugDisableShadows = false;
      await open(t, _MyJobs(MyJobsPage(items: _three, activeCount: 2, maxActive: 3, stayStatus: 'Approved', canPost: true)));
      await t.tap(find.text('Close').first);
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'my_close');
      expect(find.text('Close this job?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 600));
      debugDisableShadows = true;
    });

    testWidgets('my_updating', (t) async {
      debugDisableShadows = false;
      final c = _MyJobs(MyJobsPage(items: _three, activeCount: 2, maxActive: 3, stayStatus: 'Approved', canPost: true));
      await open(t, c);
      c.isSaving.value = true;
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, 'my_updating');
      c.isSaving.value = false;
      await t.pump(const Duration(milliseconds: 300));
      debugDisableShadows = true;
    });

    testWidgets('post_done', (t) async {
      debugDisableShadows = false;
      final items = [_mine('n', 'Kitchen helper', 'Kitchen helper', 400, 400, age: Duration.zero, salaryType: 'Daily'), ..._three.take(2)];
      await open(t, _MyJobs(MyJobsPage(items: items, activeCount: 3, maxActive: 3, stayStatus: 'Approved', canPost: false)));
      await t.runAsync(() async {});
      final shown = ToastLane.showInHost(ToastKind.success, 'Job posted.');
      await t.pump(const Duration(milliseconds: 400));
      await shot(t, 'post_done');
      expect(shown, isTrue);
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });

    for (final (name, page) in [
      ('my_empty', const MyJobsPage(items: [], activeCount: 0, maxActive: 3, stayStatus: 'Approved', canPost: true)),
      ('my_block', const MyJobsPage(items: [], activeCount: 0, maxActive: 3, stayStatus: 'Draft', canPost: false)),
      ('my_limit', const MyJobsPage(items: [], activeCount: 0, maxActive: 0, stayStatus: 'Approved', canPost: false)),
    ]) {
      testWidgets(name, (t) async {
        debugDisableShadows = false;
        await open(t, _MyJobs(page));
        await _snap(t, name);
        expect(find.text('No jobs yet'), findsOneWidget);
        debugDisableShadows = true;
      });
    }

    testWidgets('my_load', (t) async {
      debugDisableShadows = false;
      await open(t, _MyJobs(null, holding: true));
      await shot(t, 'my_load');
      expect(find.byKey(const ValueKey('jobs_skeleton')), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('my_err', (t) async {
      debugDisableShadows = false;
      await open(t, _MyJobs(null, fail: true));
      await _snap(t, 'my_err');
      expect(find.text("Couldn't load jobs"), findsOneWidget);
      debugDisableShadows = true;
    });

    test('close confirm keeps its api', () => expect(MyJobCard.confirmClose, isA<Function>()));
  });

  group('post job', () {
    Future<void> open(WidgetTester t, {Size size = const Size(360, 800), double scale = 1, Map<String, dynamic>? mine, bool failLookups = false, bool hold = false}) async {
      _base();
      Get.find<AuthController>().user.value = UserModel.fromJson({'id': 'u1', 'phoneNumber': '+919876543210', 'createdAt': '2026-01-01T00:00:00Z'});
      installFakeApi([
        FakeRoute('GET', '/stay-jobs/lookups', (_) => {
              'departments': [for (final d in _lookups.departments) {'id': d.id, 'name': d.name}],
              'roles': [
                {'id': 'r0', 'name': 'Cook', 'jobDepartmentId': 'd0'},
              ],
              'jobTypes': [for (final d in _lookups.jobTypes) {'id': d.id, 'name': d.name}],
              'shiftTypes': [for (final d in _lookups.shiftTypes) {'id': d.id, 'name': d.name}],
              'salaryTypes': [for (final d in _lookups.salaryTypes) {'id': d.id, 'name': d.name}],
            }, code: failLookups ? 500 : 200),
        FakeRoute.value('GET', '/stay-jobs/me', mine ?? {'items': [], 'activeCount': 0, 'maxActive': 3, 'stayStatus': 'Approved', 'canPost': true}),
      ]);
      await pumpPhone(t, const PostJobScreen(), size: size, textScale: scale);
      if (!hold) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 600));
      }
    }

    Future<void> next(WidgetTester t) async {
      await _tapv(t, find.textContaining('Next:').last);
      await t.pump(const Duration(milliseconds: 600));
    }

    for (final (tag, size, scale) in _sizes) {
      testWidgets('post1 $tag', (t) async {
        debugDisableShadows = false;
        await open(t, size: size, scale: scale);
        await _snap(t, 'post1_$tag');
        expect(find.byKey(const ValueKey('stagger0')), findsOneWidget);
        debugDisableShadows = true;
      });
    }

    testWidgets('post1_err toast', (t) async {
      debugDisableShadows = false;
      await open(t);
      await next(t);
      expect(Get.find<PostJobController>().step.value, 0);
      await _toast(t, 'Please enter the job title');
      await _snap(t, 'post1_err');
      expect(find.text('Please enter the job title'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });

    testWidgets('post flow 1 to 3', (t) async {
      debugDisableShadows = false;
      await open(t);
      await t.enterText(find.byType(TextFormField).at(0), 'Cook for homestay');
      await t.enterText(find.byType(TextFormField).at(1), 'Cook simple North Indian meals for up to 20 guests. Food and room given.');
      await _tapv(t, find.text('Select').first);
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'post_dept');
      await _tapv(t, find.text('Kitchen'));
      await t.pump(const Duration(milliseconds: 600));
      await next(t);
      expect(Get.find<PostJobController>().step.value, 0);
      await _toast(t, 'Please select a job role');
      await _snap(t, 'post1_err2');
      expect(find.text('Please select a job role'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
      await _tapv(t, find.text('Select').last);
      await t.pump(const Duration(milliseconds: 600));
      await _tapv(t, find.text('Cook'));
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'post1_filled');
      await next(t);
      await _snap(t, 'post2_empty');
      await _tapv(t, find.text('Monthly'));
      await t.enterText(find.byType(TextFormField).at(0), '12000');
      await t.enterText(find.byType(TextFormField).at(1), '9000');
      await t.pump(const Duration(milliseconds: 300));
      await next(t);
      expect(Get.find<PostJobController>().step.value, 1);
      await _toast(t, 'Max salary must be at least the min salary');
      await _snap(t, 'post2_err');
      expect(find.text('Max salary must be at least the min salary'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
      await t.enterText(find.byType(TextFormField).at(1), '15000');
      await _tapv(t, find.text('Select'));
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'post2_exp');
      await _tapv(t, find.text('Fresher'));
      await t.pump(const Duration(milliseconds: 600));
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump(const Duration(milliseconds: 300));
      await _toTop(t);
      await _snap(t, 'post2');
      await next(t);
      final phone = Get.find<PostJobController>().phoneCtrl.text;
      Get.find<PostJobController>().phoneCtrl.clear();
      await _tapv(t, find.text('Same as my login number'));
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'post3_empty');
      expect(Get.find<PostJobController>().sameAsPhone.value, isFalse);
      await _tapv(t, find.text('Same as my login number'));
      Get.find<PostJobController>().phoneCtrl.text = phone;
      await _tapv(t, find.text('Full time'));
      await _tapv(t, find.text('Day'));
      await t.pump(const Duration(milliseconds: 300));
      await _toTop(t);
      await _snap(t, 'post3');
      await t.enterText(find.byType(TextFormField).at(0), '987654321');
      await _tapv(t, find.text('Post Job'));
      await t.pump(const Duration(milliseconds: 600));
      await _toast(t, 'Enter a valid 10-digit mobile number');
      await _snap(t, 'post3_err');
      expect(find.text('Enter a valid 10-digit mobile number'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
      await _tapv(t, find.text('Back'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('stagger1')), findsOneWidget);
      await _tapv(t, find.byTooltip('Back').first);
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 'post_discard');
      expect(find.text('Discard Job?'), findsOneWidget);
      await _tapv(t, find.text('Keep Editing'));
      await t.pump(const Duration(milliseconds: 600));
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });

    testWidgets('post_block', (t) async {
      debugDisableShadows = false;
      await open(t, mine: {'items': [], 'activeCount': 3, 'maxActive': 3, 'stayStatus': 'Approved', 'canPost': false});
      await _snap(t, 'post_block');
      expect(find.text('Your plan allows 3 active jobs. Close one or upgrade.'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);
      debugDisableShadows = true;
    });

    testWidgets('post_load', (t) async {
      debugDisableShadows = false;
      await open(t, hold: true);
      await shot(t, 'post_load');
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });

    testWidgets('post_fail', (t) async {
      debugDisableShadows = false;
      await open(t, failLookups: true);
      await _snap(t, 'post_fail');
      expect(find.text("Couldn't load the form"), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
    });

    testWidgets('post3_posting', (t) async {
      debugDisableShadows = false;
      await open(t);
      final c = Get.find<PostJobController>();
      c.step.value = 2;
      c.isSubmitting.value = true;
      await t.pump(const Duration(milliseconds: 400));
      await shot(t, 'post3_posting');
      c.isSubmitting.value = false;
      await t.pump(const Duration(milliseconds: 300));
      debugDisableShadows = true;
    });
  });
}
