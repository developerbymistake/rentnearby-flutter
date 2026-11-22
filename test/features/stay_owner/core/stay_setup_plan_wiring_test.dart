import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_entry_screen.dart';
import 'package:bakhli/features/stay_owner/calendar/stay_calendar_screen.dart';
import 'package:bakhli/features/stay_owner/stay_owner_routes.dart';
import 'package:bakhli/features/stay_owner/strings/stay_gate_strings.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'stay_setup_fixtures.dart';

// FS-10: a Draft owner reaches the setup steps without MainScreen. The plan is the real
// PlanController fed by a fake /plans/me, never PlanGate.debugPlan.

class _UploadRepo extends FakeStayRepo {
  _UploadRepo(super.model, this.fail);

  final Object fail;
  int uploads = 0;

  @override
  Future<void> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) async {
    uploads++;
    throw fail;
  }
}

DioException _refusal(String type, String message, {required bool canUpgrade}) => DioException(
      requestOptions: RequestOptions(path: '/stays/me/photos'),
      response: Response(
        requestOptions: RequestOptions(path: '/stays/me/photos'),
        statusCode: 409,
        data: {
          'success': false,
          'error': {'type': type, 'message': message},
          'data': {'key': 'Photos', 'limit': 2, 'used': 2, 'canUpgrade': canUpgrade},
        },
      ),
      type: DioExceptionType.badResponse,
    );

FakePlanRepository _realPlan(Map<String, dynamic> me) {
  PlanGate.debugPlan = null;
  final plans = FakePlanRepository([me]);
  Get.put<PlanRepository>(plans, permanent: true);
  return plans;
}

Future<void> _pump(WidgetTester t, Widget screen, {Size size = const Size(360, 1500)}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, screen, size: size, toastHost: true);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _clear(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 15));
}

const _free = {
  'paymentEnabled': true,
  'trialAvailable': true,
  'limits': {'photos': 2, 'roomTypes': 2},
};
const _off = {
  'paymentEnabled': false,
  'limits': {'photos': 8, 'roomTypes': 6},
};

void main() {
  setUpAll(() => initTestStorage('stay_setup_plan_wiring'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanBindings.dispose();
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  group('FS-10 setup reads the real plan without MainScreen', () {
    testWidgets('payment OFF: 8 photo slots open, no lock', (t) async {
      setupFor(stayModel(draftJson(step1: true)));
      final plans = _realPlan(_off);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(plans.meCalls, 1, reason: 'the photos step registers the plan itself');
      expect(Get.isRegistered<PlanController>(), isTrue);
      expect(PlanGate.loaded, isTrue);
      expect(find.text('2 of 8'), findsOneWidget);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      await _clear(t);
    });

    testWidgets('payment ON Free: the locked 3rd photo tile opens G5', (t) async {
      setupFor(stayModel(draftJson(step1: true)));
      _realPlan(_free);
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true), size: phoneSize);
      expect(find.text('2 of 2'), findsOneWidget);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text(StayGateStrings.photoGate().title), findsWidgets);
      await _clear(t);
    });

    testWidgets('payment OFF: rooms step offers up to 6 rooms', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)));
      _realPlan(_off);
      await _pump(t, const StayRoomsScreen());
      expect(find.byKey(GateKeys.softRow), findsNothing);
      expect(find.textContaining('of 6'), findsWidgets);
      await _clear(t);
    });

    testWidgets('payment ON Free: the 3rd room opens G6', (t) async {
      setupFor(stayModel(draftJson(step1: true, rooms: true)));
      _realPlan(_free);
      await _pump(t, const StayRoomsScreen(), size: phoneSize);
      await t.tap(find.byKey(GateKeys.softRow));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('2 room types on Free'), findsWidgets);
      await _clear(t);
    });

    testWidgets('plan not answered yet: no local lock, the server decides', (t) async {
      setupFor(stayModel(draftJson(step1: true)));
      final plans = _realPlan(_free);
      plans.failWith = Exception('offline');
      await _pump(t, const StayBasicDetailsScreen(photosOnly: true));
      expect(PlanGate.loaded, isFalse);
      expect(find.byKey(GateKeys.softRow), findsNothing);
      await _clear(t);
    });
  });

  group('FS-13 photo upload refusal', () {
    test('409 PlanPhotoLimit with canUpgrade: silent, read for G5, no retry', () async {
      setupFor(stayModel(draftJson(step1: true)));
      final repo = _UploadRepo(null, _refusal('PlanPhotoLimit', '2 photos on Free.', canUpgrade: true));
      final c = StaySetupController(repo: repo);
      expect(await c.uploadPhoto('a.jpg'), isFalse);
      expect(repo.uploads, 1);
      expect(c.lastErrorType, 'PlanPhotoLimit');
      expect(c.lastCanUpgrade, isTrue);
      expect(c.lastNetwork, isFalse);
    });

    test('409 without canUpgrade keeps the server line for one info toast', () async {
      setupFor(stayModel(draftJson(step1: true)));
      final c = StaySetupController(repo: _UploadRepo(null, _refusal('PlanPhotoLimit', 'You can add up to 2 photos.', canUpgrade: false)));
      await c.uploadPhoto('a.jpg');
      expect(c.lastCanUpgrade, isFalse);
      expect(c.lastErrorMessage, 'You can add up to 2 photos.');
    });

    test('a network failure is never read as a plan refusal', () async {
      setupFor(stayModel(draftJson(step1: true)));
      final fail = DioException(requestOptions: RequestOptions(path: '/stays/me/photos'), type: DioExceptionType.connectionError);
      final c = StaySetupController(repo: _UploadRepo(null, fail));
      await c.uploadPhoto('a.jpg');
      expect(c.lastNetwork, isTrue);
      expect(c.lastCanUpgrade, isFalse);
      expect(c.lastErrorType, isNot('PlanPhotoLimit'));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('FS-32 route ids', () {
    test('a non-GUID entry id lands on the calendar', () {
      expect(stayEntryPage({'id': '../../etc'}), isA<StayCalendarScreen>());
      expect(stayEntryPage({'id': 'gupta'}), isA<StayCalendarScreen>());
      expect(stayEntryPage(const {}), isA<StayCalendarScreen>());
      expect(stayEntryPage({'id': '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b', 'kind': 'block'}), isA<StayCalendarEntryScreen>());
    });
  });
}
