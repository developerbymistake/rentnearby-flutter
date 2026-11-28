import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/b/widgets/sliding_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../shared/social_test_support.dart';

class _Host extends StatefulWidget {
  const _Host({this.labels = const ['Explore', 'My posts'], this.initial = 0});

  final List<String> labels;
  final int initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int selected = widget.initial;
  final taps = <int>[];

  void pick(int i) => setState(() => selected = i);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: SlidingTabs(
            labels: widget.labels,
            selected: selected,
            tone: ListingTone.indigo,
            onTap: (i) => setState(() {
              taps.add(i);
              selected = i;
            }),
          ),
        ),
      );
}

Rect _pill(WidgetTester t) => t.getRect(find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(DecoratedBox)).first);

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  for (final size in socialSizes) {
    for (final scale in socialScales) {
      testWidgets('one track, the filled pill slides to the tapped tab ($size, $scale)', (t) async {
        await pumpSocial(t, const _Host(), size: size, textScale: scale);
        expect(find.byType(AnimatedPositioned), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final track = t.getRect(find.byType(SlidingTabs));
        final first = _pill(t);
        expect(first.width, lessThan(track.width / 2));
        expect(first.width, greaterThan(track.width * 0.4));
        expect(first.left, lessThan(track.center.dx));
        await t.tap(find.byKey(SlidingTabs.tabKey(1)));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        final mid = _pill(t);
        expect(mid.left, greaterThan(first.left));
        await t.pumpAndSettle();
        final second = _pill(t);
        expect(second.left, greaterThanOrEqualTo(track.center.dx - 1));
        expect(second.width, closeTo(first.width, 0.5));
        final host = t.state<_HostState>(find.byType(_Host));
        expect(host.taps, [1]);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('the selected label is white on the pill, the other is body ink; labels never wrap', (t) async {
    await pumpSocial(t, const _Host());
    Text label(String s) => t.widget<Text>(find.text(s));
    expect(label('Explore').style?.color, DesignColors.onPrimary);
    expect(label('My posts').style?.color, Ink3D.body);
    expect(label('Explore').maxLines, 1);
    await t.tap(find.text('My posts'));
    await t.pumpAndSettle();
    expect(label('Explore').style?.color, Ink3D.body);
    expect(label('My posts').style?.color, DesignColors.onPrimary);
  });

  testWidgets('each tab is a selectable button for TalkBack', (t) async {
    final handle = t.ensureSemantics();
    await pumpSocial(t, const _Host());
    expect(t.getSemantics(find.byKey(SlidingTabs.tabKey(0))), containsSemantics(label: 'Explore', isButton: true, isSelected: true));
    expect(t.getSemantics(find.byKey(SlidingTabs.tabKey(1))), containsSemantics(label: 'My posts', isButton: true, isSelected: false));
    handle.dispose();
  });

  final days = [for (var d = 1; d <= 10; d++) 'Day $d'];

  for (final scale in socialScales) {
    testWidgets('many tabs: the row scrolls, cells keep the min width, the selected cell is brought into view ($scale)', (t) async {
      await pumpSocial(t, _Host(labels: days), size: const Size(360, 1400), textScale: scale);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final track = t.getRect(find.byType(SlidingTabs));
      final minCell = DS.s(SlidingTabs.minCell) * scale;
      final cell = t.getRect(find.byKey(SlidingTabs.tabKey(0)));
      expect(cell.width, closeTo(minCell, 0.5));
      expect(cell.width * days.length, greaterThan(track.width));
      expect(t.getRect(find.byKey(SlidingTabs.tabKey(9))).left, greaterThan(track.right));
      t.state<_HostState>(find.byType(_Host)).pick(9);
      await t.pumpAndSettle();
      final last = t.getRect(find.byKey(SlidingTabs.tabKey(9)));
      expect(last.left, greaterThanOrEqualTo(track.left - 0.5));
      expect(last.right, lessThanOrEqualTo(track.right + 0.5));
      expect(_pill(t).left, closeTo(last.left, 0.5));
      t.state<_HostState>(find.byType(_Host)).pick(0);
      await t.pumpAndSettle();
      final first = t.getRect(find.byKey(SlidingTabs.tabKey(0)));
      expect(first.left, greaterThanOrEqualTo(track.left - 0.5));
      expect(first.right, lessThanOrEqualTo(track.right + 0.5));
      expect(t.takeException(), isNull);
    });
  }

  for (final scale in socialScales) {
    testWidgets('5 days on a 360 dp phone fill the row with no scroll ($scale)', (t) async {
      await pumpSocial(t, _Host(labels: days.take(5).toList()), size: const Size(360, 1400), textScale: scale);
      expect(find.byType(SingleChildScrollView), findsNothing);
      final w = t.getRect(find.byKey(SlidingTabs.tabKey(0))).width;
      expect(w, greaterThanOrEqualTo(DS.s(SlidingTabs.minCell) * scale - 0.5));
      final row = t.getRect(find.byKey(SlidingTabs.tabKey(0))).left;
      expect(t.getRect(find.byKey(SlidingTabs.tabKey(4))).right, closeTo(row + 5 * w, 0.5));
      for (var i = 0; i < 5; i++) {
        expect(t.getRect(find.byKey(SlidingTabs.tabKey(i))).width, closeTo(w, 0.5));
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('few tabs share the full row evenly', (t) async {
    await pumpSocial(t, const _Host(labels: ['Day 1', 'Day 2', 'Day 3']), size: const Size(411, 1400));
    final w0 = t.getRect(find.byKey(SlidingTabs.tabKey(0))).width;
    final w2 = t.getRect(find.byKey(SlidingTabs.tabKey(2))).width;
    expect(w0, closeTo(w2, 0.5));
    expect(t.getRect(find.byKey(SlidingTabs.tabKey(2))).right, closeTo(t.getRect(find.byKey(SlidingTabs.tabKey(0))).left + 3 * w0, 0.5));
  });

  testWidgets('selected -1 hides the pill, every label is body ink; a tap still reports', (t) async {
    await pumpSocial(t, _Host(labels: days.take(3).toList(), initial: -1));
    expect(find.byType(AnimatedPositioned), findsNothing);
    for (final d in days.take(3)) {
      expect(t.widget<Text>(find.text(d)).style?.color, Ink3D.body);
    }
    await t.tap(find.text('Day 2'));
    await t.pumpAndSettle();
    expect(t.state<_HostState>(find.byType(_Host)).taps, [1]);
    expect(find.byType(AnimatedPositioned), findsOneWidget);
  });
}
