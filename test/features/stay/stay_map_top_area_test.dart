import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/tone_segment_control.dart';
import 'package:bakhli/features/stay/guest/stay_map_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_golden/golden_support.dart';

const _labels = ['1 km', '6 km', '12 km', '20 km'];
const _sem = ['1 kilometres', '6 kilometres', '12 kilometres', '20 kilometres'];

class _Top extends StatefulWidget {
  const _Top();
  @override
  State<_Top> createState() => _TopState();
}

class _TopState extends State<_Top> {
  int sel = AppConstants.radiusOptions.indexOf(AppConstants.defaultRadiusKm);
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(gradient: ListingPalette.forest.gradient, borderRadius: DS.br(CardRadius.header)),
            padding: DS.insets(l: 20, t: 12, r: 20, b: 16),
            child: ToneSegmentControl(labels: _labels, semanticLabels: _sem, selected: sel, tone: ListingTone.forest, cellHeight: KitMetrics.touch - 8, onTap: (i) => setState(() => sel = i)),
          ),
          Padding(
            padding: EdgeInsets.only(top: DS.gv(12), left: DS.s(StayMapTopControls.side), right: DS.s(StayMapTopControls.side)),
            child: StayMapTopControls(layer: null, map: () => null, onLocate: () {}),
          ),
        ],
      );
}

Future<void> _pump(WidgetTester t, {double width = 360, double scale = 1}) async {
  setGoldenView(t, Size(width, 760));
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'WorkSans'),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 760), textScaler: TextScaler.linear(scale)),
      child: const Scaffold(body: RepaintBoundary(key: ValueKey('top'), child: Align(alignment: Alignment.topCenter, child: _Top()))),
    ),
  ));
  await t.pump();
}

TextStyle _styleOf(WidgetTester t, String text) => t.widget<Text>(find.text(text)).style!;

void main() {
  setUpAll(loadGoldenFonts);

  test('Change 17/18: the stay map uses the shared segmented control, default 20 km', () {
    final src = File('lib/features/stay/guest/stay_map_screen.dart').readAsStringSync();
    expect(src, contains('ToneSegmentControl('));
    expect(src, contains('tone: ListingTone.forest'));
    final chips = src.substring(src.indexOf('Widget _buildRadiusChips()'), src.indexOf('void _onLocateTap()'));
    expect(chips.contains('TextStyle('), isFalse);
    expect(chips.contains('GestureDetector'), isFalse);
    expect(chips, contains('cellHeight: KitMetrics.touch - 8'));
    expect(AppConstants.defaultRadiusKm, 20.0);
  });

  testWidgets('radius chips: 20 km selected at start, a tap moves the selection, Ink3D 13 w700, same total height as the compact search bar', (t) async {
    await _pump(t);
    expect(_styleOf(t, '20 km').color, DesignColors.onPrimary);
    expect(_styleOf(t, '12 km').color, Ink3D.body);
    expect(_styleOf(t, '12 km').fontWeight, FontWeight.w700);
    expect(_styleOf(t, '12 km').fontFamily, Ink3D.text(13, FontWeight.w700, Ink3D.body).fontFamily);
    expect(_styleOf(t, '12 km').fontSize, Ink3D.text(13, FontWeight.w700, Ink3D.body).fontSize);
    expect(t.getSize(find.byKey(const ValueKey('segment-0'))).height, closeTo(DS.s(KitMetrics.touch - 8), 0.5));
    expect(t.getSize(find.byType(ToneSegmentControl)).height, closeTo(DS.s(KitMetrics.touch), 0.5));
    for (var i = 0; i < _labels.length; i++) {
      await t.tap(find.text(_labels[i]));
      await t.pump();
      expect(_styleOf(t, _labels[i]).color, DesignColors.onPrimary);
      for (var j = 0; j < _labels.length; j++) {
        if (j != i) expect(_styleOf(t, _labels[j]).color, Ink3D.body);
      }
    }
  });

  testWidgets('radius chips: TalkBack reads kilometres and the selected state', (t) async {
    final h = t.ensureSemantics();
    await _pump(t);
    expect(t.getSemantics(find.bySemanticsLabel('20 kilometres')).flagsCollection.isSelected, Tristate.isTrue);
    expect(t.getSemantics(find.bySemanticsLabel('6 kilometres')).flagsCollection.isSelected, Tristate.isFalse);
    h.dispose();
  });

  testWidgets('Change 19: map buttons 56 with glyph 28 through DS; width 320 at text 1.3 has no overflow', (t) async {
    await _pump(t, width: 320, scale: 1.3);
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(const ValueKey('disc-zoom-in'))).width, closeTo(DS.s(TripMapControls.rowSize), 0.01));
    expect(TripMapControls.rowSize, 56);
    final icon = t.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('disc-zoom-in')), matching: find.byType(Icon)));
    expect(icon.size, closeTo(DS.s(28), 0.01));
  });

  testWidgets('golden: stay map top area', (t) async {
    await _pump(t);
    await t.pump(const Duration(milliseconds: 600));
    await expectLater(find.byKey(const ValueKey('top')), matchesGoldenFile('goldens/stay_map_top_area.png'));
  });
}
