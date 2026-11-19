import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:bakhli/features/trip/trip_strings_v2_easy.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo implements TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);
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
  int sends = 0;

  @override
  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async {
    sends++;
    return TripEnquiryBatch(
      items: const [],
      skipped: const [],
      veryShortNotice: false,
      results: [for (final id in stayIds) TripSendResult(listingId: id, status: 'Sent')],
    );
  }
}

const _step = 'stay:1';

ShortlistItem _item(String id) => ShortlistItem(stepKey: _step, kind: 'Stay', listingId: id, name: 'Stay $id');

GetPage _page(String name) => GetPage(
      name: name,
      page: () => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(name),
              TextButton(
                onPressed: () => TripShortlistFlow.done(
                  context,
                  step: _step,
                  taxi: false,
                  send: () => TripShortlistController.to.sendStays(step: _step, day: 1, nights: 2),
                ),
                child: const Text('done'),
              ),
            ]),
          ),
        ),
      ),
    );

Future<void> _app(WidgetTester t, List<String> stack) async {
  await t.pumpWidget(GetMaterialApp(
    initialRoute: AppRoutes.main,
    getPages: [
      _page(AppRoutes.main),
      _page(AppRoutes.tripOverview),
      _page(AppRoutes.tripPlan),
      _page(AppRoutes.tripStay),
    ],
  ));
  for (final r in stack) {
    Get.toNamed(r);
    await t.pumpAndSettle();
  }
}

Future<void> _toResult(WidgetTester t) async {
  await t.tap(find.text('done'));
  await t.pumpAndSettle();
  expect(find.text(TripStringsShortlist.sendAll), findsOneWidget);
  await t.tap(find.text(TripStringsShortlist.sendAll));
  await t.pumpAndSettle();
  expect(find.text(TripStringsV2Easy.sentBack), findsOneWidget);
}

void main() {
  late _Enquiry enquiry;
  late TripShortlistController c;

  setUp(() {
    Get.testMode = true;
    enquiry = _Enquiry();
    Get.put<TripEnquiryController>(enquiry);
    c = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put(c);
  });

  tearDown(Get.reset);

  testWidgets('back to plan from the stay list lands on the trip overview', (t) async {
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay]);
    TripNavigation.backToPlan();
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
  });

  testWidgets('back to plan from the stay list under the day plan lands on the day plan', (t) async {
    await _app(t, [AppRoutes.tripPlan, AppRoutes.tripStay]);
    TripNavigation.backToPlan();
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripPlan);
  });

  testWidgets('the result sheet button goes back to the overview', (t) async {
    c.items.addAll([_item('a'), _item('b')]);
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay]);
    await _toResult(t);
    await t.tap(find.text(TripStringsV2Easy.sentBack));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(enquiry.sends, 1);
  });

  testWidgets('dismissing the result sheet outside equals back to plan and sends nothing again', (t) async {
    c.items.addAll([_item('a'), _item('b')]);
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay]);
    await _toResult(t);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(enquiry.sends, 1);
    expect(c.countOf(_step), 0);
  });

  testWidgets('not now keeps the picks and goes back to the overview', (t) async {
    c.items.addAll([_item('a')]);
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay]);
    await t.tap(find.text('done'));
    await t.pumpAndSettle();
    await t.tap(find.text(TripStringsShortlist.notNow));
    await t.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.tripOverview);
    expect(enquiry.sends, 0);
    expect(c.countOf(_step), 1);
  });

  testWidgets('entering the list again after sending never re-sends the same stays', (t) async {
    c.items.addAll([_item('a'), _item('b')]);
    await _app(t, [AppRoutes.tripOverview, AppRoutes.tripStay]);
    await _toResult(t);
    await t.tap(find.text(TripStringsV2Easy.sentBack));
    await t.pumpAndSettle();
    Get.toNamed(AppRoutes.tripStay);
    await t.pumpAndSettle();
    await t.tap(find.text('done').last);
    await t.pumpAndSettle();
    expect(find.text(TripStringsShortlist.sendAll), findsNothing);
    expect(enquiry.sends, 1);
  });
}
