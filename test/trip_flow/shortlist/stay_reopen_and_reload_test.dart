import 'dart:convert';
import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../features/trip/support/engine_rig.dart';

class _Repo implements TripShortlistRepository {
  bool fail = false;
  int lists = 0;
  List<ShortlistItem> server = const [];

  @override
  Future<TripShortlist> list(String tripId) async {
    lists++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    return TripShortlist(items: server);
  }

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

class _Enquiry extends TripEnquiryController {
  TripEnquiryBatch? reply;

  @override
  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async =>
      reply;
}

class _Api implements HttpClientAdapter {
  _Api(this.server);

  Map<String, dynamic> server;
  final List<RequestOptions> seen = [];

  int count(String method) => seen.where((o) => o.method.toUpperCase() == method).length;

  Map<String, dynamic> lastPut() {
    final body = seen.lastWhere((o) => o.method.toUpperCase() == 'PUT').data;
    return Map<String, dynamic>.from(body is String ? jsonDecode(body) as Map : body as Map);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final json = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (options.method.toUpperCase() == 'PUT') {
      final body = options.data is String ? jsonDecode(options.data as String) as Map : options.data as Map;
      server = {...server, 'plan': body['plan'], 'updatedAt': '2026-11-02T00:00:00Z'};
    }
    return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': server}), 200, headers: json);
  }

  @override
  void close({bool force = false}) {}
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _step = 'stay:1';

ShortlistItem _item(String id) => ShortlistItem(stepKey: _step, kind: 'Stay', listingId: id, name: 'Stay $id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('reopen_gs').path);
    await GetStorage.init();
  });

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('stay shortlist reload after an error', () {
    late _Repo repo;
    late _Enquiry enquiry;
    late TripShortlistController c;

    setUp(() {
      repo = _Repo();
      enquiry = _Enquiry();
      Get.put<TripEnquiryController>(enquiry);
      c = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
    });

    test('a failed load shows the error and Retry loads the list again', () async {
      repo.fail = true;
      expect(await c.load(), isFalse);
      expect(c.hasError(_step), isTrue);
      repo.fail = false;
      repo.server = [_item('a')];
      expect(await c.reload(_step), isTrue);
      expect(c.hasError(_step), isFalse);
      expect(c.countOf(_step), 1);
    });

    test('coming back after a failed load never serves the cached rows', () async {
      repo.server = [_item('a')];
      await c.load();
      repo.fail = true;
      await c.load(force: true);
      repo.fail = false;
      repo.server = [_item('b')];
      expect(await c.load(), isTrue);
      expect(repo.lists, 3);
      expect(c.has(_step, 'b'), isTrue);
      expect(c.has(_step, 'a'), isFalse);
    });

    test('a failed send shows the error; Retry reloads the list and drops the stale row', () async {
      repo.server = [_item('a'), _item('gone')];
      await c.load();
      repo.server = [_item('a')];
      enquiry.reply = null;
      expect(await c.sendStays(step: _step, day: 1, nights: 2), isNull);
      expect(c.hasError(_step), isTrue);
      expect(c.sendFailed, contains(_step));
      expect(await c.reload(_step), isTrue);
      expect(repo.lists, 2);
      expect(c.hasError(_step), isFalse);
      expect(c.has(_step, 'gone'), isFalse);
      expect(c.has(_step, 'a'), isTrue);
    });

    test('a limit refusal shows its own note, not the Retry error', () async {
      repo.server = [_item('a')];
      await c.load();
      enquiry.reply = null;
      enquiry.lastErrorType = TripEnquiryErrorTypes.enquiryLimit;
      expect(await c.sendStays(step: _step, day: 1, nights: 2), isNull);
      expect(c.hasError(_step), isFalse);
      expect(c.noteOf(_step), isNotNull);
    });

    test('a good send clears the send error', () async {
      repo.server = [_item('a')];
      await c.load();
      c.sendFailed.add(_step);
      enquiry.reply = const TripEnquiryBatch(
        items: [],
        skipped: [],
        veryShortNotice: false,
        results: [TripSendResult(listingId: 'a', status: 'Sent')],
      );
      expect(await c.sendStays(step: _step, day: 1, nights: 2), isNotNull);
      expect(c.hasError(_step), isFalse);
    });
  });

