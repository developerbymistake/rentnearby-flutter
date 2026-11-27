import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/discovery_overlay.dart';
import 'package:bakhli/features/trip/trip_strings_map_disc.dart';
import 'package:bakhli/features/trip/widgets/trip_map_spot_card.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  @override
  final RxnDouble selectedScreenX = RxnDouble();
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

  testWidgets('no target day: only Details, no invented day number', (tester) async {
    await _pump(tester, TripMapSpotCard(spot: _dot, mode: DiscoveryMode.full, onAdd: () {}, onDetails: () {}), 360, 1);
    expect(find.byKey(const ValueKey('disc-card-add')), findsNothing);
    expect(find.textContaining('Day'), findsNothing);
    expect(find.byKey(const ValueKey('disc-card-details')), findsOneWidget);
  });

  testWidgets('320 @ 1.3: both button labels keep one size (wrap, no shrink)', (tester) async {
    await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, plannedDay: 2, line: _line, onRemove: () {}, onDetails: () {}), 320, 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    final a = tester.renderObject<RenderParagraph>(find.text(TripMapDiscStrings.removeFromDay));
    final b = tester.renderObject<RenderParagraph>(find.text(TripMapDiscStrings.details));
    expect(a.text.style!.fontSize, b.text.style!.fontSize);
    expect(a.textScaler, b.textScaler);
  });

  test('APP-18: the card title follows the mock 15 (w600) through the role style', () {
    final s = TripMapSpotCard.titleStyle;
    expect(s.fontSize, DS.f(15));
    expect(s.fontWeight, FontWeight.w600);
    expect(s.fontFamily, Ink3D.text(15, FontWeight.w600, Ink3D.title).fontFamily);
  });

  testWidgets('button min height is the touch token', (tester) async {
    await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, targetDay: 1, onAdd: () {}, onDetails: () {}), 360, 1);
    expect(tester.getSize(find.byKey(const ValueKey('disc-card-details'))).height, greaterThanOrEqualTo(DS.s(KitMetrics.touch) - 0.5));
  });

  testWidgets('tip: drawn under the card when tipX is given, absent otherwise', (tester) async {
    await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.readOnly), 360, 1);
    expect(find.byKey(const ValueKey('disc-card-tip')), findsNothing);
    await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.readOnly, tipX: 100), 360, 1);
    final card = tester.getRect(find.byKey(const ValueKey('disc-card')));
    final tip = tester.getRect(find.byKey(const ValueKey('disc-card-tip')));
    expect(tip.bottom, greaterThan(card.bottom));
    expect(tip.center.dx, closeTo(card.left + 100, 1.5));
  });

  group('3D restyle (map spot card mock)', () {
    BoxDecoration face(WidgetTester tester, String key) => tester
        .widget<DecoratedBox>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('disc-card-btn-face'))))
        .decoration as BoxDecoration;
    Color labelColor(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;
    BoxDecoration deco(WidgetTester tester, String key) => tester.widget<Container>(find.byKey(ValueKey(key))).decoration! as BoxDecoration;

    testWidgets('default tone is indigo: gradient Add, white Details pill with indigo text', (tester) async {
      await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, targetDay: 1, onAdd: () {}, onDetails: () {}), 360, 1);
      final tone = ListingTone.indigo;
      expect(face(tester, 'disc-card-add').gradient, tone.gradient);
      expect(face(tester, 'disc-card-add').boxShadow, tone.glow());
      final det = face(tester, 'disc-card-details');
      expect(det.color, DesignColors.surface);
      expect(det.gradient, isNull);
      expect(det.boxShadow, DS.shadows(Ink3D.softShadow));
      expect(labelColor(tester, TripMapDiscStrings.details), tone.text);
    });

    testWidgets('forest tone reaches every tone slot (Add, Details, category pill, close dot, card glow)', (tester) async {
      final tone = ListingTone.forest;
      await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, targetDay: 1, tone: tone, onAdd: () {}, onDetails: () {}), 360, 1);
      expect(face(tester, 'disc-card-add').gradient, tone.gradient);
      expect(labelColor(tester, TripMapDiscStrings.details), tone.text);
      expect(deco(tester, 'disc-card-cat').color, tone.tint);
      expect(deco(tester, 'disc-card-close-dot').color, tone.tint);
      expect(tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('disc-card-close')), matching: find.byType(Icon))).color, tone.text);
      final shadows = deco(tester, 'disc-card').boxShadow!;
      expect(shadows.first.color, tone.haloBase.withValues(alpha: Alpha.v26));
      expect(shadows.length, 2);
    });

    testWidgets('Remove from day is a white pill with the danger text, no coral box', (tester) async {
      await _pump(tester, TripMapSpotCard(spot: _photo, mode: DiscoveryMode.full, plannedDay: 2, tone: ListingTone.forest, onRemove: () {}, onDetails: () {}), 360, 1);
      final rem = face(tester, 'disc-card-remove');
      expect(rem.color, DesignColors.surface);
      expect(rem.border, isNull);
      expect(labelColor(tester, TripMapDiscStrings.removeFromDay), Form3D.errorText);
    });

    testWidgets('disabled button keeps the 45% opacity', (tester) async {
      await _pump(tester, const TripMapSpotCard(spot: _photo, mode: DiscoveryMode.readOnly), 360, 1);
      final op = tester.widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('disc-card-details')), matching: find.byType(Opacity)));
      expect(op.opacity, Alpha.v45);
    });

    testWidgets('photo spot: the photo only, no icon or sticker on it (owner 2026-11-27)', (tester) async {
      await _pump(tester, const TripMapSpotCard(spot: _photo, mode: DiscoveryMode.readOnly), 360, 1);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('disc-card-art')), findsNothing);
      expect(find.byKey(const ValueKey('disc-card-sticker')), findsNothing);
      expect(find.byKey(const ValueKey('disc-card-photo')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('disc-card-photo')), matching: find.byType(Art3D)), findsNothing);
    });

    testWidgets('no-photo spot: category gradient tile with the 3D art, same slot size as a photo', (tester) async {
      await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.readOnly), 360, 1);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('disc-card-photo')), findsNothing);
      expect(find.byKey(const ValueKey('disc-card-sticker')), findsNothing);
      final art = find.byKey(const ValueKey('disc-card-art'));
      expect(deco(tester, 'disc-card-art').gradient, TripSpotLook.gradientOf('waterfall'));
      expect(tester.getSize(art), Size.square(DS.s(TripMapSpotCard.photo)));
      final a = tester.widget<Art3D>(find.descendant(of: art, matching: find.byType(Art3D)));
      expect(a.asset, TripSpotLook.assetOf('waterfall'));
      expect(a.size, TripMapSpotCard.artSize);
    });

    testWidgets('photo and no-photo cards have the same height (no jump between spots)', (tester) async {
      await _pump(tester, const TripMapSpotCard(spot: _photo, mode: DiscoveryMode.readOnly, line: 'Shimla'), 360, 1);
      final h1 = tester.getSize(find.byKey(const ValueKey('disc-card'))).height;
      await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.readOnly, line: 'Shimla'), 360, 1);
      expect(tester.getSize(find.byKey(const ValueKey('disc-card'))).height, closeTo(h1, 0.5));
    });

    testWidgets('plain round corners radius 20', (tester) async {
      await _pump(tester, const TripMapSpotCard(spot: _dot, mode: DiscoveryMode.readOnly), 360, 1);
      expect(deco(tester, 'disc-card').borderRadius, DS.circular(20));
    });
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
      expect(card.top, closeTo(120 + DS.gv(DiscoveryOverlay.cardGapTop), 0.5));
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

    testWidgets('trip chip sits 36 under the header at left 18', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host())..dataState.value = DiscoveryDataState.loading;
      await pumpOverlay(tester, layer);
      final chip = tester.getRect(find.byKey(const ValueKey('disc-chip')));
      expect(chip.top, closeTo(120 + DS.gv(DiscoveryOverlay.chipGapTop), 0.5));
      expect(chip.left, closeTo(DS.s(DiscoveryOverlay.chipLeftTop), 0.5));
    });

    testWidgets('selected screen x gives the card a tip; 820 wide card is capped and centred', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host())..selected.value = _photo;
      layer.selectedScreenX.value = 400;
      await pumpPhone(
        tester,
        Scaffold(body: Stack(children: [DiscoveryOverlay(layer: layer)])),
        size: const Size(820, 760),
      );
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('disc-card')));
      expect(card.width, lessThanOrEqualTo(DS.s(TripMapSpotCard.maxWidth) + 0.5));
      expect(card.center.dx, closeTo(410, 1));
      expect(tester.getRect(find.byKey(const ValueKey('disc-card-tip'))).center.dx, closeTo(400, 1.5));
    });

    testWidgets('offline chip at 320 @ 1.3 shows the whole sentence', (tester) async {
      final layer = _FakeLayer(DiscoveryMode.full, host());
      await pumpPhone(
        tester,
        Scaffold(body: Stack(children: [DiscoveryOverlay(layer: layer, notice: () => 'Offline. Your plan is saved on this phone.')])),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      final p = tester.renderObject<RenderParagraph>(find.text('Offline. Your plan is saved on this phone.'));
      expect(p.didExceedMaxLines, isFalse);
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
