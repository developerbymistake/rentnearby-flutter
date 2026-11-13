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
import 'package:bakhli/features/trip/widgets/guide/trip_guide_progress.dart';
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
  final f = label == 'Previous' ? find.byTooltip(label) : find.text(label);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

TripGuideBar _bar(WidgetTester t) => t.widget<TripGuideBar>(find.byType(TripGuideBar));

void _agree(WidgetTester t, _Rig r, {required int percent, required bool next}) {
  expect(find.text('$percent%'), findsOneWidget);
  expect(t.widget<TripGuideProgress>(find.byType(TripGuideProgress)).percent, percent);
  expect(r.c.guideState.percent.value, percent);
  expect(find.byType(TripGuideBar).evaluate().isEmpty ? false : _bar(t).canNext, next);
  final fill = t.widget<FractionallySizedBox>(find.descendant(of: find.byType(TripGuideProgress), matching: find.byType(FractionallySizedBox)));
  expect(fill.widthFactor, closeTo(percent / 100, 0.001));
  final box = t.getSize(find.descendant(of: find.byType(TripGuideProgress), matching: find.byType(DecoratedBox)).last);
  expect(box.height, greaterThan(0));
  if (percent > 0) expect(box.width, greaterThan(0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  testWidgets('owner repro: Help me find, back from the list with nothing shortlisted, Next stays disabled', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'Help me find');
    expect(r.opened, 1);
    _agree(t, r, percent: 0, next: false);
    expect(find.text('Find taxis'), findsOneWidget);
    r.c.guideNext();
    await t.pump();
    expect(r.c.guideState.index.value, 0);
    await _tap(t, 'Find taxis');
    expect(r.opened, 2);
    expect(find.text("Let's get you there"), findsOneWidget);
    r.close();
  });

  testWidgets('shortlist 1 then Not now answers the step and Next moves on', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'Help me find');
    await r.shortlist(1);
    await t.pump();
    expect(find.text('Great picks'), findsOneWidget);
    _agree(t, r, percent: 0, next: false);
    await _tap(t, 'Not now');
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    expect(r.sl.countOf(_step), 1);
    await _tap(t, 'Previous');
    _agree(t, r, percent: 25, next: false);
    expect(find.byType(TripGuideBar), findsNothing);
    await _tap(t, 'Not now');
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    r.close();
  });

  testWidgets('send with one recipient failing still answers the step', (t) async {
    final r = _Rig(_plan());
    r.reply = (ids) => [
          for (final id in ids) TripSendResult(listingId: id, status: id == 'c2' ? 'Failed' : 'Sent', enquiryId: 'e-$id'),
        ];
    r.wireSender();
    await _pump(t, r);
    await _tap(t, 'Help me find');
    await r.shortlist(2);
    await t.pump();
    await _tap(t, 'Send to all');
    expect(r.c.guideState.sent[_step], 1);
    expect(r.c.guideState.failed[_step], 1);
    expect(r.c.guideAnswered(_step), isTrue);
    _agree(t, r, percent: 25, next: false);
    expect(find.text('Not now'), findsOneWidget);
    r.close();
  });

  testWidgets('every recipient failing leaves the step unanswered with an honest message', (t) async {
    final r = _Rig(_plan());
    r.reply = (ids) => [for (final id in ids) TripSendResult(listingId: id, status: 'Failed')];
    r.wireSender();
    await _pump(t, r);
    await _tap(t, 'Help me find');
    await r.shortlist(2);
    await t.pump();
    await _tap(t, 'Send to all');
    expect(r.c.guideAnswered(_step), isFalse);
    expect(r.c.guideState.notes[_step], isNotNull);
    expect(find.byKey(const ValueKey('guide-send-note')), findsOneWidget);
    _agree(t, r, percent: 0, next: false);
    r.c.guideNext();
    expect(r.c.guideState.index.value, 0);
    r.close();
  });

  testWidgets('overview jump beyond the first unanswered step is refused', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    final keys = [for (final s in r.c.guideState.steps) s.key];
    expect(keys.length, greaterThan(1));
    r.c.guideJumpTo(keys.last, persist: true);
    expect(r.c.guideState.index.value, 0);
    r.close();
  });

  testWidgets('a full send shows the sent card and Next moves on', (t) async {
    final r = _Rig(_plan());
    r.reply = (ids) => [for (final id in ids) TripSendResult(listingId: id, status: 'Sent')];
    r.wireSender();
    await _pump(t, r);
    await _tap(t, 'Help me find');
    await r.shortlist(2);
    await t.pump();
    await _tap(t, 'Send to all');
    expect(find.text('Enquiry sent'), findsOneWidget);
    expect(_bar(t).canNext, isTrue);
    expect(find.text('Next'), findsOneWidget);
    await t.tap(find.text('Next').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    await _tap(t, 'Previous');
    _agree(t, r, percent: 25, next: true);
    r.close();
  });

  testWidgets('Skip answers the step and Next moves on', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'Skip this');
    _agree(t, r, percent: 25, next: true);
    await _tap(t, 'Next');
    expect(find.text('Where will you stay in Nainital?'), findsOneWidget);
    r.close();
  });

  testWidgets('bar fill is drawn at 25 percent', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'Skip this');
    await settlePhone(t);
    _agree(t, r, percent: 25, next: true);
    await shot(t, 'A_skip25_360x800');
    r.close();
  });

  testWidgets('I will arrange it myself answers the step', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'I will arrange it myself');
    await t.pump(const Duration(milliseconds: 200));
    expect(r.c.guideAnswered(_step), isTrue);
    _agree(t, r, percent: 25, next: true);
    r.close();
  });

  testWidgets('after a kill a stored find without a shortlist is unanswered and resumes on the step', (t) async {
    final r = _Rig(_plan(guide: const TripGuide(step: _step, choices: {_step: TripGuideChoice.find})));
    await _pump(t, r);
    expect(find.text("Let's get you there"), findsOneWidget);
    _agree(t, r, percent: 0, next: false);
    expect(find.text('Find taxis'), findsOneWidget);
    r.close();
  });

  testWidgets('after a kill a stored find with a shortlist but no send or Not now stays unanswered', (t) async {
    final r = _Rig(_plan(guide: const TripGuide(step: _step, choices: {_step: TripGuideChoice.find})));
    await r.shortlist(2);
    await _pump(t, r);
    expect(find.text('Great picks'), findsOneWidget);
    _agree(t, r, percent: 0, next: false);
    r.close();
  });

  testWidgets('a stored find is not written back to the plan', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    await _tap(t, 'Help me find');
    expect(r.c.plan.value!.guide?.choices[_step], isNull);
    r.close();
  });

  testWidgets('forward jumps need every step before them answered', (t) async {
    final r = _Rig(_plan());
    await _pump(t, r);
    r.c.guideGoTo(3);
    expect(r.c.guideState.index.value, 0);
    await _tap(t, 'Skip this');
    r.c.guideGoTo(2);
    expect(r.c.guideState.index.value, 0);
    r.c.guideGoTo(1);
    expect(r.c.guideState.index.value, 1);
    r.close();
  });

  group('real font screenshots', () {
    final configs = <(String, Size, double)>[
      ('360x800', const Size(360, 800), 1.0),
      ('300x640', const Size(300, 640), 1.0),
      ('360x800_s13', const Size(360, 800), 1.3),
    ];
    for (final cfg in configs) {
      testWidgets('A_* states at ${cfg.$1}', (t) async {
        final r = _Rig(_plan());
        r.reply = (ids) => [for (final id in ids) TripSendResult(listingId: id, status: 'Sent')];
        r.wireSender();
        await _pump(t, r, size: cfg.$2, scale: cfg.$3);
        await shot(t, 'A_question_${cfg.$1}');
        await _tap(t, 'Help me find');
        await settlePhone(t);
        await shot(t, 'A_find0_${cfg.$1}');
        await r.shortlist(2);
        await t.pump();
        await settlePhone(t);
        await shot(t, 'A_review_${cfg.$1}');
        await _tap(t, 'Send to all');
        await settlePhone(t);
        expect(find.text('Enquiry sent'), findsOneWidget);
        await shot(t, 'A_sent_${cfg.$1}');
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 6));
        r.close();
      });
    }
  });
}
