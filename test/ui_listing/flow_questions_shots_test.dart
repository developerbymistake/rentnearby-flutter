import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_guide.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_finish.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

class _Repo implements TripShortlistRepository {
  final items = <ShortlistItem>[];

  @override
  Future<TripShortlist> list(String tripId) async => TripShortlist(items: List.of(items));

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

TripSpotRef _spot(String id) => TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan(List<String> cities) => TripPlan(
      legs: [
        for (var k = 0; k < cities.length; k++)
          TripCityLeg(index: k + 1, cityKey: k + 1, cityName: cities[k], latitude: 29.4 + k / 10, longitude: 79.4),
      ],
      days: [for (var k = 0; k < cities.length; k++) TripDay(day: k + 1, leg: k + 1, spots: [_spot('s$k')])],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
    );

class _Rig {
  _Rig(TripPlan plan) {
    sl = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put<TripShortlistController>(sl);
    Get.put<TabConfigController>(_Tabs());
    c = TripPlanController();
    c.plan.value = plan;
    Get.put<TripPlanController>(c);
    c.guideState.opener = (ctx, row, guide) async => true;
    c.carSender = (step, ids, requestId) async {
      final results = [for (final id in ids) TripSendResult(listingId: id, status: 'Sent')];
      repo.items.removeWhere((i) => ids.contains(i.listingId));
      return AskResult(items: const [], skipped: const [], veryShortNotice: false, results: results);
    };
  }

  final repo = _Repo();
  late final TripShortlistController sl;
  late final TripPlanController c;

  Future<void> shortlist(String step, List<String> names) async {
    repo.items
      ..clear()
      ..addAll([
        for (var i = 0; i < names.length; i++)
          ShortlistItem(stepKey: step, kind: ShortlistKinds.car, listingId: 'c$i', name: names[i], state: ShortlistStates.active),
      ]);
    await sl.load(force: true);
  }

  void close() {
    c.onClose();
    Get.reset();
  }
}

const _out = 'F:/Dhasu/UI_Template_resume/Mock_Final/shots/flow-questions';

Future<void> _tap(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

double _prevTop(WidgetTester t) => t.getTopLeft(find.byTooltip('Previous')).dy;

double _sheetOffset(WidgetTester t) => t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

Finder _named(String full) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == full);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRealFonts();
    shotsDir = _out;
  });

  final configs = <(String, Size, double)>[
    ('1.0_360', const Size(360, 800), 1.0),
    ('1.3_360', const Size(360, 800), 1.3),
    ('1.0_300', const Size(300, 640), 1.0),
  ];

  for (final cfg in configs) {
    testWidgets('flow questions ${cfg.$1}', (t) async {
      debugDisableShadows = false;
      final long = cfg.$1 == '1.0_300';
      final r = _Rig(_plan(long ? ['Nainital Lake District Town', 'Almora Hill Station'] : ['Nainital', 'Almora']));
      await pumpPhone(t, Scaffold(body: SafeArea(bottom: false, child: TripGuideView(controller: r.c, shortlist: r.sl))),
          size: cfg.$2, textScale: cfg.$3);
      await settlePhone(t);
      expect(t.takeException(), isNull);
      final tops = <double>[_prevTop(t)];
      await shot(t, 'q1_getting_there_${cfg.$1}');
      await _tap(t, 'Help me find');
      await settlePhone(t);
      await shot(t, 'q1_find_${cfg.$1}');

      await r.shortlist('gettingThere', long ? ['Pradeep Kumar Singh Rawat Travels', 'Rakesh Singh', 'Mohan Rawat'] : ['Pradeep Kumar', 'Rakesh Singh', 'Mohan Rawat']);
      await t.pump();
      await settlePhone(t);
      expect(find.text('Great picks'), findsOneWidget);
      expect(find.byType(TripGuideBar), findsNothing);
      expect(find.text('Pradeep'), findsOneWidget);
      expect(_named(long ? 'Pradeep Kumar Singh Rawat Travels' : 'Pradeep Kumar'), findsOneWidget);
      expect(find.text('Change my picks'), findsOneWidget);
      expect(_sheetOffset(t), 0);
      await shot(t, 'review_${cfg.$1}');
      await t.ensureVisible(find.text('Not now'));
      await t.pump();
      final notNow = t.getRect(find.text('Not now'));
      expect(notNow.bottom, lessThanOrEqualTo(cfg.$2.height));
      final notNowBox = t.renderObject(find.text('Not now'));
      expect(t.hitTestOnBinding(notNow.center).path.any((e) => identical(e.target, notNowBox)), isTrue);
      await shot(t, 'review_end_${cfg.$1}');
      await _tap(t, 'Send to all');
      await settlePhone(t);
      expect(find.text('Enquiry sent'), findsOneWidget);
      expect(find.text('Rakesh · Sent'), findsNothing);
      expect(find.text('Rakesh Singh · Sent'), findsOneWidget);
      expect(_sheetOffset(t), 0);
      tops.add(_prevTop(t));
      await shot(t, 'sent_${cfg.$1}');
      await _tap(t, 'Next');
      await settlePhone(t);
      var i = 2;
      while (find.text('Skip this').evaluate().isNotEmpty) {
        tops.add(_prevTop(t));
        await shot(t, 'q${i}_${cfg.$1}');
        await _tap(t, 'Skip this');
        await settlePhone(t);
        if (i == 2 || find.text('We will not show taxis for this trip.').evaluate().isNotEmpty) await shot(t, 'q${i}_skip_${cfg.$1}');
        await _tap(t, 'Next');
        await settlePhone(t);
        i++;
      }
      expect(find.byType(TripGuideFinish), findsOneWidget);
      await shot(t, 'finish_${cfg.$1}');
      expect(t.takeException(), isNull);
      for (final y in tops) {
        expect(y, closeTo(tops.first, 0.5));
      }

      r.c.guideJumpTo('stay:1', nudge: true, name: long ? 'Hill View Homestay and Cottages' : 'Hill View');
      await t.pump();
      await settlePhone(t);
      await shot(t, 'nudge_${cfg.$1}');
      expect(find.byType(TripGuideBar), findsNothing);
      expect(_sheetOffset(t), 0);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 6));
      r.close();
      debugDisableShadows = true;
    });
  }

  for (final cfg in configs) {
    testWidgets('finish ready card ${cfg.$1}', (t) async {
      debugDisableShadows = false;
      var opened = 0;
      await pumpPhone(
          t,
          Scaffold(
              body: SafeArea(
                  bottom: false,
                  child: TripGuideFinish(arranged: true, percent: 100, title: 'Nainital to Almora', subtitle: '13 Nov · 3 days', stepText: '5 of 5', onBack: () {}, onSummary: () => opened++))),
          size: cfg.$2,
          textScale: cfg.$3);
      await settlePhone(t);
      await shot(t, 'finish_ready_${cfg.$1}');
      expect(find.text('Open summary'), findsOneWidget);
      expect(find.textContaining('% done'), findsNothing);
      await t.tap(find.text('Open summary'));
      expect(opened, 1);
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }

  testWidgets('finish saved card', (t) async {
    debugDisableShadows = false;
    await pumpPhone(t, Scaffold(body: SafeArea(bottom: false, child: TripGuideFinish(arranged: false, percent: 60, title: 'Nainital to Almora', subtitle: '13 Nov · 3 days', stepText: '5 of 5', onBack: () {}, onSummary: () {}))));
    await settlePhone(t);
    await shot(t, 'finish_saved_1.0_360');
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  });
}