  group('stay step reopen', () {
    test('reopen clears a skipped stay mark and saves it before the shortlist opens', () async {
      final plan = enginePlan([[2, 2]]).withStayMark(1, const TripRowMark.skipped());
      ApiService.init();
      final api = _Api(engineTripJson(plan));
      ApiService.dio.httpClientAdapter = api;
      final c = engineRig(plan);
      expect(await c.reopenStayStep(1), isTrue);
      expect(c.plan.value!.legAt(1)!.stayMark, isNull);
      expect(api.count('PUT'), 1);
      final sent = TripPlan.fromJson(Map<String, dynamic>.from(api.lastPut()['plan'] as Map));
      expect(sent.legAt(1)!.stayMark, isNull);
    });

    test('reopen keeps an own mark, like the Stay card', () async {
      final plan = enginePlan([[2, 2]]).withStayMark(1, const TripRowMark.own());
      ApiService.init();
      final api = _Api(engineTripJson(plan));
      ApiService.dio.httpClientAdapter = api;
      final c = engineRig(plan);
      expect(await c.reopenStayStep(1), isTrue);
      expect(c.plan.value!.legAt(1)!.stayMark?.isOwn, isTrue);
      expect(api.count('PUT'), 0);
    });

    test('after a send the local plan takes the server reopen and never writes the old mark back', () async {
      final base = enginePlan([[2, 2]]);
      final local = base
          .withStayMark(1, const TripRowMark.own())
          .withGuide(const TripGuide(choices: {_step: TripGuideChoice.own}));
      ApiService.init();
      final api = _Api(engineTripJson(base, extra: {'updatedAt': '2026-11-01T05:00:00Z'}));
      ApiService.dio.httpClientAdapter = api;
      final c = engineRig(local);

      await c.adoptReopenedStay(_step);
      expect(api.count('GET'), 1);
      expect(api.count('PUT'), 0);
      expect(c.plan.value!.legAt(1)!.stayMark, isNull);
      expect(c.plan.value!.guide?.choices[_step], isNull);

      c.scheduleSave();
      expect(await c.flushPendingSave(), isTrue);
      final put = api.lastPut();
      expect(DateTime.parse(put['baseUpdatedAt'] as String), DateTime.utc(2026, 11, 1, 5));
      expect(TripPlan.fromJson(Map<String, dynamic>.from(put['plan'] as Map)).legAt(1)!.stayMark, isNull);
    });

    test('nothing is fetched when the step has no mark, and a server that kept the mark changes nothing', () async {
      final base = enginePlan([[2, 2]]);
      ApiService.init();
      final api = _Api(engineTripJson(base.withStayMark(1, const TripRowMark.skipped())));
      ApiService.dio.httpClientAdapter = api;
      final open = engineRig(base);
      await open.adoptReopenedStay(_step);
      expect(api.count('GET'), 0);

      final marked = engineRig(base.withStayMark(1, const TripRowMark.skipped()));
      await marked.adoptReopenedStay(_step);
      expect(api.count('GET'), 1);
      expect(marked.plan.value!.legAt(1)!.stayMark?.isSkipped, isTrue);
    });

    testWidgets('Find another clears the skip and then opens the stay shortlist', (t) async {
      final plan = enginePlan([[2, 2]]).withStayMark(1, const TripRowMark.skipped());
      ApiService.init();
      final api = _Api(engineTripJson(plan));
      ApiService.dio.httpClientAdapter = api;
      Get.put<TabConfigController>(_Tabs());
      final c = Get.put<TripPlanController>(TripPlanController());
      c.plan.value = plan;
      c.trip.value = engineTrip(plan);
      GetPage page(String name) => GetPage(name: name, page: () => Scaffold(body: Text(name)));
      await t.pumpWidget(GetMaterialApp(
        initialRoute: AppRoutes.tripReplies,
        getPages: [page(AppRoutes.tripReplies), page(AppRoutes.tripStay)],
      ));
      bool? opened;
      TripNavigation.reopenStayShortlist(1).then((v) => opened = v);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.tripStay);
      expect((Get.arguments as Map)['shortlist'], isTrue);
      expect(c.plan.value!.legAt(1)!.stayMark, isNull);
      expect(api.count('PUT'), 1);
      expect(opened, isNull);
    });
  });
}
