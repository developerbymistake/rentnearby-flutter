import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_today_cache.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_strings_sync.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/trip_lifecycle_actions.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _loadedAt = '2026-11-19T10:00:00.123456Z';
const _otherSaveAt = '2026-11-19T10:05:00.654321Z';

class _VersionApi implements HttpClientAdapter {
  _VersionApi({required this.serverTrip, this.putErrors = const [], this.offline = false});

  final Map<String, dynamic> serverTrip;
  final List<String> putErrors;
  final bool offline;
  final List<RequestOptions> seen = [];

  int count(String method) => seen.where((o) => o.method.toUpperCase() == method && o.path == '/trips/t1').length;

  List<Map<String, dynamic>> get putBodies => [
        for (final o in seen)
          if (o.method.toUpperCase() == 'PUT') Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) : o.data as Map),
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    if (offline) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    final json = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    final method = options.method.toUpperCase();
    if (method == 'PUT' && options.path == '/trips/t1') {
      final n = count('PUT');
      if (n <= putErrors.length) {
        final type = putErrors[n - 1];
        return ResponseBody.fromString(
            jsonEncode({'status': '409', 'code': 409, 'error': {'message': 'Changed', 'type': type}}), 409,
            headers: json);
      }
      final body = putBodies.last;
      return ResponseBody.fromString(
          jsonEncode({'status': '200', 'code': 200, 'data': {...serverTrip, 'plan': body['plan'], 'updatedAt': '2026-11-19T10:06:00Z'}}),
          200,
          headers: json);
    }
    if (method == 'GET' && options.path == '/trips/t1') {
      return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': serverTrip}), 200, headers: json);
    }
    return ResponseBody.fromString(
        jsonEncode({'status': '503', 'code': 503, 'error': {'message': 'Down', 'type': 'Down'}}), 503,
        headers: json);
  }

  @override
  void close({bool force = false}) {}
}

TripPlan _moved(TripPlan plan) => plan.copyWith(days: [
      plan.days[0].copyWith(spots: [...plan.days[0].spots, ...plan.days[1].spots]),
      plan.days[1].copyWith(spots: const []),
    ]);

