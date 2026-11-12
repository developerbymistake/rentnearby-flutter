import 'dart:io';

import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:bakhli/features/jobs/widgets/job_list_card.dart';
import 'package:bakhli/features/jobs/widgets/jobs_ui.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/widgets/trip_card.dart';
import 'package:bakhli/features/trip/widgets/trip_page_bottom_bar.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import 'package:bakhli/widgets/role_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../golden_support.dart';

const _roles = [
  RoleModel(key: UserRoleKeys.seeker, name: 'Seeker', description: 'Plan trips, find stays and book local taxis.', sortOrder: 1),
  RoleModel(
      key: UserRoleKeys.stayOwner,
      name: 'Stay Owner',
      description: 'List your homestay or hotel, receive enquiries and post jobs for your staff and your guests.',
      sortOrder: 2),
  RoleModel(key: UserRoleKeys.taxiDriver, name: 'Taxi Driver', description: 'Offer local rides and long trips.', sortOrder: 3),
];

Widget _roleCards() => Column(children: [
      for (final r in _roles) ...[
        RoleOptionCard(role: r, selected: r.key == UserRoleKeys.stayOwner, isCurrent: r.key == UserRoleKeys.seeker, onTap: () {}),
        const SizedBox(height: 12),
      ],
    ]);

Widget _rail(double w, {String tag = 'HOMESTAY', bool featured = true}) => SizedBox(
      width: w,
      height: RailCard.height,
      child: RailCard(
        title: 'Riverside Heritage Homestay Near Naini Lake Mall Road',
        tagLabel: tag,
        locationLabel: 'Bhimtal, Nainital',
        facts: const [CardFact('4 rooms'), CardFact('Meals', tone: FactTone.cyan)],
        priceCaption: 'From',
        priceValue: '₹12,500',
        priceUnit: '/night',
        isFeatured: featured,
        tone: KitTone.stay,
        onTap: () {},
      ),
    );

Widget _rows() => Column(children: [
      ListRow(
        title: 'Hilltop Villa with a very long name that wraps',
        subtitle: 'Mussoorie, Uttarakhand',
        tag: 'STAY',
        facts: const [CardFact('3 rooms'), CardFact('Parking')],
        priceValue: '₹4,200',
        priceUnit: '/night',
        thumbnailUrl: null,
        onTap: () {},
      ),
      ListRow(title: 'Lake View Inn', subtitle: 'Nainital', priceValue: '₹2,100', priceUnit: '/night', isFeatured: true, onTap: () {}),
    ]);

Widget _hero() => HeroBanner(
    title: 'Plan your trip',
    subtitle: 'Pick places, days and a taxi in a few taps.',
    iconAsset: TravelIcon.stay,
    cta: 'Start',
    onTap: () {});

TripSummaryModel _trip() => TripSummaryModel(
      id: 'a',
      title: 'Nainital and Mussoorie',
      status: 'planned',
      cityName: 'Nainital',
      dayCount: 3,
      spotCount: 8,
      category: 'trip',
      updatedAt: DateTime(2026, 1, 1),
      legCount: 2,
      legCities: const ['Nainital', 'Mussoorie'],
      progress: const TripProgress(total: 4, done: 1, inProgress: 1, percent: 25),
    );

Widget _tripCard() => TripCard(trip: _trip(), onOpen: () {}, onAction: () {}, onDelete: () {}, onShare: () {});

Widget _job() => JobListCard(
      title: 'Front desk executive for a mountain homestay',
      roleLabel: 'Reception',
      experienceTag: '1+ yrs',
      metaLine: 'Mussoorie, Uttarakhand',
      salaryLabel: '₹18,000 - 25,000',
      salaryUnit: '/month',
      topRightText: '2d ago',
      trailingChip: 'Full time',
      accent: JobsUi.tone.accent,
      accentDark: JobsUi.tone.accentDark,
      onTap: () {},
    );

Widget _tripBar() => TripPageBottomBar(
      counterText: '3 days',
      secondaryLabel: 'Add spots',
      secondaryIcon: Icons.add_rounded,
      onSecondary: () {},
      primaryLabel: 'Continue',
      onPrimary: () {},
      hint: 'Pick at least one spot',
    );

