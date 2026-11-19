import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
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
  _VersionApi({required this.serverTrip, this.putErrors = const []});

  final Map<String, dynamic> serverTrip;
  final List<String> putErrors;
  final List<RequestOptions> seen = [];

  int count(String method) => seen.where((o) => o.method.toUpperCase() == method && o.path == '/trips/t1').length;

  List<Map<String, dynamic>> get putBodies => [
        for (final o in seen)
          if (o.method.toUpperCase() == 'PUT') Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) : o.data as Map),
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
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
  setUp(() => StorageService.clearTripPending('t1'));
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

  test('retry_of_an_offline_copy_sends_the_copy_base_and_a_newer_server_plan_wins', () async {
    final local = enginePlan([[2, 2]]);
    final other = enginePlan([[1], [1], [1]]);
    ApiService.init();
    final api = _VersionApi(
      serverTrip: engineTripJson(other, extra: {'updatedAt': _otherSaveAt}),
      putErrors: ['TripChanged'],
    );
    ApiService.dio.httpClientAdapter = api;
    StorageService.saveTripPending('t1', plan: _moved(local).toJson(), baseUpdatedAt: DateTime.parse(_loadedAt));
    final c = engineRig(local);

    await c.open('t1', fresh: true);
    expect(c.hasPendingCopy, isTrue);
    expect(c.saveFailed.value, isTrue);
    expect(api.count('PUT'), 0);

    expect(await c.retrySave(), isFalse);
    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    await _until(() => api.count('GET') == 2 && !c.isOpening.value && c.lastToast != null);

    expect(api.count('PUT'), 1);
    expect(c.plan.value!.days.length, other.days.length);
    expect(c.hasPendingCopy, isFalse);
    expect(c.saveFailed.value, isFalse);
    expect(StorageService.getTripPending('t1'), isNull);
    expect(c.lastToast, TripStringsSync.changedElsewhere);

    c.plan.value = c.plan.value!.copyWith(days: [c.plan.value!.days[0], c.plan.value!.days[1]]);
    await c.saveNow();
    expect(api.putBodies.last['baseUpdatedAt'], _otherSaveAt);
  });

  test('an_edit_after_taking_back_the_offline_copy_keeps_the_copy_base_on_the_phone', () async {
    final local = enginePlan([[2, 2]]);
    final other = enginePlan([[1], [1], [1]]);
    ApiService.init();
    final api = _VersionApi(serverTrip: engineTripJson(other, extra: {'updatedAt': _otherSaveAt}), putErrors: ['Down']);
    ApiService.dio.httpClientAdapter = api;
    StorageService.saveTripPending('t1', plan: _moved(local).toJson(), baseUpdatedAt: DateTime.parse(_loadedAt));
    final c = engineRig(local);
    await c.open('t1', fresh: true);

    expect(await c.retrySave(), isFalse);
    expect(api.putBodies.single['baseUpdatedAt'], _loadedAt);
    c.plan.value = local;
    c.scheduleSave();
    expect(StorageService.getTripPending('t1')!.baseUpdatedAt, DateTime.parse(_loadedAt));
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
