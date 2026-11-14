import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/widgets/guide/trip_guide_header_text.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

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
      const MarkBookedResult(closedEnquiries: 1, closedShortlist: 1);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const _phone = Size(392, 820);

TripSpotRef _spot(String id) => TripSpotRef(id: id, name: id, latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60);

TripPlan _plan(List<String> cities, {List<int>? perLeg, int? adults = 2, int kids = 0, bool dated = true}) {
  final counts = perLeg ?? [for (var i = 0; i < cities.length; i++) 2];
  final days = <TripDay>[];
  var day = 1;
  for (var k = 1; k <= cities.length; k++) {
    for (var j = 0; j < counts[k - 1]; j++) {
      days.add(TripDay(day: day, leg: k, spots: [_spot('s$day'), _spot('t$day')]));
      day++;
    }
  }
  return TripPlan(
    legs: [for (var k = 1; k <= cities.length; k++) TripCityLeg(index: k, cityKey: k, cityName: cities[k - 1], latitude: 29.4 + k / 10, longitude: 79.4)],
    days: days,
    settings: TripSettings(startDate: dated ? DateTime(2030, 11, 14) : null, adults: adults, kids: kids),
    steps: const TripSteps(startFrom: TripStartFrom(name: 'Kamalwaganja', lat: 29.21, lon: 79.45)),
  );
}

Future<TripPlanController> _rig(WidgetTester t, TripPlan plan, {int index = 0}) async {
  final sl = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  Get.put<TripPlanController>(c, permanent: true);
  c.planStep.value = 2;
  await pumpPhone(t, const TripPlanScreen(), size: _phone);
  await settlePhone(t);
  c.guideState.on.value = true;
  await settlePhone(t);
  await _goto(t, c, index);
  return c;
}

Future<void> _goto(WidgetTester t, TripPlanController c, int index) async {
  c.guideState.index.value = index;
  await settlePhone(t);
}

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(ValueKey(key))).data ?? '';

