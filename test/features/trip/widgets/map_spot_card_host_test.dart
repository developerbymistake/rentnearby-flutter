import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/trip/widgets/map_spot_card_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Card extends StatelessWidget {
  const _Card(this.id, this.onTap);

  final String id;
  final VoidCallback onTap;

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(key: ValueKey('card-$id'), width: 300, height: id == 'b' ? 140 : 90, child: const ColoredBox(color: Colors.white)),
    );
  }
}

class _Rig {
  final spot = ValueNotifier<String?>(null);
  int closes = 0;
  int taps = 0;
  int parentBuilds = 0;

  Widget build({MapSpotCardEdge edge = MapSpotCardEdge.top, bool reduce = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduce),
          child: Scaffold(
            body: ValueListenableBuilder<String?>(
              valueListenable: spot,
              builder: (_, id, _) {
                parentBuilds++;
                return Align(
                  alignment: edge == MapSpotCardEdge.top ? Alignment.topCenter : Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 100),
                    child: MapSpotCardHost(
                      id: id,
                      label: id == null ? null : 'Spot $id',
                      edge: edge,
                      onClose: () {
                        closes++;
                        spot.value = null;
                      },
                      child: id == null ? null : _Card(id, () => taps++),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

Finder _card(String id) => find.byKey(ValueKey('card-$id'));

FadeTransition _fade(WidgetTester t) =>
    t.widget<FadeTransition>(find.descendant(of: find.byKey(const ValueKey('map-card-host')), matching: find.byType(FadeTransition)).first);

bool _guarded(WidgetTester t) => t.widget<IgnorePointer>(find.byKey(const ValueKey('map-card-exit-guard'))).ignoring;

Future<_Rig> _open(WidgetTester t, {MapSpotCardEdge edge = MapSpotCardEdge.top, bool reduce = false}) async {
  final rig = _Rig();
  await t.pumpWidget(rig.build(edge: edge, reduce: reduce));
  rig.spot.value = 'a';
  await t.pump();
  await t.pump(MapSpotCardHost.openDuration);
  return rig;
}

void main() {
  testWidgets('nothing is built while no spot is selected', (t) async {
    final rig = _Rig();
    await t.pumpWidget(rig.build());
    expect(find.byKey(const ValueKey('map-card-host')), findsNothing);
  });

  testWidgets('open: fades in and slides 12 dp from the top edge in 240 ms, the card is built once', (t) async {
    final rig = _Rig();
    await t.pumpWidget(rig.build());
    _Card.builds = 0;
    rig.spot.value = 'a';
    await t.pump();
    expect(_fade(t).opacity.value, 0);
    final start = t.getTopLeft(_card('a')).dy;
    await t.pump(MapSpotCardHost.openDuration ~/ 2);
    final mid = _fade(t).opacity.value;
    expect(mid, inExclusiveRange(0.5, 1), reason: 'easeOutCubic is past half way at half time');
    await t.pump(MapSpotCardHost.openDuration ~/ 2);
    expect(_fade(t).opacity.value, 1);
    final rest = t.getTopLeft(_card('a')).dy;
    expect(rest - start, closeTo(DS.s(MapSpotCardHost.slide), 0.01));
    expect(_Card.builds, 1);
    expect(_guarded(t), isFalse);
  });

  testWidgets('bottom edge: the card rises from below', (t) async {
    final rig = _Rig();
    await t.pumpWidget(rig.build(edge: MapSpotCardEdge.bottom));
    rig.spot.value = 'a';
    await t.pump();
    final start = t.getTopLeft(_card('a')).dy;
    await t.pump(MapSpotCardHost.openDuration);
    expect(start - t.getTopLeft(_card('a')).dy, closeTo(DS.s(MapSpotCardHost.slide), 0.01));
  });

  testWidgets('close: the last spot stays visible for 180 ms, ignores taps, then leaves', (t) async {
    final rig = await _open(t);
    final builds = rig.parentBuilds;
    rig.spot.value = null;
    await t.pump();
    expect(_card('a'), findsOneWidget);
    expect(_guarded(t), isTrue);
    await t.tap(_card('a'), warnIfMissed: false);
    expect(rig.taps, 0);
    await t.pump(MapSpotCardHost.closeDuration ~/ 2);
    expect(_fade(t).opacity.value, inExclusiveRange(0, 1));
    await t.pump(MapSpotCardHost.closeDuration);
    await t.pump();
    expect(_card('a'), findsNothing);
    expect(find.byKey(const ValueKey('map-card-host')), findsNothing);
    expect(rig.parentBuilds, builds + 1, reason: 'the animation never rebuilds the parent (the map)');
  });

  testWidgets('a new spot during the exit reopens the card and taps work again', (t) async {
    final rig = await _open(t);
    rig.spot.value = null;
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    rig.spot.value = 'b';
    await t.pump();
    expect(_guarded(t), isFalse);
    await t.pump(MapSpotCardHost.openDuration);
    expect(_fade(t).opacity.value, 1);
    expect(_card('b'), findsOneWidget);
    await t.pump(MapSpotCardHost.switchDuration);
    await t.tap(_card('b'));
    expect(rig.taps, 1);
  });

  testWidgets('spot to spot: cross-fade in 160 ms, the old card takes no taps', (t) async {
    final rig = await _open(t);
    rig.spot.value = 'b';
    await t.pump();
    await t.pump(MapSpotCardHost.switchDuration ~/ 2);
    expect(_card('a'), findsOneWidget);
    expect(_card('b'), findsOneWidget);
    final old = find.ancestor(of: _card('a'), matching: find.byType(IgnorePointer)).first;
    expect(t.widget<IgnorePointer>(old).ignoring, isTrue);
    expect(_fade(t).opacity.value, 1, reason: 'the host stays open while switching');
    await t.pump(MapSpotCardHost.switchDuration);
    await t.pump();
    expect(_card('a'), findsNothing);
    expect(_card('b'), findsOneWidget);
    expect(rig.closes, 0);
  });

  testWidgets('swipe up more than 40 dp closes', (t) async {
    final rig = await _open(t);
    await t.timedDrag(_card('a'), const Offset(0, -90), const Duration(seconds: 1));
    await t.pump();
    expect(rig.closes, 1);
    await t.pump(MapSpotCardHost.closeDuration);
    await t.pump(MapSpotCardHost.closeDuration);
    await t.pump();
    expect(_card('a'), findsNothing);
  });

  testWidgets('a fast fling up closes even when short', (t) async {
    final rig = await _open(t);
    await t.timedDrag(_card('a'), const Offset(0, -36), const Duration(milliseconds: 48));
    await t.pump();
    expect(rig.closes, 1);
  });

  testWidgets('a short slow swipe snaps back and keeps the card', (t) async {
    final rig = await _open(t);
    final rest = t.getTopLeft(_card('a')).dy;
    await t.timedDrag(_card('a'), const Offset(0, -30), const Duration(seconds: 1));
    await t.pump();
    expect(rig.closes, 0);
    await t.pump(MapSpotCardHost.snapDuration);
    expect(t.getTopLeft(_card('a')).dy, closeTo(rest, 0.01));
  });

  testWidgets('a swipe away from the edge does nothing', (t) async {
    final rig = await _open(t);
    final rest = t.getTopLeft(_card('a')).dy;
    await t.timedDrag(_card('a'), const Offset(0, 120), const Duration(seconds: 1));
    await t.pump(MapSpotCardHost.snapDuration);
    expect(rig.closes, 0);
    expect(t.getTopLeft(_card('a')).dy, closeTo(rest, 0.01));
  });

  testWidgets('bottom edge: swipe down closes, swipe up does not', (t) async {
    final rig = await _open(t, edge: MapSpotCardEdge.bottom);
    await t.timedDrag(_card('a'), const Offset(0, -120), const Duration(seconds: 1));
    await t.pump(MapSpotCardHost.snapDuration);
    expect(rig.closes, 0);
    await t.timedDrag(_card('a'), const Offset(0, 90), const Duration(seconds: 1));
    await t.pump();
    expect(rig.closes, 1);
  });

  testWidgets('reduced motion: no animation in or out', (t) async {
    final rig = _Rig();
    await t.pumpWidget(rig.build(reduce: true));
    rig.spot.value = 'a';
    await t.pump();
    expect(_fade(t).opacity.value, 1);
    rig.spot.value = 'b';
    await t.pump();
    await t.pump();
    expect(_card('a'), findsNothing);
    expect(_card('b'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    rig.spot.value = null;
    await t.pump();
    expect(_card('b'), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('a11y: a live region labelled with the spot name, inside a repaint boundary', (t) async {
    await _open(t);
    final s = t.widget<Semantics>(find.byKey(const ValueKey('map-card-host')));
    expect(s.container, isTrue);
    expect(s.properties.liveRegion, isTrue);
    expect(s.properties.label, 'Spot a');
    final boundary = t.widget<RepaintBoundary>(find.ancestor(of: find.byKey(const ValueKey('map-card-host')), matching: find.byType(RepaintBoundary)).first);
    expect(boundary.child?.key, const ValueKey('map-card-host'));
  });
}
