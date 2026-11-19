import 'dart:convert';
import 'dart:io';

import 'package:bakhli/design/extra/list_rows_3d.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/trip_strings_sync.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/engine_rig.dart';
import 'trip_day_plan_screen_test.dart';

const _loadedAt = '2026-11-19T10:00:00.123456Z';
const _otherSaveAt = '2026-11-19T10:05:00.654321Z';

TripPlan _moved(TripPlan plan) => plan.copyWith(days: [
      plan.days[0].copyWith(spots: [...plan.days[0].spots, ...plan.days[1].spots]),
      plan.days[1].copyWith(spots: const []),
      ...plan.days.skip(2),
    ]);

String _days(TripPlan p) => jsonEncode([for (final d in p.days) d.toJson()]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('pending_copy_gs').path);
    await GetStorage.init();
  });
  setUp(() {
    StorageService.clearTripPending('t1');
    StorageService.clearTripCache('t1');
  });
  tearDown(Get.reset);

  Future<void> openOnScreen(WidgetTester t, Map<String, dynamic> server, TripPlan local, {required TripPlan pending}) async {
    final api = installFakeApi([FakeRoute.value('GET', '/trips/{id}', server)]);
    final c = await pumpDayPlan(t, local);
    StorageService.saveTripPending('t1', plan: pending.toJson(), baseUpdatedAt: DateTime.parse(_loadedAt));
    await t.runAsync(() => c.open('t1', fresh: true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(api.calls('PUT', '/trips/t1'), isEmpty);
    expect(StorageService.getTripPending('t1'), isNull);
  }

  void expectNoSaveRetry() {
    expect(find.text(TripStrings.notSavedYet), findsNothing);
    expect(
        find.byWidgetPredicate((w) => w is Banner3D && w.onAction == Get.find<TripPlanController>().retrySave), findsNothing);
  }

  testWidgets('locked_plan_open_drops_the_pending_edit_with_one_line_and_no_retry', (t) async {
    final local = dayPlanFixture();
    final server = engineTripJson(local, extra: {
      'updatedAt': _loadedAt,
      'planLock': {'locked': true, 'reason': lockedByRequest.reason, 'requestId': lockedByRequest.requestId},
    });
    await openOnScreen(t, server, local, pending: _moved(local));

    final c = Get.find<TripPlanController>();
    expect(_days(c.plan.value!), _days(local));
    expect(c.lastToast, TripStringsSync.lockedNotSaved);
    expect(find.byKey(TripPlanScreen.lockedBannerKey), findsOneWidget);
    expectNoSaveRetry();
    await drainSave(t);
  });

  testWidgets('older_pending_edit_is_not_sent_and_the_newer_plan_shows_without_retry', (t) async {
    final local = dayPlanFixture();
    final other = dayPlanFixture(perLeg: const [[1, 1]]);
    await openOnScreen(t, engineTripJson(other, extra: {'updatedAt': _otherSaveAt}), local, pending: _moved(local));

    final c = Get.find<TripPlanController>();
    expect(_days(c.plan.value!), _days(other));
    expect(c.lastToast, TripStringsSync.changedElsewhereNotSaved);
    expectNoSaveRetry();
    await drainSave(t);
  });
}