Widget _host(Widget child, {double scale = 1, bool disableAnim = false}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: goldenSize, textScaler: TextScaler.linear(scale), disableAnimations: disableAnim),
        child: Scaffold(backgroundColor: goldenBg, body: child),
      ),
    );

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 1500));
}

void _noOverflowText(Finder f) {
  expect(f, findsWidgets);
  for (final e in f.evaluate()) {
    final ro = e.renderObject;
    if (ro is RenderParagraph) expect(ro.didExceedMaxLines, isFalse, reason: ro.text.toPlainText());
  }
}

Future<void> _golden(WidgetTester t, String name, Widget child, double scale) async {
  setGoldenView(t);
  await t.pumpWidget(goldenHost(child, scale: scale, scroll: false));
  await settleGolden(t);
  expect(t.takeException(), isNull);
  await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/${name}_$scale.png'));
}

double _scaleOf(WidgetTester t) {
  final st = t.widget<ScaleTransition>(find.descendant(of: find.byType(PressScale), matching: find.byType(ScaleTransition)).first);
  return st.scale.value;
}

void main() {
  setUpAll(loadGoldenFonts);

  group('RoleOptionCard', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('three cards have equal width and height at $scale', (t) async {
        setGoldenView(t);
        await t.pumpWidget(_host(SingleChildScrollView(padding: const EdgeInsets.all(16), child: _roleCards()), scale: scale));
        await _settle(t);
        expect(t.takeException(), isNull);
        final sizes = find.byType(RoleOptionCard).evaluate().map((e) => (e.renderObject as RenderBox).size).toList();
        expect(sizes.length, 3);
        expect(sizes[1].width, sizes[0].width);
        expect(sizes[2].width, sizes[0].width);
        if (scale == 1.0) {
          expect(sizes[1].height, sizes[0].height);
          expect(sizes[2].height, sizes[0].height);
        }
      });
    }

    testWidgets('golden', (t) => _golden(t, 'role_cards', _roleCards(), 1.0));
  });

  group('RailCard', () {
    for (final w in [RailCard.width, RailCard.gridMaxExtent]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('Featured badge visible and tag not truncated at $w x$scale', (t) async {
          setGoldenView(t);
          await t.pumpWidget(_host(Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.topLeft, child: _rail(w))), scale: scale));
          await _settle(t);
          expect(t.takeException(), isNull);
          final card = t.getRect(find.byType(RailCard));
          final badge = t.getRect(find.byType(PlanBadgeChip));
          expect(badge.left, greaterThanOrEqualTo(card.left));
          expect(badge.right, lessThanOrEqualTo(card.right));
          expect(badge.top, greaterThanOrEqualTo(card.top));
          expect(badge.bottom, lessThanOrEqualTo(card.top + RailCard.photoHeight));
          _noOverflowText(find.descendant(of: find.byType(PlanBadgeChip), matching: find.byType(Text)));
          _noOverflowText(find.descendant(of: find.byType(KitTagChip), matching: find.byType(Text)));
          final tagRect = t.getRect(find.byType(KitTagChip));
          expect(tagRect.right, lessThanOrEqualTo(card.right));
          expect(tagRect.bottom, lessThanOrEqualTo(badge.top));
        });
      }
    }

    testWidgets(
        'golden',
        (t) => _golden(t, 'rail_cards',
            Column(mainAxisSize: MainAxisSize.min, children: [_rail(RailCard.width), const SizedBox(height: 8), _rail(RailCard.gridMaxExtent)]), 1.0));
  });

  group('ListRow', () {
    testWidgets('with and without photo lay out without overflow', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_host(SingleChildScrollView(child: _rows())));
      await _settle(t);
      expect(t.takeException(), isNull);
      final rows = find.byType(ListRow).evaluate().map((e) => (e.renderObject as RenderBox).size).toList();
      expect(rows[0].width, rows[1].width);
      for (final s in rows) {
        expect(s.height, greaterThanOrEqualTo(ListRow.minHeight));
      }
      expect(find.byType(PlaceholderTile), findsWidgets);
    });
    testWidgets('golden', (t) => _golden(t, 'list_rows', _rows(), 1.0));
  });

  group('HeroBanner', () {
    testWidgets('keeps its height and title is visible', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_host(Padding(padding: const EdgeInsets.all(16), child: _hero())));
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(HeroBanner)).height, greaterThanOrEqualTo(120));
      expect(find.text('Plan your trip'), findsOneWidget);
    });
    testWidgets('golden', (t) => _golden(t, 'hero_banner', _hero(), 1.0));
  });

  group('TripCard', () {
    testWidgets('lays out inside screen width', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_host(SingleChildScrollView(padding: const EdgeInsets.all(16), child: _tripCard())));
      await _settle(t);
      expect(t.takeException(), isNull);
      final r = t.getRect(find.byType(TripCard));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(goldenSize.width));
    });
    testWidgets('golden', (t) => _golden(t, 'trip_card', _tripCard(), 1.0));
  });

  group('JobListCard', () {
    testWidgets('lays out inside screen width', (t) async {
      setGoldenView(t);
      await t.pumpWidget(_host(SingleChildScrollView(padding: const EdgeInsets.all(16), child: _job())));
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(t.getRect(find.byType(JobListCard)).right, lessThanOrEqualTo(goldenSize.width));
    });
    testWidgets('golden', (t) => _golden(t, 'job_list_card', _job(), 1.0));
  });

  group('text scale 1.3', () {
    final cases = <String, Widget Function()>{
      'role cards': _roleCards,
      'list rows': _rows,
      'hero banner': _hero,
      'trip card': _tripCard,
      'job card': _job,
      'rail card': () => _rail(RailCard.width),
    };
    for (final e in cases.entries) {
      testWidgets('${e.key} has no overflow', (t) async {
        setGoldenView(t);
        await t.pumpWidget(_host(SingleChildScrollView(padding: const EdgeInsets.all(16), child: e.value()), scale: 1.3));
        await _settle(t);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('TripPageBottomBar has no overflow', (t) async {
      setGoldenView(t);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: MediaQuery(
          data: const MediaQueryData(size: goldenSize, textScaler: TextScaler.linear(1.3)),
          child: Scaffold(bottomNavigationBar: _tripBar()),
        ),
      ));
      await _settle(t);
      expect(t.takeException(), isNull);
    });
  });

  group('bottom bars', () {
    testWidgets('TripPageBottomBar: body bottom equals visible bar top, no AbsorbPointer, columns are min-size', (t) async {
      setGoldenView(t);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: Scaffold(
          body: Container(key: const ValueKey('body'), color: goldenBg),
          bottomNavigationBar: _tripBar(),
        ),
      ));
      await _settle(t);
      expect(t.takeException(), isNull);
      final body = t.getRect(find.byKey(const ValueKey('body')));
      final bar = t.getRect(find.byType(TripPageBottomBar));
      expect(body.bottom, bar.top);
      expect(bar.bottom, goldenSize.height);
      expect(bar.height, lessThan(goldenSize.height / 3));
      expect(find.descendant(of: find.byType(TripPageBottomBar), matching: find.byType(AbsorbPointer)), findsNothing);
      for (final e in find.descendant(of: find.byType(TripPageBottomBar), matching: find.byType(Column)).evaluate()) {
        expect((e.widget as Column).mainAxisSize, MainAxisSize.min);
      }
    });

    testWidgets('TemplateBottomBar: body content bottom stays above visible bar top', (t) async {
      setGoldenView(t);
      late BuildContext bodyCtx;
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'WorkSans'),
        home: MediaQuery(
          data: const MediaQueryData(size: goldenSize, viewPadding: EdgeInsets.only(bottom: 24), padding: EdgeInsets.only(bottom: 24)),
          child: Scaffold(
            extendBody: true,
            body: Builder(builder: (c) {
              bodyCtx = c;
              return const SizedBox.expand();
            }),
            bottomNavigationBar: TemplateBottomBar(
              bottomInset: 24,
              selectedIndex: 0,
              onTap: (_) {},
              items: const [
                TemplateNavItem(index: 0, label: 'Home', image: 'assets/images/design/fitness_app/tab_1.png'),
                TemplateNavItem(index: 1, label: 'Trips', image: 'assets/images/design/travel3d/compass.png', center: true),
                TemplateNavItem(index: 2, label: 'Profile', image: 'assets/images/design/fitness_app/tab_2.png'),
              ],
            ),
          ),
        ),
      ));
      await _settle(t);
      expect(t.takeException(), isNull);
      final shape = t.getRect(find.descendant(of: find.byType(TemplateBottomBar), matching: find.byType(PhysicalShape)).first);
      final bodyBottom = goldenSize.height - BarMetrics.bodyBottomOf(bodyCtx);
      expect(bodyBottom, lessThanOrEqualTo(shape.top));
      expect(shape.bottom, goldenSize.height);
      expect(find.descendant(of: find.byType(TemplateBottomBar), matching: find.byType(AbsorbPointer)), findsNothing);
    });

    test('no bottom-bar source uses AbsorbPointer', () {
      const files = [
        'lib/features/trip/widgets/trip_page_bottom_bar.dart',
        'lib/design/extra/template_nav.dart',
        'lib/design/template/bottom_navigation_view/bottom_bar_view.dart',
      ];
      for (final f in files) {
        expect(File(f).readAsStringSync().contains('AbsorbPointer'), isFalse, reason: f);
      }
      final lib = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final f in lib) {
        final src = f.readAsStringSync();
        if (!src.contains('bottomNavigationBar:')) continue;
        expect(src.contains('AbsorbPointer'), isFalse, reason: f.path);
      }
    });
  });

  group('TabEntrance', () {
    Finder op() => find.descendant(of: find.byType(TabEntrance), matching: find.byType(Opacity));

    testWidgets('visible on first build, replays every time its tab becomes active', (t) async {
      final src = 0.obs;
      await t.pumpWidget(_host(TabEntrance(tab: 1, source: src, child: const Text('x'))));
      expect(t.widget<Opacity>(op()).opacity, 1);
      for (var i = 0; i < 2; i++) {
        src.value = 1;
        await t.pump();
        await t.pump(const Duration(milliseconds: 20));
        expect(t.widget<Opacity>(op()).opacity, lessThan(1));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.widget<Opacity>(op()).opacity, 1);
        src.value = 0;
        await t.pump();
        expect(t.widget<Opacity>(op()).opacity, 1);
      }
    });

    testWidgets('never replays with disableAnimations', (t) async {
      final src = 0.obs;
      await t.pumpWidget(_host(TabEntrance(tab: 1, source: src, child: const Text('x')), disableAnim: true));
      src.value = 1;
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      expect(t.widget<Opacity>(op()).opacity, 1);
    });
  });

  group('PressScale', () {
    Future<void> build(WidgetTester t, {bool enabled = true, bool disableAnim = false}) => t.pumpWidget(_host(
        Center(child: PressScale(enabled: enabled, child: const SizedBox(width: 100, height: 60, child: Text('p')))),
        disableAnim: disableAnim));

    testWidgets('shrinks on press and returns to 1', (t) async {
      await build(t);
      expect(_scaleOf(t), 1);
      final g = await t.startGesture(t.getCenter(find.byType(PressScale)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t), lessThan(1));
      expect(_scaleOf(t), greaterThanOrEqualTo(0.9));
      await g.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_scaleOf(t), 1);
    });

    testWidgets('stays at 1 when disabled', (t) async {
      await build(t, enabled: false);
      final g = await t.startGesture(t.getCenter(find.byType(PressScale)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t), 1);
      await g.up();
    });

    testWidgets('stays at 1 with disableAnimations', (t) async {
      await build(t, disableAnim: true);
      final g = await t.startGesture(t.getCenter(find.byType(PressScale)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t), 1);
      await g.up();
    });
  });
}
