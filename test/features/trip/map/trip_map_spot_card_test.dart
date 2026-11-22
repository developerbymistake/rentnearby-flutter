import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_overlay.dart';
import 'package:bakhli/features/trip/trip_strings_map_disc.dart';
import 'package:bakhli/features/trip/widgets/trip_map_spot_card.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';

const _photo = DiscoverySpot(id: 's1', lat: 31.1, lon: 77.17, category: 'temple', rank: 1, name: 'Jakhoo Temple', cityKey: 10, thumbUrl: 'https://res.cloudinary.com/x/image/upload/v1/a.jpg');
const _dot = DiscoverySpot(id: 's2', lat: 31.1, lon: 77.17, category: 'waterfall', rank: 300, name: 'Chadwick Falls', cityKey: 10);
const _long = DiscoverySpot(
    id: 's3', lat: 31.1, lon: 77.17, category: 'temple', rank: 2, name: 'Shri Sankat Mochan Hanuman Temple and the old deodar forest walk above the Ridge', cityKey: 10, thumbUrl: 'https://x/image/upload/a.jpg');
const _line = 'Hilltop temple in deodar woods above the Ridge with a long view over the town';

const _widths = [320.0, 360.0, 411.0];
const _scales = [1.0, 1.3];

class _FakeLayer implements DiscoveryLayerApi {
  @override
  final DiscoveryMode mode;
  @override
  final DiscoveryHost host;
  @override
  final DiscTuning tuning = DiscTuning.trip;
  @override
  final RxBool attached = true.obs;
  @override
  final RxBool eyeOn = true.obs;
  @override
  final RxBool hasSpotsHere = true.obs;
  @override
  final Rx<DiscoveryDataState> dataState = DiscoveryDataState.ready.obs;
  @override
  final Rxn<DiscoverySpot> selected = Rxn<DiscoverySpot>();
  @override
  final RxnInt selectedPlannedDay = RxnInt();
  final eyeCalls = <bool>[];
  int clears = 0;

  _FakeLayer(this.mode, this.host);

  @override
  Future<void> setEye(bool on) async {
    eyeCalls.add(on);
    eyeOn.value = on;
  }

  @override
  Future<void> clearSelection() async {
    clears++;
    selected.value = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _frame(Widget child, double width) => Scaffold(
      backgroundColor: const Color(0xFFEDE8DF),
      body: Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.fromLTRB(12, 40, 12, 0), child: SizedBox(width: width - 24, child: child))),
    );

Future<void> _pump(WidgetTester tester, Widget card, double width, double scale) =>
    pumpPhone(tester, _frame(card, width), size: Size(width, 760), textScale: scale);

