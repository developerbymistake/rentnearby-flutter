import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/models/place_result_model.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_card.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_progress.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo implements TripShortlistRepository {
  _Repo([this.items = const []]);

  final List<ShortlistItem> items;
  final booked = <String>[];

  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: items);

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async {
    booked.add(stepKey);
    return const MarkBookedResult(closedEnquiries: 1, closedShortlist: 1);
  }
}

TripSpotRef _spot(String id) =>
    TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan(int legs, {TripGuide? guide}) => TripPlan(
      legs: [
        for (var k = 1; k <= legs; k++)
          TripCityLeg(index: k, cityKey: k, cityName: 'City$k', latitude: 29.4 + k / 10, longitude: 79.4),
      ],
      days: [for (var k = 1; k <= legs; k++) TripDay(day: k, leg: k, spots: [_spot('s$k')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      guide: guide,
    );

ShortlistItem _item(String step, String name, {String state = ShortlistStates.active, String? reason}) => ShortlistItem(
      stepKey: step,
      kind: ShortlistKinds.stay,
      listingId: 'id-$name',
      name: name,
      state: state,
      closedReason: reason,
    );

class _FailingWays extends TaxiWaysController {
  _FailingWays()
      : super(
          from: PlaceResult(name: 'A', subtitle: '', latLng: const LatLng(29.2, 79.5)),
          to: PlaceResult(name: 'B', subtitle: '', latLng: const LatLng(29.4, 79.4)),
        );

  @override
  Future<void> load() async {
    loadFailed.value = true;
  }
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Rig {
  _Rig(this.c, this.sl, this.repo);
  final TripPlanController c;
  final TripShortlistController sl;
  final _Repo repo;

  void close() {
    c.onClose();
    Get.reset();
  }
}

_Rig _rig(TripPlan plan, {List<ShortlistItem> items = const []}) {
  final repo = _Repo(items);
  final sl = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  final c = TripPlanController();
  c.plan.value = plan;
  return _Rig(c, sl, repo);
}

Future<void> _pump(WidgetTester t, _Rig r, double w, {double scale = 1, double h = 800}) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: Scaffold(body: TripGuideView(controller: r.c, shortlist: r.sl)),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

bool _nextEnabled(WidgetTester t) {
  final btn = t.widget<TripGuideBar>(find.byType(TripGuideBar));
  return btn.canNext;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Next stays disabled until a choice, Skip enables it, Previous keeps answers', (t) async {
    final r = _rig(_plan(1));
    await _pump(t, r, 360);
    expect(find.text("Let's get you there"), findsOneWidget);
    expect(_nextEnabled(t), isFalse);
    expect(find.text('Help me find'), findsOneWidget);
    expect(find.text('I will arrange it myself'), findsOneWidget);
    expect(find.text('Skip this'), findsOneWidget);

    await _tap(t, 'Skip this');
    expect(_nextEnabled(t), isTrue);
    await _tap(t, 'Next');
    expect(find.text('Where will you stay in City1?'), findsOneWidget);
    expect(_nextEnabled(t), isFalse);

    await _tap(t, 'Previous');
    expect(find.text("Let's get you there"), findsOneWidget);
    expect(r.c.guideState.current.value, TripGuideChoice.skip);
    expect(_nextEnabled(t), isTrue);
    r.close();
  });

  testWidgets('percent bar and step n of N follow the answers, no stepper dots', (t) async {
    final r = _rig(_plan(1));
    await _pump(t, r, 360);
    expect(find.text('0% done'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await _tap(t, 'Skip this');
    await _tap(t, 'Next');
    expect(find.text('25% done'), findsOneWidget);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Stay in City1'), findsOneWidget);
    expect(find.byType(Stepper), findsNothing);
    r.close();
  });

  testWidgets('skipping the sightseeing taxi writes the skipped mark and shows the note', (t) async {
    final r = _rig(_plan(1, guide: const TripGuide(step: 'taxi')));
    await _pump(t, r, 360);
    expect(find.text('See the sights in City1'), findsOneWidget);
    await _tap(t, 'Skip this');
    expect(find.text('We will not show taxis for this trip.'), findsOneWidget);
    expect(r.c.plan.value!.taxiMark?.isSkipped, isTrue);
    r.close();
  });

  testWidgets('choices and the cursor are written into the plan', (t) async {
    final r = _rig(_plan(1));
    await _pump(t, r, 360);
    await _tap(t, 'Skip this');
    await _tap(t, 'Next');
    final g = r.c.plan.value!.guide!;
    expect(g.step, 'stay:1');
    expect(g.choices['gettingThere'], TripGuideChoice.skip);
    r.close();
  });

  testWidgets('resume opens the exact stored step with answers unchanged', (t) async {
    final r = _rig(_plan(2, guide: const TripGuide(
      step: 'between:2',
      choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.skip, 'taxi': TripGuideChoice.skip},
    )));
    await _pump(t, r, 360);
    expect(find.text('On to City2'), findsOneWidget);
    expect(find.text('Step 4 of 6'), findsOneWidget);
    expect(find.text('50% done'), findsOneWidget);
    await _tap(t, 'Previous');
    expect(find.text('See the sights in City1 & City2'), findsOneWidget);
    expect(r.c.guideState.current.value, TripGuideChoice.skip);
    r.close();
  });

  testWidgets('a plan without a guide (v6) starts at the first unresolved step', (t) async {
    final r = _rig(_plan(1));
    await _pump(t, r, 360);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    r.close();
  });

  testWidgets('a 4 city (10 step) plan walks to the finish card at 300 dp and text scale 2', (t) async {
    final r = _rig(_plan(4));
    await _pump(t, r, 300, scale: 2, h: 900);
    expect(find.text('Step 1 of 10'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await t.ensureVisible(find.text('Skip this'));
      await t.pump();
      await _tap(t, 'Skip this');
      expect(t.takeException(), isNull);
      await _tap(t, 'Next');
      expect(t.takeException(), isNull);
    }
    expect(find.text('Your trip is ready to go'), findsOneWidget);
    expect(find.text('100% done'), findsOneWidget);
    expect(find.text('Open summary'), findsOneWidget);
    r.close();
  });

  testWidgets('review card after shortlisting; Not now moves on and keeps the shortlist', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
      items: [_item('stay:1', 'Hill View'), _item('stay:1', 'Lake Inn')],
    );
    await _pump(t, r, 360);
    expect(find.text('Great picks'), findsOneWidget);
    expect(find.text('Send an enquiry to all your shortlisted stays together?'), findsOneWidget);
    expect(find.text('Hill View'), findsOneWidget);
    expect(find.text('2 of 3 shortlisted'), findsOneWidget);
    expect(find.text('Yes, send to all'), findsOneWidget);
    expect(_nextEnabled(t), isFalse);
    await _tap(t, 'Not now');
    expect(find.text('See the sights in City1'), findsOneWidget);
    expect(r.sl.countOf('stay:1'), 2);
    r.close();
  });

  testWidgets('car step review offers Yes, send to all and Change my picks', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'gettingThere', choices: {'gettingThere': TripGuideChoice.find})),
      items: [
        ShortlistItem(stepKey: 'gettingThere', kind: ShortlistKinds.car, listingId: 'c1', name: 'Driver A', state: ShortlistStates.active),
      ],
    );
    await _pump(t, r, 360);
    expect(find.text('Great picks'), findsOneWidget);
    expect(find.text('Yes, send to all'), findsOneWidget);
    expect(find.text('Change my picks'), findsOneWidget);
    expect(_nextEnabled(t), isFalse);
    r.close();
  });

  List<ShortlistItem> cars(int n) => [
        for (var i = 1; i <= n; i++)
          ShortlistItem(stepKey: 'gettingThere', kind: ShortlistKinds.car, listingId: 'c$i', name: 'Driver $i', state: ShortlistStates.active),
      ];

  testWidgets('Yes, send to all on a car step sends up to 3 drivers through carSender', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'gettingThere', choices: {'gettingThere': TripGuideChoice.find})),
      items: cars(4),
    );
    final calls = <List<String>>[];
    final requestIds = <String>[];
    r.c.carSender = (step, ids, requestId) async {
      calls.add(ids);
      requestIds.add(requestId);
      return AskResult(items: const [], skipped: const [], veryShortNotice: false, results: [
        for (final id in ids) TripSendResult(listingId: id, status: 'Sent', enquiryId: 'e-$id'),
      ]);
    };
    await _pump(t, r, 360, h: 900);
    await t.ensureVisible(find.text('Yes, send to all'));
    await _tap(t, 'Yes, send to all');
    expect(calls, hasLength(1));
    expect(calls.single, ['c1', 'c2', 'c3']);
    expect(r.c.guideState.sent['gettingThere'], 3);
    expect(r.c.guideState.failed['gettingThere'], isNull);
    r.close();
  });

  testWidgets('a failed car send keeps a note and Try again reuses the same request id', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'gettingThere', choices: {'gettingThere': TripGuideChoice.find})),
      items: cars(2),
    );
    final requestIds = <String>[];
    var fail = true;
    r.c.carSender = (step, ids, requestId) async {
      requestIds.add(requestId);
      if (fail) return null;
      return AskResult(items: const [], skipped: const [], veryShortNotice: false, results: [
        for (final id in ids) TripSendResult(listingId: id, status: 'Sent'),
      ]);
    };
    await _pump(t, r, 360, h: 900);
    await t.ensureVisible(find.text('Yes, send to all'));
    await _tap(t, 'Yes, send to all');
    expect(r.c.guideState.sent['gettingThere'], isNull);
    expect(r.c.guideState.notes['gettingThere'], isNotNull);
    expect(find.text('Great picks'), findsOneWidget);
    fail = false;
    await t.ensureVisible(find.text('Try again'));
    await _tap(t, 'Try again');
    expect(requestIds, hasLength(2));
    expect(requestIds[0], requestIds[1]);
    expect(r.c.guideState.sent['gettingThere'], 2);
    r.close();
  });

  testWidgets('a car send with a failed ways load keeps the picks and a retry note', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'gettingThere', choices: {'gettingThere': TripGuideChoice.find})),
      items: cars(2),
    );
    r.c.carWays = (_) async => _FailingWays();
    await _pump(t, r, 360, h: 900);
    await t.ensureVisible(find.text('Yes, send to all'));
    await _tap(t, 'Yes, send to all');
    expect(r.c.guideState.sent['gettingThere'], isNull);
    expect(r.c.guideState.notes['gettingThere'], isNotNull);
    expect(r.sl.countOf('gettingThere'), 2);
    expect(find.text('Try again'), findsOneWidget);
    r.close();
  });

  testWidgets('Not now in the list Done sheet moves the guide to the next step', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
      items: [_item('stay:1', 'Hill View'), _item('stay:1', 'Lake Inn')],
    );
    Get.put<TabConfigController>(_Tabs());
    Get.put<TripPlanController>(r.c);
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late BuildContext ctx;
    await t.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Column(children: [
          Expanded(child: TripGuideView(controller: r.c, shortlist: r.sl)),
          Builder(builder: (c) {
            ctx = c;
            return TextButton(
              onPressed: () => TripShortlistFlow.done(ctx, step: 'stay:1', taxi: false, send: () async => null),
              child: const Text('list done'),
            );
          }),
        ]),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('list done'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Not now')));
    await t.pumpAndSettle();
    expect(find.text('See the sights in City1'), findsOneWidget);
    expect(find.text('Great picks'), findsNothing);
    r.close();
  });

  testWidgets('nudge card marks the step booked through the server and moves on', (t) async {
    final r = _rig(_plan(1, guide: const TripGuide(choices: {'gettingThere': TripGuideChoice.skip})));
    await _pump(t, r, 360);
    r.c.guideJumpTo('stay:1', nudge: true, name: 'Hill View');
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Did you book Hill View?'), findsOneWidget);
    expect(find.text('Mark as booked'), findsOneWidget);
    expect(find.text('Choose new options'), findsOneWidget);
    await _tap(t, 'Mark as booked');
    await t.pump(const Duration(milliseconds: 100));
    expect(r.repo.booked, ['stay:1']);
    expect(r.c.plan.value!.legAt(1)!.stayMark?.isOwn, isTrue);
    expect(find.text('See the sights in City1'), findsOneWidget);
    r.close();
  });

  testWidgets('reopened card appears for a closed no reply shortlist', (t) async {
    final r = _rig(
      _plan(1, guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
      items: [_item('stay:1', 'Hill View', state: ShortlistStates.closed, reason: ShortlistClosedReasons.noReply)],
    );
    await _pump(t, r, 360);
    expect(find.text('No reply yet'), findsOneWidget);
    expect(find.text('I booked it myself'), findsOneWidget);
    expect(find.text('Find new options'), findsOneWidget);
    r.close();
  });

  testWidgets('a progress change does not rebuild the card', (t) async {
    final r = _rig(_plan(1));
    await _pump(t, r, 360);
    final before = TripGuideFrame.builds;
    r.c.guideState.percent.value = 60;
    await t.pump();
    expect(find.text('60% done'), findsOneWidget);
    expect(TripGuideFrame.builds, before);
    r.close();
  });

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow and a centred card at ${w.toInt()} dp, text scale $scale', (t) async {
        final r = _rig(
          _plan(1, guide: const TripGuide(step: 'stay:1', choices: {'gettingThere': TripGuideChoice.skip, 'stay:1': TripGuideChoice.find})),
          items: [_item('stay:1', 'A very long stay name that must wrap or clip nicely'), _item('stay:1', 'Lake Inn')],
        );
        await _pump(t, r, w, scale: scale);
        expect(t.takeException(), isNull);
        r.c.guideState.step = 'taxi';
        r.c.guideGoTo(2);
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull);
        if (scale == 1.0) {
          final card = t.getRect(find.byType(TripGuideFrame));
          final top = t.getRect(find.byType(TripGuideProgress)).bottom;
          final bottom = t.getTopLeft(find.byType(TripGuideBar)).dy;
          expect(card.top, greaterThanOrEqualTo(top));
          expect(card.bottom, lessThanOrEqualTo(bottom));
          expect(((card.top - top) - (bottom - card.bottom)).abs(), lessThan(40));
          expect(card.width, lessThanOrEqualTo(w));
        }
        r.close();
      });
    }
  }
}
