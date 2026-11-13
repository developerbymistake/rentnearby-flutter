import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_bar.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';

const _step = 'gettingThere';

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

TripPlan _plan({TripGuide? guide}) => TripPlan(
      legs: [TripCityLeg(index: 1, cityKey: 1, cityName: 'Nainital', latitude: 29.4, longitude: 79.4)],
      days: [
        TripDay(
          day: 1,
          leg: 1,
          spots: [TripSpotRef(id: 's1', name: 'Naini Lake', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60)],
        ),
      ],
      settings: TripSettings(startDate: DateTime(2030, 11, 1)),
      guide: guide,
    );

ShortlistItem _driver(int i) => ShortlistItem(
      stepKey: _step,
      kind: ShortlistKinds.car,
      listingId: 'c$i',
      name: 'Driver $i',
      state: ShortlistStates.active,
    );

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Rig {
  _Rig(TripPlan plan) {
    sl = TripShortlistController(repo: repo, tripId: () async => 't1', offline: () => false, warn: (_) {});
    Get.put<TripShortlistController>(sl);
    Get.put<TabConfigController>(_Tabs());
    c = TripPlanController();
    c.plan.value = plan;
    Get.put<TripPlanController>(c);
    c.guideState.opener = (ctx, row, guide) async {
      opened++;
      return true;
    };
    addTearDown(Get.reset);
  }

  final repo = _Repo();
  late final TripShortlistController sl;
  late final TripPlanController c;
  int opened = 0;

  void close() {
    c.onClose();
    Get.reset();
  }
  List<TripSendResult> Function(List<String> ids)? reply;

  Future<void> shortlist(int n) async {
    repo.items
      ..clear()
      ..addAll([for (var i = 1; i <= n; i++) _driver(i)]);
    await sl.load(force: true);
  }

  void wireSender() {
    c.carSender = (step, ids, requestId) async {
      final results = reply!(ids);
      repo.items.removeWhere((i) => results.any((x) => x.listingId == i.listingId && x.ok));
      return AskResult(items: const [], skipped: const [], veryShortNotice: false, results: results);
    };
  }
}

Widget _host(_Rig r) => Scaffold(
      body: SafeArea(bottom: false, child: TripGuideView(controller: r.c, shortlist: r.sl)),
    );

Future<void> _pump(WidgetTester t, _Rig r, {Size size = phoneSize, double scale = 1}) async {
  await pumpPhone(t, _host(r), size: size, textScale: scale);
  await settlePhone(t);
}

Future<void> _tap(WidgetTester t, String label) async {
  final f = find.text(label);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

TripGuideBar _bar(WidgetTester t) => t.widget<TripGuideBar>(find.byType(TripGuideBar));

const _out = 'F:/Dhasu/UI_Template_resume/Slice2/shots';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRealFonts();
    shotsDir = _out;
  });

  testWidgets('G fit: question sheet at 360x740 keeps the buttons pinned and every option reachable', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r, size: const Size(360, 740));
    final barTop = t.getTopLeft(find.byType(TripGuideBar)).dy;
    await t.ensureVisible(find.text('Skip this'));
    await t.pump();
    expect(t.getRect(find.text('Skip this')).bottom, lessThan(barTop));
    expect(t.getTopLeft(find.byType(TripGuideBar)).dy, barTop);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Back to steps'), findsNothing);
    expect(find.text('Open the list'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byTooltip('Previous'), findsOneWidget);
    r.close();
  });

  testWidgets('G labels: primary button says what happens', (t) async {
    final r = _Rig(_plan());
    r.reply = (ids) => [for (final id in ids) TripSendResult(listingId: id, status: 'Sent')];
    r.wireSender();
    await _pump(t, r);
    expect(_bar(t).primaryLabel, 'Next');
    expect(_bar(t).onPrimary, isNull);
    await _tap(t, 'Help me find');
    expect(_bar(t).primaryLabel, 'Find taxis');
    expect(_bar(t).onPrimary, isNotNull);
    await _tap(t, 'Find taxis');
    expect(r.opened, 2);
    await r.shortlist(3);
    await t.pump();
    expect(find.text('Great picks'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Driver $i'), findsOneWidget);
    }
    expect(find.byType(TripGuideBar), findsNothing);
    expect(find.text('Send to all'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await _tap(t, 'Send to all');
    expect(find.text('Enquiry sent'), findsOneWidget);
    expect(_bar(t).primaryLabel, 'Next');
    r.close();
  });

  testWidgets('G labels: own and skip enable Next, stay step says Find stays', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'I will arrange it myself');
    expect(_bar(t).primaryLabel, 'Next');
    expect(_bar(t).onPrimary, isNotNull);
    await _tap(t, 'Skip this');
    expect(_bar(t).onPrimary, isNotNull);
    await _tap(t, 'Next');
    await _tap(t, 'Help me find');
    expect(_bar(t).primaryLabel, 'Find stays');
    r.close();
  });

  testWidgets('G step label and percent bar agree', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    expect(find.text('GETTING THERE · STEP 1 OF 4'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await _tap(t, 'Skip this');
    expect(find.text('25%'), findsOneWidget);
    r.close();
  });

  group('G real font screenshots', () {
    final configs = <(String, Size, double)>[
      ('360x800_s10', const Size(360, 800), 1.0),
      ('360x740_s10', const Size(360, 740), 1.0),
      ('300x640_s10', const Size(300, 640), 1.0),
      ('360x800_s13', const Size(360, 800), 1.3),
      ('360x800_s20', const Size(360, 800), 2.0),
      ('300x640_s20', const Size(300, 640), 2.0),
    ];
    for (final cfg in configs) {
      testWidgets('G states at ${cfg.$1}', (t) async {
        debugDisableShadows = false;
        final r = _Rig(_plan());
        r.reply = (ids) => [for (final id in ids) TripSendResult(listingId: id, status: 'Sent')];
        r.wireSender();
        await _pump(t, r, size: cfg.$2, scale: cfg.$3);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_question_${cfg.$1}');
        await _tap(t, 'Skip this');
        await settlePhone(t);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_skip_${cfg.$1}');
        await _tap(t, 'I will arrange it myself');
        await settlePhone(t);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_own_${cfg.$1}');
        await _tap(t, 'Help me find');
        await settlePhone(t);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_find_${cfg.$1}');
        await r.shortlist(3);
        await t.pump();
        await settlePhone(t);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_review_${cfg.$1}');
        await _tap(t, 'Send to all');
        await settlePhone(t);
        expect(find.text('Enquiry sent'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'before ${cfg.$1}');
        await shot(t, 'G_sent_${cfg.$1}');
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 6));
        r.close();
        debugDisableShadows = true;
      });
    }
  });
}
