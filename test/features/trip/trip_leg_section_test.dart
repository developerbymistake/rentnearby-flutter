import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_fold_state.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_sizes.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.locked = false, this.onCustomize, this.rebuilds});

  final bool locked;
  final VoidCallback? onCustomize;
  final ValueNotifier<int>? rebuilds;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final fold = TripLegFoldState();

  @override
  void dispose() {
    fold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: Listenable.merge([fold, widget.rebuilds]),
          builder: (_, _) => TripLegSectionHeader(
            title: 'Nainital',
            rangeLine: 'Days 1-3 · 18-20 Dec',
            detailLine: '12 spots · 3 nights',
            foldedLine: TripStringsDayplan.foldedSummary(3, 12),
            folded: fold.isFolded(0),
            locked: widget.locked,
            onToggle: () => fold.toggle(0),
            onCustomize: widget.onCustomize ?? () {},
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget w, Size size) => pumpAtSize(tester, w, size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open_shows_controls', (tester) async {
    await _pump(tester, const _Harness(), const Size(360, 800));
    expect(find.text('Nainital'), findsOneWidget);
    expect(find.text(TripStringsDayplan.customize), findsOneWidget);
    expect(find.text(TripStringsDayplan.hide), findsOneWidget);
    expect(find.textContaining('12 spots · 3 nights'), findsOneWidget);
    expect(find.textContaining('Tap to open'), findsNothing);
    final pill = tester.getSize(find.byKey(TripLegSectionHeader.customizeKey));
    final fold = tester.getSize(find.byKey(TripLegSectionHeader.foldKey));
    expect(fold.height, pill.height);
  });

  testWidgets('folded_shows_summary', (tester) async {
    await _pump(tester, const _Harness(), const Size(360, 800));
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 days · 12 places · Tap to open'), findsOneWidget);
    expect(find.text(TripStringsDayplan.show), findsOneWidget);
    expect(find.text(TripStringsDayplan.customize), findsOneWidget);
    expect(find.textContaining('12 spots'), findsNothing);
  });

  testWidgets('tap_toggles', (tester) async {
    await _pump(tester, const _Harness(), const Size(360, 800));
    await tester.tap(find.text('Nainital'));
    await tester.pumpAndSettle();
    expect(find.text(TripStringsDayplan.show), findsOneWidget);
    await tester.tap(find.byKey(TripLegSectionHeader.detailKey));
    await tester.pumpAndSettle();
    expect(find.text(TripStringsDayplan.hide), findsOneWidget);
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    expect(find.text(TripStringsDayplan.show), findsOneWidget);
  });

  testWidgets('state_survives_rebuild', (tester) async {
    final rebuilds = ValueNotifier(0);
    await _pump(tester, _Harness(rebuilds: rebuilds), const Size(360, 800));
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    rebuilds.value++;
    await tester.pumpAndSettle();
    expect(find.text(TripStringsDayplan.show), findsOneWidget);

    await _pump(tester, const _Harness(), const Size(360, 800));
    expect(find.text(TripStringsDayplan.hide), findsOneWidget);
  });

  test('fold_state_is_session_only_and_opens_all', () {
    final s = TripLegFoldState();
    expect(s.folded, isEmpty);
    s.toggle(1);
    s.set(2, true);
    expect(s.folded, {1, 2});
    s.set(2, false);
    s.openAll();
    expect(s.folded, isEmpty);
    expect(TripLegFoldState().isFolded(1), isFalse);
  });

  testWidgets('folded_look_has_layers_and_round_bottom', (tester) async {
    await _pump(tester, const _Harness(), const Size(360, 800));
    BorderRadius radius() =>
        (tester.widget<Container>(find.byKey(TripLegSectionHeader.cardKey)).decoration! as BoxDecoration).borderRadius! as BorderRadius;
    expect(find.byKey(TripLegSectionHeader.layersKey), findsNothing);
    expect(radius().bottomLeft, Radius.zero);
    expect(radius().bottomRight, Radius.zero);
    final openH = tester.getSize(find.byType(TripLegSectionHeader)).height;

    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TripLegSectionHeader.layersKey), findsOneWidget);
    expect(radius().bottomLeft, isNot(Radius.zero));
    expect(radius().bottomRight, isNot(Radius.zero));
    final layers = find.descendant(of: find.byKey(TripLegSectionHeader.layersKey), matching: find.byType(DecoratedBox));
    expect(layers, findsNWidgets(2));
    final cardBottom = tester.getBottomLeft(find.byKey(TripLegSectionHeader.cardKey)).dy;
    final sectionBottom = tester.getBottomLeft(find.byType(TripLegSectionHeader)).dy;
    for (final e in layers.evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      expect(r.bottom, greaterThan(cardBottom));
      expect(r.bottom, lessThanOrEqualTo(sectionBottom));
    }
    expect(tester.getSize(find.byType(TripLegSectionHeader)).height, greaterThan(openH));
  });

  testWidgets('folded_customize_still_works', (tester) async {
    var customized = 0;
    await _pump(tester, _Harness(onCustomize: () => customized++), const Size(360, 800));
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TripLegSectionHeader.customizeKey));
    await tester.pumpAndSettle();
    expect(customized, 1);
    expect(find.text(TripStringsDayplan.show), findsOneWidget);
  });

  testWidgets('locked pill inert', (tester) async {
    var customized = 0;
    final handle = tester.ensureSemantics();
    await _pump(tester, _Harness(locked: true, onCustomize: () => customized++), const Size(360, 800));
    final label = tester.widget<Text>(find.text(TripStringsDayplan.customize));
    expect(label.style!.color, ListingPalette.indigo.tint);
    expect(
      tester.getSemantics(find.byKey(TripLegSectionHeader.customizeKey)),
      isSemantics(label: TripStringsDayplan.customize, isButton: true, hasEnabledState: true, isEnabled: false),
    );
    await tester.tap(find.byKey(TripLegSectionHeader.customizeKey));
    await tester.pumpAndSettle();
    expect(customized, 0);
    expect(find.text(TripStringsDayplan.show), findsNothing);
    handle.dispose();
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    expect(find.text(TripStringsDayplan.show), findsOneWidget);
  });

  testWidgets('unlocked pill fires its callback', (tester) async {
    var customized = 0;
    await _pump(tester, _Harness(onCustomize: () => customized++), const Size(360, 800));
    await tester.tap(find.byKey(TripLegSectionHeader.customizeKey));
    await tester.pumpAndSettle();
    expect(customized, 1);
    expect(find.text(TripStringsDayplan.hide), findsOneWidget);
  });

  testWidgets('no_three_dot', (tester) async {
    await _pump(tester, const _Harness(), const Size(600, 960));
    expect(find.byKey(const ValueKey('leg-menu')), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('customize_sits_left_of_hide_in_one_row', (tester) async {
    await _pump(tester, const _Harness(), const Size(600, 960));
    final cz = tester.getRect(find.byKey(TripLegSectionHeader.customizeKey));
    final fold = tester.getRect(find.byKey(TripLegSectionHeader.foldKey));
    final card = tester.getRect(find.byKey(TripLegSectionHeader.cardKey));
    final detail = tester.getBottomLeft(find.byKey(TripLegSectionHeader.detailKey)).dy;
    expect(cz.top, fold.top);
    expect(cz.right, lessThan(fold.left));
    expect(card.contains(cz.topLeft) && card.contains(fold.bottomRight), isTrue);
    expect(cz.bottom, lessThanOrEqualTo(detail + 1));
  });

  testWidgets('header_is_shorter_when_controls_fit', (tester) async {
    await _pump(tester, const _Harness(), const Size(600, 960));
    final wide = tester.getSize(find.byKey(TripLegSectionHeader.cardKey)).height;
    await _pump(tester, const _Harness(), const Size(320, 568));
    final narrow = tester.getSize(find.byKey(TripLegSectionHeader.cardKey)).height;
    expect(wide, lessThan(narrow));
  });

  testWidgets('narrow_stacks_controls_without_overflow', (tester) async {
    for (final scale in [1.0, 1.3]) {
      await pumpAtSize(tester, const _Harness(), const Size(320, 568), textScale: scale);
      expect(tester.takeException(), isNull);
      final cz = tester.getRect(find.byKey(TripLegSectionHeader.customizeKey));
      final detail = tester.getBottomLeft(find.byKey(TripLegSectionHeader.detailKey)).dy;
      expect(cz.top, greaterThanOrEqualTo(detail));
    }
  });

  testWidgets('fold_does_not_change_the_layout_tier', (tester) async {
    for (final size in const [Size(600, 960), Size(320, 568)]) {
      await _pump(tester, const _Harness(), size);
      final before = tester.getTopLeft(find.byKey(TripLegSectionHeader.customizeKey));
      await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byKey(TripLegSectionHeader.customizeKey));
      expect(after.dx, before.dx);
      if (size.width > 400) expect(after.dy, before.dy);
    }
  });

  testWidgets('folded_layer_room_merges_with_the_gap_below', (tester) async {
    Widget section(double gap) => Scaffold(
          body: SingleChildScrollView(
            child: TripLegSectionHeader(
              title: 'Nainital',
              rangeLine: 'Days 1-3 · 18-20 Dec',
              detailLine: '12 spots · 3 nights',
              foldedLine: TripStringsDayplan.foldedSummary(3, 12),
              folded: true,
              onToggle: () {},
              onCustomize: () {},
              gapBelow: gap,
            ),
          ),
        );
    await _pump(tester, section(0), const Size(360, 800));
    final alone = tester.getSize(find.byType(TripLegSectionHeader)).height;
    await _pump(tester, section(DS.gv(44)), const Size(360, 800));
    final merged = tester.getSize(find.byType(TripLegSectionHeader)).height;
    expect(alone - merged, closeTo(DS.s(34), 0.01));
    final cardBottom = tester.getBottomLeft(find.byKey(TripLegSectionHeader.cardKey)).dy;
    final layers = find.descendant(of: find.byKey(TripLegSectionHeader.layersKey), matching: find.byType(DecoratedBox));
    for (final e in layers.evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      expect(r.bottom, greaterThan(cardBottom));
      expect(r.bottom - cardBottom, lessThan(DS.gv(44)));
    }
  });

  testFiveSizes('leg_section_open_five_sizes', () => const _Harness());

  testFiveSizes('leg_section_folded_five_sizes', () => const _Harness(), check: (tester, _) async {
    await tester.tap(find.byKey(TripLegSectionHeader.foldKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap to open'), findsOneWidget);
  });

  testFiveSizes('leg_section_locked_five_sizes', () => const _Harness(locked: true));

  testFiveSizes('leg_section_large_text_five_sizes', () => const _Harness(), textScale: 1.6);
}