Future<void> _until(bool Function() done) async {
  final sw = Stopwatch()..start();
  while (!done() && sw.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('save_version_gs').path);
    await GetStorage.init();
  });
  setUp(() {
    StorageService.clearTripPending('t1');
    StorageService.clearTripCache('t1');
  });
  tearDown(Get.reset);

  test('save_sends_the_updated_at_it_loaded_and_the_next_save_sends_the_new_one', () async {
    final plan = enginePlan([[2, 2]]);
    ApiService.init();
    final api = _VersionApi(serverTrip: engineTripJson(plan, extra: {'updatedAt': _loadedAt}));
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(plan);
    c.trip.value = c.trip.value!.copyWith(updatedAt: DateTime.parse(_loadedAt));

    c.plan.value = _moved(plan);
    expect(await c.saveNow(), isTrue);
    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);

    c.plan.value = plan;
    expect(await c.saveNow(), isTrue);
    expect(api.putBodies.last['baseUpdatedAt'], '2026-11-19T10:06:00.000Z');
  });

  test('a_save_refused_as_changed_elsewhere_reloads_the_latest_plan_and_does_not_resend', () async {
    final local = enginePlan([[2, 2]]);
    final other = enginePlan([[1], [1], [1]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(other, extra: {'updatedAt': _otherSaveAt}),
      putErrors: ['TripChanged'],
    );
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(local);
    c.trip.value = c.trip.value!.copyWith(updatedAt: DateTime.parse(_loadedAt));
    c.plan.value = _moved(local);

    expect(await c.saveNow(), isFalse);
    await _until(() => c.trip.value?.updatedAt == DateTime.parse(_otherSaveAt) && !c.isOpening.value);

    expect(api.count('PUT'), 1);
    expect(api.count('GET'), 1);
    expect(jsonEncode([for (final d in c.plan.value!.days) d.toJson()]), jsonEncode([for (final d in other.days) d.toJson()]));
    expect(c.saveFailed.value, isFalse);
    expect(StorageService.getTripPending('t1'), isNull);

    c.plan.value = c.plan.value!.copyWith(days: [c.plan.value!.days[0], c.plan.value!.days[1]]);
    await c.saveNow();
    expect(api.putBodies.last['baseUpdatedAt'], _otherSaveAt);
  });

  test('concurrent_update_retries_once_with_the_same_base_without_a_reload', () async {
    final plan = enginePlan([[2, 2]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(plan, extra: {'updatedAt': _loadedAt}),
      putErrors: ['CONCURRENT_UPDATE'],
    );
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(plan);
    c.trip.value = c.trip.value!.copyWith(updatedAt: DateTime.parse(_loadedAt));
    c.plan.value = _moved(plan);

    expect(await c.saveNow(), isTrue);
    expect(api.count('PUT'), 2);
    expect(api.count('GET'), 0);
    expect([for (final b in api.putBodies) b['baseUpdatedAt']], [_loadedAt, _loadedAt]);
  });

  test('concurrent_update_then_changed_elsewhere_ends_in_the_reload', () async {
    final plan = enginePlan([[2, 2]]);
    final other = enginePlan([[1], [1], [1]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(other, extra: {'updatedAt': _otherSaveAt}),
      putErrors: ['CONCURRENT_UPDATE', 'TripChanged'],
    );
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(plan);
    c.trip.value = c.trip.value!.copyWith(updatedAt: DateTime.parse(_loadedAt));
    c.plan.value = _moved(plan);

    expect(await c.saveNow(), isFalse);
    await _until(() => c.trip.value?.updatedAt == DateTime.parse(_otherSaveAt) && !c.isOpening.value);
    expect(api.count('PUT'), 2);
    expect(c.plan.value!.days.length, other.days.length);
  });

  Map<String, dynamic> lockedTrip(TripPlan plan, String updatedAt) => engineTripJson(plan, extra: {
        'updatedAt': updatedAt,
        'planLock': {'locked': true, 'reason': lockedByRequest.reason, 'requestId': lockedByRequest.requestId},
      });

  Future<TripPlanController> openWithPending(_VersionApi api, TripPlan local, TripPlan pending, DateTime? base) async {
    ApiService.init();
    ApiService.dio.httpClientAdapter = api;
    StorageService.saveTripPending('t1', plan: pending.toJson(), baseUpdatedAt: base);
    final c = engineRig(local);
    await c.open('t1', fresh: true);
    return c;
  }

  String daysOf(TripPlan p) => jsonEncode([for (final d in p.days) d.toJson()]);

  test('an_older_offline_copy_is_never_sent_and_the_newer_server_plan_is_shown', () async {
    final local = enginePlan([[2, 2]]);
    final other = enginePlan([[1], [1], [1]]);
    final api = _VersionApi(serverTrip: engineTripJson(other, extra: {'updatedAt': _otherSaveAt}));
    final c = await openWithPending(api, local, _moved(local), DateTime.parse(_loadedAt));

    expect(api.count('PUT'), 0);
    expect(daysOf(c.plan.value!), daysOf(other));
    expect(c.saveFailed.value, isFalse);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, TripStringsSync.changedElsewhereNotSaved);

    expect(await c.retrySave(), isTrue);
    expect(api.putBodies.single['baseUpdatedAt'], _otherSaveAt);
    expect(daysOf(TripPlan.fromJson(api.putBodies.single['plan'] as Map<String, dynamic>)), daysOf(other));
  });

  test('an_offline_copy_without_a_base_is_never_sent', () async {
    final local = enginePlan([[2, 2]]);
    final api = _VersionApi(serverTrip: engineTripJson(local, extra: {'updatedAt': _loadedAt}));
    final c = await openWithPending(api, local, _moved(local), null);

    expect(api.count('PUT'), 0);
    expect(daysOf(c.plan.value!), daysOf(local));
    expect(c.saveFailed.value, isFalse);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, TripStringsSync.olderEditNotSaved);
  });

  test('an_offline_copy_on_the_same_version_is_sent_with_its_base', () async {
    final local = enginePlan([[2, 2]]);
    final api = _VersionApi(serverTrip: engineTripJson(local, extra: {'updatedAt': _loadedAt}));
    final c = await openWithPending(api, local, _moved(local), DateTime.parse(_loadedAt));
    await _until(() => api.count('PUT') == 1 && !c.isSaving.value);

    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    expect(daysOf(c.plan.value!), daysOf(_moved(local)));
    expect(c.lastToast, isNull);
    expect(StorageService.getTripPending('t1'), isNull);
  });

  test('a_locked_plan_drops_a_pending_layout_edit_with_one_line_and_no_retry', () async {
    final local = enginePlan([[2, 2]]);
    final api = _VersionApi(serverTrip: lockedTrip(local, _loadedAt));
    final c = await openWithPending(api, local, _moved(local), DateTime.parse(_loadedAt));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(c.isPlanLocked, isTrue);
    expect(api.count('PUT'), 0);
    expect(daysOf(c.plan.value!), daysOf(local));
    expect(c.saveFailed.value, isFalse);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, TripStringsSync.lockedNotSaved);
  });

  test('a_locked_plan_drops_an_older_pending_layout_edit_as_locked', () async {
    final local = enginePlan([[2, 2]]);
    final api = _VersionApi(serverTrip: lockedTrip(local, _otherSaveAt));
    final c = await openWithPending(api, local, _moved(local), DateTime.parse(_loadedAt));

    expect(api.count('PUT'), 0);
    expect(c.saveFailed.value, isFalse);
    expect(c.lastToast, TripStringsSync.lockedNotSaved);
  });

  test('a_locked_plan_keeps_a_pending_edit_the_lock_allows', () async {
    final local = enginePlan([[2, 2]]);
    final allowed = local.copyWith(dismissedEnquiryIds: const ['e1']);
    final api = _VersionApi(serverTrip: lockedTrip(local, _loadedAt));
    final c = await openWithPending(api, local, allowed, DateTime.parse(_loadedAt));
    await _until(() => api.count('PUT') == 1 && !c.isSaving.value);

    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    expect(c.plan.value!.dismissedEnquiryIds, ['e1']);
    expect(c.lastToast, isNull);
  });

  test('offline_open_shows_a_pending_copy_only_when_the_lock_allows_it', () async {
    final local = enginePlan([[2, 2]]);
    final api = _VersionApi(serverTrip: lockedTrip(local, _loadedAt), offline: true);
    TripTodayCache.saveTrip(TripModel.fromJson(lockedTrip(local, _loadedAt)));
    final c = await openWithPending(api, local, _moved(local), DateTime.parse(_loadedAt));

    expect(c.offline.value, isTrue);
    expect(daysOf(c.plan.value!), daysOf(local));
    expect(StorageService.getTripPending('t1'), isNotNull);

    TripTodayCache.saveTrip(TripModel.fromJson(engineTripJson(local, extra: {'updatedAt': _loadedAt})));
    await c.open('t1', fresh: true);
    expect(c.offline.value, isTrue);
    expect(daysOf(c.plan.value!), daysOf(_moved(local)));
  });

  test('a_save_left_behind_on_leave_refused_as_changed_drops_the_copy_and_tells_the_user', () async {
    final local = enginePlan([[2, 2]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(local, extra: {'updatedAt': _otherSaveAt}),
      putErrors: ['TripChanged'],
    );
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(local);
    c.trip.value = TripModel.fromJson(engineTripJson(local, extra: {'updatedAt': _loadedAt}));
    c.plan.value = _moved(local);
    c.scheduleSave();
    expect(StorageService.getTripPending('t1'), isNotNull);

    await c.open('t2');
    await _until(() => c.lastToast != null);

    expect(api.count('PUT'), 1);
    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, TripStringsSync.changedElsewhereNotSaved);
  });

  test('a_save_left_behind_on_leave_that_lands_drops_the_copy_so_the_next_open_is_clean', () async {
    final local = enginePlan([[2, 2]]);
    ApiService.init();
    final api = _VersionApi(serverTrip: engineTripJson(local, extra: {'updatedAt': _loadedAt}));
    ApiService.dio.httpClientAdapter = api;
    final c = engineRig(local);
    c.trip.value = TripModel.fromJson(engineTripJson(local, extra: {'updatedAt': _loadedAt}));
    c.plan.value = _moved(local);
    c.scheduleSave();

    await c.open('t2');
    await _until(() => api.count('PUT') == 1 && StorageService.getTripPending('t1') == null);

    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, isNull);
  });

  Future<bool?> saveAndExit(WidgetTester t, List<String> putErrors) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(411, 891);
    addTearDown(t.view.reset);
    final local = enginePlan([[2, 2]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(enginePlan([[1], [1], [1]]), extra: {'updatedAt': _otherSaveAt}),
      putErrors: putErrors,
    );
    ApiService.dio.httpClientAdapter = api;
    late BuildContext ctx;
    await t.pumpWidget(GetMaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    Get.put<TabConfigController>(_Tabs());
    final c = Get.put<TripPlanController>(engineRig(local));
    c.trip.value = c.trip.value!.copyWith(updatedAt: DateTime.parse(_loadedAt));
    c.plan.value = _moved(local);
    c.scheduleSave();
    bool? result;
    await t.runAsync(() async {
      unawaited(TripLifecycleActions.saveAndExit(ctx).then((v) => result = v));
      await _until(() => api.count('PUT') == 1 && !c.isSaving.value);
      await _until(() => result != null || (api.count('GET') == 1 && !c.isOpening.value));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    return result;
  }

  testWidgets('save_and_exit_after_a_changed_elsewhere_refusal_does_not_say_saved', (t) async {
    final result = await saveAndExit(t, ['TripChanged']);
    expect(result, isFalse);
    expect(find.text(TripStringsV2Plan.savedTitle), findsNothing);
  });

  testWidgets('save_and_exit_after_a_landed_save_says_saved', (t) async {
    await saveAndExit(t, const []);
    expect(find.text(TripStringsV2Plan.savedTitle), findsOneWidget);
  });
}