void main() {
  setUpAll(() => TripSpotMedia.debugImageBuilder = (url, fit, fallback) => const ColoredBox(color: Color(0xFF5D8BD6)));
  tearDownAll(() => TripSpotMedia.debugImageBuilder = null);

  for (final w in _widths) {
    for (final ts in _scales) {
      final tag = '${w.toInt()} @ $ts';

      testWidgets('photo card, not planned: photo, category, 2-line title, 1-line line, Add to Day 2 + Details ($tag)', (tester) async {
        var added = 0, details = 0, closed = 0;
        await _pump(
            tester,
            TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, targetDay: 2, line: _line, onAdd: () => added++, onDetails: () => details++, onClose: () => closed++),
            w,
            ts);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('disc-card-photo')), findsOneWidget);
        expect(find.byKey(const ValueKey('disc-card-cat')), findsOneWidget);
        expect(find.text('Temple'), findsOneWidget);
        expect(find.text('Add to Day 2'), findsOneWidget);
        expect(find.text(TripMapDiscStrings.details), findsOneWidget);
        expect(find.text(TripMapDiscStrings.removeFromDay), findsNothing);
        final add = tester.getRect(find.byKey(const ValueKey('disc-card-add')));
        final det = tester.getRect(find.byKey(const ValueKey('disc-card-details')));
        expect(add.top, closeTo(det.top, 0.5), reason: 'buttons stay on one row');
        expect(tester.widget<Text>(find.byKey(const ValueKey('disc-card-line'))).maxLines, 1);
        await tester.tap(find.byKey(const ValueKey('disc-card-add')));
        await tester.tap(find.byKey(const ValueKey('disc-card-details')));
        await tester.tap(find.byKey(const ValueKey('disc-card-close')));
        expect((added, details, closed), (1, 1, 1));
      });

      testWidgets('dot card has no photo ($tag)', (tester) async {
        await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.full, targetDay: 1, line: 'Seasonal waterfall in a forested glen'), w, ts);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('disc-card-photo')), findsNothing);
        expect(find.text('Add to Day 1'), findsOneWidget);
      });

      testWidgets('planned card: In Day pill, Details + Remove from day on one row ($tag)', (tester) async {
        var removed = 0;
        await _pump(
            tester,
            TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, plannedDay: 2, targetDay: 2, line: _line, onRemove: () => removed++, onDetails: () {}, dayColorOf: (_) => const Color(0xFFFF8A3D)),
            w,
            ts);
        expect(tester.takeException(), isNull);
        expect(find.text('In Day 2'), findsOneWidget);
        expect(find.byKey(const ValueKey('disc-card-cat')), findsNothing);
        expect(find.byKey(const ValueKey('disc-card-add')), findsNothing);
        final rem = tester.getRect(find.byKey(const ValueKey('disc-card-remove')));
        final det = tester.getRect(find.byKey(const ValueKey('disc-card-details')));
        expect(rem.top, closeTo(det.top, 0.5));
        expect(det.left, lessThan(rem.left), reason: 'Details first, Remove second');
        await tester.tap(find.byKey(const ValueKey('disc-card-remove')));
        expect(removed, 1);
      });

      testWidgets('read-only card has only Details ($tag)', (tester) async {
        await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.readOnly, plannedDay: 2, targetDay: 2, line: _line, onDetails: () {}), w, ts);
        expect(tester.takeException(), isNull);
        expect(find.text(TripMapDiscStrings.details), findsOneWidget);
        expect(find.textContaining('Day'), findsNothing);
        expect(find.byKey(const ValueKey('disc-card-remove')), findsNothing);
      });

      testWidgets('long name stays within 2 lines, empty line hides the row ($tag)', (tester) async {
        await _pump(tester, const TripMapSpotCard(spot: _long, mode: DiscoveryMode.full, targetDay: 1, line: '  '), w, ts);
        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(find.byKey(const ValueKey('disc-card-title'))).maxLines, 2);
        expect(find.byKey(const ValueKey('disc-card-line')), findsNothing);
      });
    }
  }

  testWidgets('no target day disables Add to Day', (tester) async {
    var added = 0;
    await _pump(tester, TripMapSpotCard(spot: _dot, mode: DiscoveryMode.full, onAdd: () => added++), 360, 1);
    await tester.tap(find.byKey(const ValueKey('disc-card-add')), warnIfMissed: false);
    expect(added, 0);
    expect(find.descendant(of: find.byKey(const ValueKey('disc-card-add')), matching: find.byType(Opacity)), findsOneWidget);
  });

  group('DiscoveryOverlay', () {
    DiscoveryHost host({List<DiscoverySpot>? added, int? target = 2}) => DiscoveryHost(
          anchorLayerId: () => null,
          plannedDayOf: (_) => null,
          topInset: () => 120,
          bottomInset: () => 80,
          targetDayFor: (_) => target,
          onAdd: (s) => added?.add(s),
          onDetails: (_) {},
          lineFor: (_) => _line,
        );

    Future<void> pumpOverlay(WidgetTester tester, _FakeLayer layer, {DiscoveryPlacement placement = DiscoveryPlacement.top, String? Function()? notice}) =>
        pumpPhone(
          tester,
          Scaffold(
            body: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFEDE8DF))),
              DiscoveryOverlay(layer: layer, placement: placement, notice: notice),
            ]),
          ),
          size: const Size(360, 760),
        );

    testWidgets('not attached: nothing shows', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host())..attached.value = false;
      await pumpOverlay(tester, layer);
      expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
      expect(find.byKey(const ValueKey('disc-zoom-in')), findsNothing);
    });

    testWidgets('top placement: controls column, card under the header, Add calls the host, chevron clears', (tester) async {
      final added = <DiscoverySpot>[];
      final layer = _FakeLayer(DiscoveryMode.full, host(added: added));
      await pumpOverlay(tester, layer);
      expect(find.byKey(const ValueKey('disc-eye')), findsOneWidget);
      final eye = tester.getRect(find.byKey(const ValueKey('disc-eye')));
      final locate = tester.getRect(find.byKey(const ValueKey('disc-locate')));
      expect(locate.top, greaterThan(eye.bottom));
      expect(eye.left, closeTo(locate.left, 0.5));
      expect(find.byKey(const ValueKey('disc-card')), findsNothing);
      layer.selected.value = _photo;
      await tester.pump();
      final card = tester.getRect(find.byKey(const ValueKey('disc-card')));
      expect(card.top, greaterThan(120));
      expect(card.top, lessThan(150));
      await tester.tap(find.text('Add to Day 2'));
      expect(added.single.id, 's1');
      await tester.tap(find.byKey(const ValueKey('disc-card-close')));
      await tester.pump();
      expect(layer.clears, 1);
      expect(find.byKey(const ValueKey('disc-card')), findsNothing);
    });

    testWidgets('planned selection shows the In Day state; eye tap toggles through the layer', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host());
      layer.selected.value = _photo;
      layer.selectedPlannedDay.value = 3;
      await pumpOverlay(tester, layer);
      expect(find.text('In Day 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('disc-eye')));
      await tester.pump();
      expect(layer.eyeCalls, [false]);
    });

    testWidgets('loading: chip and ring; ready with zero spots: no eye, no chip', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host())..dataState.value = DiscoveryDataState.loading;
      await pumpOverlay(tester, layer);
      expect(find.text(TripMapDiscStrings.loadingPlaces), findsOneWidget);
      expect(find.byKey(const ValueKey('disc-eye-ring')), findsOneWidget);
      layer.dataState.value = DiscoveryDataState.ready;
      layer.hasSpotsHere.value = false;
      await tester.pump();
      expect(find.byKey(const ValueKey('disc-chip')), findsNothing);
      expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
      expect(find.byKey(const ValueKey('disc-zoom-in')), findsOneWidget);
    });

    testWidgets('offline notice shows the existing offline text', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host());
      await pumpOverlay(tester, layer, notice: () => 'Offline. Your plan is saved on this phone.');
      expect(find.text('Offline. Your plan is saved on this phone.'), findsOneWidget);
    });

    testWidgets('bottom placement, read-only: no controls, card above the bottom inset with only Details', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.readOnly, const DiscoveryHost.readOnly(bottomInset: _eighty))..selected.value = _photo;
      await pumpOverlay(tester, layer, placement: DiscoveryPlacement.bottom);
      expect(find.byKey(const ValueKey('disc-eye')), findsNothing);
      final card = tester.getRect(find.byKey(const ValueKey('disc-card')));
      expect(card.bottom, lessThan(760 - 80));
      expect(card.bottom, greaterThan(760 - 80 - 20));
      expect(find.byKey(const ValueKey('disc-card-add')), findsNothing);
      expect(find.text(TripMapDiscStrings.details), findsOneWidget);
    });

    testWidgets('taps outside the overlay children reach the map below', (tester) async {
      var mapTaps = 0;
      final layer = _FakeLayer(DiscoveryMode.full, host());
      await pumpPhone(
        tester,
        Scaffold(
          body: Stack(children: [
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => mapTaps++)),
            DiscoveryOverlay(layer: layer),
          ]),
        ),
        size: const Size(360, 760),
      );
      await tester.tapAt(const Offset(60, 600));
      expect(mapTaps, 1);
    });
  });
}

double _eighty() => 80;