String _asset(WidgetTester t) {
  final img = t.widget<Image>(find.descendant(of: find.byKey(GuideSheetScaffold.circleKey), matching: find.byType(Image)).first);
  return (img.image as AssetImage).assetName;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('SheetModalBody has the red close X and closes with null', (t) async {
    Object? result = 'unset';
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<String>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SheetModalBody(tone: ListingTone.coral, art: ListingArt.taxi, title: 'Great picks'),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final x = find.byType(SheetCloseButton);
    expect(x, findsOneWidget);
    expect(t.getSize(x), const Size(44, 44));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    final icon = t.widget<Icon>(find.descendant(of: x, matching: find.byType(Icon)));
    expect(icon.icon, Icons.close_rounded);
    expect(icon.size, 16);
    expect(icon.color, DesignColors.error);
    final sheet = t.getRect(find.byType(SheetModalBody));
    expect(t.getRect(x).right, lessThanOrEqualTo(sheet.right));
    await t.tap(x);
    await t.pumpAndSettle();
    expect(find.byType(SheetModalBody), findsNothing);
    expect(result, isNull);
  });

  tearDown(Get.reset);

  group('header text', () {
    final one = _plan(['Nainital'], perLeg: [3]);
    final two = _plan(['Nainital', 'Mukteshwar']);
    final three = _plan(['Nainital', 'Bhimtal', 'Mukteshwar'], perLeg: [2, 1, 2]);
    TripGuideHeaderText of(TripPlan p, TripEasyRowKind k, [int? leg]) => TripGuideHeaderText.of(p, TripEasyRowKey(k, leg));

    test('getting there: first city, day one, people', () {
      for (final p in [one, two, three]) {
        final h = of(p, TripEasyRowKind.gettingThere);
        expect(h.title, 'To Nainital');
        expect(h.subtitle, '14 Nov · 2 people');
      }
    });

    test('stay: its city, nights, its date range', () {
      expect(of(one, TripEasyRowKind.stay, 1).title, 'Nainital');
      expect(of(one, TripEasyRowKind.stay, 1).subtitle, '3 nights · 14-17 Nov · 2 people');
      expect(of(two, TripEasyRowKind.stay, 1).subtitle, '2 nights · 14-16 Nov · 2 people');
      expect(of(two, TripEasyRowKind.stay, 2).title, 'Mukteshwar');
      expect(of(two, TripEasyRowKind.stay, 2).subtitle, '2 nights · 16-18 Nov · 2 people');
      expect(of(three, TripEasyRowKind.stay, 2).subtitle, '1 night · 16-17 Nov · 2 people');
    });

    test('sightseeing taxi: 1 or 2 cities joined, 3 or more first +N more', () {
      expect(of(one, TripEasyRowKind.taxi).title, 'Nainital');
      expect(of(one, TripEasyRowKind.taxi).subtitle, '3 days · 14-16 Nov · 2 people');
      expect(of(two, TripEasyRowKind.taxi).title, 'Nainital & Mukteshwar');
      expect(of(two, TripEasyRowKind.taxi).subtitle, '4 days · 14-17 Nov · 2 people');
      expect(of(three, TripEasyRowKind.taxi).title, 'Nainital +2 more');
      expect(of(three, TripEasyRowKind.taxi).subtitle, '5 days · 14-18 Nov · 2 people');
    });

    test('between cities: previous to city, that day', () {
      expect(of(two, TripEasyRowKind.between, 2).title, 'Nainital to Mukteshwar');
      expect(of(two, TripEasyRowKind.between, 2).subtitle, 'On 16 Nov · 2 people');
      expect(of(three, TripEasyRowKind.between, 2).title, 'Nainital to Bhimtal');
      expect(of(three, TripEasyRowKind.between, 3).title, 'Bhimtal to Mukteshwar');
      expect(of(three, TripEasyRowKind.between, 3).subtitle, 'On 17 Nov · 2 people');
    });

    test('coming back: Back home, last city, last day', () {
      for (final p in [one, two, three]) {
        expect(of(p, TripEasyRowKind.comingBack).title, 'Back home');
      }
      expect(of(one, TripEasyRowKind.comingBack).subtitle, 'From Nainital · 16 Nov · 2 people');
      expect(of(two, TripEasyRowKind.comingBack).subtitle, 'From Mukteshwar · 17 Nov · 2 people');
      expect(of(three, TripEasyRowKind.comingBack).subtitle, 'From Mukteshwar · 18 Nov · 2 people');
    });

    test('long names pass through whole', () {
      final p = _plan(['Kamalwaganja Malla Talla Nainital', 'Mukteshwar Mountain Range View Point']);
      expect(of(p, TripEasyRowKind.between, 2).title, 'Kamalwaganja Malla Talla Nainital to Mukteshwar Mountain Range View Point');
      expect(of(p, TripEasyRowKind.taxi).title, 'Kamalwaganja Malla Talla Nainital & Mukteshwar Mountain Range View Point');
    });

    test('no dates and no people leave those parts out', () {
      final p = _plan(['Nainital', 'Mukteshwar'], adults: null, dated: false);
      expect(of(p, TripEasyRowKind.gettingThere).subtitle, '');
      expect(of(p, TripEasyRowKind.stay, 1).subtitle, '2 nights');
      expect(of(p, TripEasyRowKind.taxi).subtitle, '4 days');
      expect(of(p, TripEasyRowKind.between, 2).subtitle, '');
      expect(of(p, TripEasyRowKind.comingBack).subtitle, 'From Mukteshwar');
    });

    test('adults and kids count as people, one is a person', () {
      expect(of(_plan(['Nainital'], adults: 2, kids: 1), TripEasyRowKind.gettingThere).subtitle, '14 Nov · 3 people');
      expect(of(_plan(['Nainital'], adults: 1), TripEasyRowKind.gettingThere).subtitle, '14 Nov · 1 person');
    });
  });

  group('guide screen at 392 x 820', () {
    final cases = <(String, int, String, String, String)>[
      ('Getting there', 0, 'To Nainital', '14 Nov · 2 people', ListingArt.taxi),
      ('Stay', 1, 'Nainital', '2 nights · 14-16 Nov · 2 people', ListingArt.stay),
      ('Sightseeing taxi', 2, 'Nainital & Mukteshwar', '4 days · 14-17 Nov · 2 people', ListingArt.taxi),
      ('Between cities', 3, 'Nainital to Mukteshwar', 'On 16 Nov · 2 people', ListingArt.bus),
      ('Coming back', 5, 'Back home', 'From Mukteshwar · 17 Nov · 2 people', ListingArt.airplane),
    ];
    for (final (name, index, title, sub, art) in cases) {
      testWidgets('$name: header text, circle, icon, no scroll', (t) async {
        final c = await _rig(t, _plan(['Nainital', 'Mukteshwar']), index: index);
        expect(find.text('Make it easy below'), findsNothing);
        expect(_text(t, 'guide_title'), title);
        expect(_text(t, 'guide_subtitle'), sub);
        expect(_asset(t), art);

        final header = t.getRect(find.byType(TripPlanHeader));
        final circle = t.getRect(find.byKey(GuideSheetScaffold.circleKey));
        expect(circle.size, const Size(88, 88));
        expect(circle.left, 20);
        expect(circle.center.dy, closeTo(header.bottom, 0.5), reason: 'circle sits half on header, half on page');
        expect(circle.top, lessThan(header.bottom));
        expect(circle.bottom, greaterThan(header.bottom));

        final scrollable = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first);
        expect(scrollable.position.maxScrollExtent, 0, reason: '$name sheet must not scroll');
        expect(c.guideState.stepNow, isNotNull);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('sheet starts 56 below the header, much higher than before', (t) async {
      await _rig(t, _plan(['Nainital', 'Mukteshwar']));
      final header = t.getRect(find.byType(TripPlanHeader));
      final eyebrow = t.getRect(find.textContaining('GETTING THERE'));
      expect(eyebrow.top - header.bottom, inInclusiveRange(56, 100));
    });

    testWidgets('status pill shows a real status, nothing otherwise', (t) async {
      final c = await _rig(t, _plan(['Nainital', 'Mukteshwar']));
      expect(find.byKey(const ValueKey('guide_status_pill')), findsNothing);
      c.offline.value = true;
      await settlePhone(t);
      final pill = find.byKey(const ValueKey('guide_status_pill'));
      expect(pill, findsOneWidget);
      expect(find.descendant(of: pill, matching: find.text('Saved on this phone')), findsOneWidget);
      final chip = t.getRect(find.textContaining('Relaxed'));
      expect(t.getRect(pill).right, lessThan(chip.left));
      expect(t.getRect(pill).left, greaterThanOrEqualTo(108), reason: 'pill stays clear of the circle');
      c.offline.value = false;
      c.saveFailed.value = true;
      await settlePhone(t);
      expect(find.text('Saved on this phone'), findsOneWidget);
    });

    for (final cities in [
      ['Kamalwaganja Malla Talla', 'Mukteshwar Mountain Range', 'Bhimtal Lake Side Village'],
      ['Nainital', 'Bhimtal', 'Mukteshwar', 'Ranikhet Hill Station Lower'],
    ]) {
      testWidgets('${cities.length} cities, long names: titles are never cut', (t) async {
        final c = await _rig(t, _plan(cities, perLeg: [for (final _ in cities) 1]));
        final total = c.guideState.total.value;
        for (var i = 0; i < total; i++) {
          await _goto(t, c, i);
          final title = find.byKey(const ValueKey('guide_title'));
          final p = t.renderObject<RenderParagraph>(title);
          expect(p.didExceedMaxLines, isFalse, reason: 'step $i: ${_text(t, 'guide_title')}');
          expect(t.widget<Text>(title).overflow, isNot(TextOverflow.ellipsis));
          expect(t.getRect(title).bottom, lessThanOrEqualTo(t.getRect(find.byType(TripPlanHeader)).bottom));
          final map = t.getRect(find.byTooltip('Map'));
          expect(t.getRect(title).right, lessThanOrEqualTo(map.left + 0.5), reason: 'title under Map at step $i');
          expect(t.takeException(), isNull);
        }
      });
    }

    testWidgets('offline banner stays clear of the circle', (t) async {
      final c = await _rig(t, _plan(['Nainital', 'Mukteshwar']));
      c.offline.value = true;
      await settlePhone(t);
      final banner = t.getRect(find.text('Offline. Your plan is saved on this phone.'));
      final circle = t.getRect(find.byKey(GuideSheetScaffold.circleKey));
      expect(banner.left, greaterThanOrEqualTo(circle.right));
      expect(t.takeException(), isNull);
    });

    testWidgets('long status wraps inside the pill and stays clear of the circle', (t) async {
      final c = await _rig(t, _plan(['Nainital', 'Mukteshwar']));
      c.settingsChangedAt.value = DateTime.now();
      c.offline.value = true;
      c.saveFailed.value = false;
      await settlePhone(t);
      expect(t.getRect(find.byKey(const ValueKey('guide_status_pill'))).left, greaterThanOrEqualTo(108));
      expect(t.takeException(), isNull);
    });

    testWidgets('finish screen keeps the whole trip name', (t) async {
      final c = await _rig(t, _plan(['Nainital', 'Mukteshwar']));
      await _goto(t, c, c.guideState.total.value);
      expect(find.byKey(const ValueKey('guide_title')), findsNothing);
      expect(find.byKey(GuideSheetScaffold.circleKey), findsNothing);
      expect(find.text(c.title), findsWidgets);
    });
  });
}
