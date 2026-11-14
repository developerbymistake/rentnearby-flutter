import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/utils/trip_guide_rules.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'journeys/fake_api.dart';

class _Repo implements TripShortlistRepository {
  _Repo(this.items);

  final List<ShortlistItem> items;

  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: items);

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Down implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

ShortlistItem _item(String step, String id) => ShortlistItem(stepKey: step, kind: ShortlistKinds.taxi, listingId: id, name: 'N-$id');

TripModel _trip(TripPlan plan) => TripModel(
      id: 't1',
      title: 'Trip',
      status: TripStatuses.planned,
      cityKey: 1,
      cityName: 'City 1',
      cityLatitude: 29.4,
      cityLongitude: 79.4,
      dayCount: plan.days.length,
      spotCount: plan.spotCount,
      plan: plan,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<TripPlanController> _rig(TripPlan plan, {List<ShortlistItem> items = const []}) async {
  Get.reset();
  final sl = TripShortlistController(repo: _Repo(items), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  Get.put<TripEnquiryController>(TripEnquiryController());
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c);
  c.plan.value = plan;
  c.trip.value = _trip(plan);
  await sl.load(force: true);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('answered vs resolved', () {
    test('find + Not now + shortlist may be passed but is not resolved', () {
      expect(TripGuideRules.answered(choice: TripGuideChoice.find, shortlisted: 2, sentOk: false, notNow: true, rowEvidence: false), isTrue);
      expect(TripGuideRules.resolved(choice: TripGuideChoice.find, sentOk: false, rowEvidence: false), isFalse);
    });

    test('a sent enquiry, server evidence, Own and Skip are resolved', () {
      expect(TripGuideRules.resolved(choice: TripGuideChoice.find, sentOk: true, rowEvidence: false), isTrue);
      expect(TripGuideRules.resolved(choice: TripGuideChoice.find, sentOk: false, rowEvidence: true), isTrue);
      expect(TripGuideRules.resolved(choice: TripGuideChoice.own, sentOk: false, rowEvidence: false), isTrue);
      expect(TripGuideRules.resolved(choice: TripGuideChoice.skip, sentOk: false, rowEvidence: false), isTrue);
      expect(TripGuideRules.resolved(choice: null, sentOk: true, rowEvidence: true), isFalse);
    });
  });

  group('TripGuide notNow model', () {
    test('round trip keeps the order and drops duplicates, bad keys and the 9th key', () {
      final g = TripGuide.tryParse({
        'step': 'stay:1',
        'notNow': ['gettingThere', 'gettingThere', 'bogus', 'stay:1', 'taxi', 'comingBack', 'stay:2', 'between:2', 'stay:3', 'between:3', 'stay:4'],
      })!;
      expect(g.notNow, ['gettingThere', 'stay:1', 'taxi', 'comingBack', 'stay:2', 'between:2', 'stay:3', 'between:3']);
      expect(TripGuide.tryParse(g.toJson()), g);
      expect(g.toJson()['notNow'], g.notNow);
    });

    test('notNow alone makes the guide non default and takes part in equality', () {
      const a = TripGuide(notNow: ['taxi']);
      expect(a.isDefault, isFalse);
      expect(a == const TripGuide(), isFalse);
      expect(a == const TripGuide(notNow: ['taxi']), isTrue);
    });
  });

  group('Not now is pending, never progress', () {
    final base = journeyPlan([2]);

    test('percent does not move; step 1 stays pending after moving to step 2; it persists', () async {
      final c = await _rig(base, items: [_item('gettingThere', 'a')]);
      c.guideHydrate();
      c.guideSync();
      expect(c.guideState.percent.value, 0);
      c.guideNotNow('gettingThere');
      expect(c.guideState.percent.value, 0);
      expect(c.guideState.index.value, 1);
      expect(c.guideState.pending.contains('gettingThere'), isTrue);
      expect(c.plan.value!.guide!.notNow, ['gettingThere']);
      c.onClose();
    });

    test('reload hydrate restores the pending tag and the position', () async {
      final saved = base.withGuide(const TripGuide(step: 'stay:1', choices: {}, notNow: ['gettingThere']));
      final c = await _rig(saved, items: [_item('gettingThere', 'a')]);
      c.guideRefresh();
      expect(c.guideState.pending.contains('gettingThere'), isTrue);
      expect(c.guideState.step, 'stay:1');
      expect(c.guideState.percent.value, 0);
      c.onClose();
    });

    test('percent rises after the enquiry is sent and the tag goes', () async {
      final c = await _rig(base, items: [_item('gettingThere', 'a')]);
      c.guideHydrate();
      c.guideSync();
      c.guideNotNow('gettingThere');
      c.guideState.sentOk.add('gettingThere');
      c.guideRefresh();
      expect(c.guideState.percent.value, 25);
      expect(c.guideState.pending.contains('gettingThere'), isFalse);
      c.onClose();
    });
  });

  group('save errors are honest', () {
    final plan = journeyPlan([2]);

    test('a 400 shows the server message, is not a connection problem, and is not re-sent', () async {
      final api = installFakeApi([FakeRoute.value('PUT', '/trips/{id}', null, code: 400, errorType: 'Contract problem')]);
      final c = await _rig(plan);
      c.plan.value = plan.withGuide(const TripGuide(step: 'stay:1'));
      expect(await c.saveNow(), isFalse);
      expect(c.saveFailed.value, isTrue);
      expect(c.notSavedMessage, 'Contract problem');
      expect(c.notSavedMessage, isNot(TripStrings.notSavedCheckConnection));
      final sent = api.calls('PUT', '/trips/t1').length;
      expect(await c.flushPendingSave(), isFalse);
      expect(await c.flushPendingSave(), isFalse);
      expect(api.calls('PUT', '/trips/t1').length, sent);
      c.onClose();
    });

    test('a 409 contract error shows its own message', () async {
      installFakeApi([FakeRoute.value('PUT', '/trips/{id}', null, code: 409, errorType: 'Conflict problem')]);
      final c = await _rig(plan);
      c.plan.value = plan.withGuide(const TripGuide(step: 'stay:1'));
      expect(await c.saveNow(), isFalse);
      expect(c.notSavedMessage, 'Conflict problem');
      c.onClose();
    });

    test('a changed payload is sent again after a rejection', () async {
      final api = installFakeApi([FakeRoute.value('PUT', '/trips/{id}', null, code: 400, errorType: 'Contract problem')]);
      final c = await _rig(plan);
      c.plan.value = plan.withGuide(const TripGuide(step: 'stay:1'));
      await c.saveNow();
      final sent = api.calls('PUT', '/trips/t1').length;
      c.plan.value = c.plan.value!.withGuide(const TripGuide(step: 'taxi'));
      await c.flushPendingSave();
      expect(api.calls('PUT', '/trips/t1').length, sent + 1);
      c.onClose();
    });

    test('a network failure says check your connection', () async {
      ApiService.init();
      final down = _Down();
      ApiService.dio.httpClientAdapter = down;
      final c = await _rig(plan);
      ApiService.dio.httpClientAdapter = down;
      c.plan.value = plan.withGuide(const TripGuide(step: 'stay:1'));
      expect(await c.saveNow(), isFalse);
      expect(c.notSavedMessage, TripStrings.notSavedCheckConnection);
      c.onClose();
    });
  });
}
