import 'dart:io';

import 'package:bakhli/design/extra/kit_tone.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/tokens/design_colors.dart';
import 'package:bakhli/design/tokens/listing_palette.dart';
import 'package:bakhli/design/tokens/template_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/features/buddy/viewer/viewer_look.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile_config.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tokens.dart';

const _tokens = 'lib/design/tokens/';

// Old indigo brand family (gradient 738AE6 -> 5C5EDD, text 2633C5 and its tints).
final _oldIndigo = RegExp(r'738AE6|5C5EDD|2633C5|EEF0FC|D5D9F5|DADDF7', caseSensitive: false);
// Neutral page colour: kept, but only the token files may spell it.
final _page = RegExp(r'F2F3F8', caseSensitive: false);
final _brandStandIn = RegExp(r'Colors\.(indigo|indigoAccent|blue|blueAccent|lightBlue)\b');

Iterable<File> _dart() =>
    Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

String _path(File f) => f.path.replaceAll(Platform.pathSeparator, '/');

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('the old indigo hex family is gone from lib', () {
    final hits = <String>[];
    for (final f in _dart()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_oldIndigo.hasMatch(lines[i])) hits.add('${_path(f)}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('the page colour hex lives only in the token files', () {
    final hits = <String>[];
    for (final f in _dart()) {
      final path = _path(f);
      if (path.startsWith(_tokens)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_page.hasMatch(lines[i])) hits.add('$path:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no Material indigo or blue stands in for the brand colour', () {
    final hits = <String>[];
    for (final f in _dart()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_brandStandIn.hasMatch(lines[i])) hits.add('${_path(f)}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('brand gradient runs navy to royal blue, top left to bottom right', () {
    const p = ListingPalette.indigo;
    expect(p.g1.toARGB32(), 0xFF1E3A8A);
    expect(p.g2.toARGB32(), 0xFF2F6FE0);
    expect(p.text, DesignColors.brandNavy);
    expect(p.tint.toARGB32(), 0xFFEFF6FF);
    expect(p.page, DesignColors.scaffold);
    expect(p.gradient.colors, [DesignColors.brandNavy, DesignColors.brandRoyal]);
    expect(p.gradient.begin, Alignment.topLeft);
    expect(p.gradient.end, Alignment.bottomRight);
    expect(DesignGradients.lunch.colors, [DesignColors.brandNavy, DesignColors.brandRoyal]);
    expect(DesignGradients.brand.colors, [DesignColors.brandNavy, DesignColors.brandRoyal]);
    expect(KitTone.brand.gradient.colors, [DesignColors.brandNavy, DesignColors.brandRoyal]);
  });

  test('primary family tokens all point at the new blue', () {
    expect(DesignColors.primary, DesignColors.brandNavy);
    expect(DesignColors.chipSelected, DesignColors.brandNavy);
    expect(DesignColors.inputBorderFocus, DesignColors.brandNavy);
    expect(DesignColors.inputCursor, DesignColors.brandNavy);
    expect(DesignColors.lunchStart, DesignColors.brandNavy);
    expect(DesignColors.lunchEnd, DesignColors.brandRoyal);
    expect(TemplateTokens.nearlyDarkBlue, DesignColors.brandNavy);
    expect(KitTone.stay.accentDark, DesignColors.brandNavy);
  });

  test('white text stays readable on the light end of the gradient', () {
    expect(_contrast(Colors.white, DesignColors.brandRoyal), greaterThanOrEqualTo(4.5));
    expect(_contrast(Colors.white, ListingPalette.indigo.g2), greaterThanOrEqualTo(4.5));
    expect(_contrast(Colors.white, DesignColors.brandNavy), greaterThanOrEqualTo(4.5));
  });

  test('navy text stays readable on the pale blue surfaces', () {
    expect(_contrast(DesignColors.brandNavy, DesignColors.brandTint), greaterThanOrEqualTo(4.5));
    expect(_contrast(DesignColors.brandNavy, DesignColors.scaffold), greaterThanOrEqualTo(4.5));
    expect(_contrast(DesignColors.brandRoyal, Colors.white), greaterThanOrEqualTo(4.5));
  });

  test('trips hub and plan rails use the blue family, no lavender left', () {
    expect(HubTokens.heading, DesignColors.brandNavy);
    expect(HubTokens.headingSub, DesignColors.brandNavy);
    expect(HubTokens.dotOff, DesignColors.brandRing);
    expect(HubTokens.statusStrip, DesignColors.brandTint);
    expect(HubTokens.pageGradient.colors, [
      DesignColors.brandTint,
      DesignColors.brandTint,
      DesignColors.brandButton,
      DesignColors.brandLine,
      DesignColors.brandButton,
      DesignColors.brandTint,
      DesignColors.scaffold,
    ]);
    final where = HubTiles.all.firstWhere((t) => t.id == 'where');
    expect([where.c1, where.c2, where.text], [DesignColors.brandTint, DesignColors.brandLine, DesignColors.brandNavy]);
    expect(TripLook.rail, DesignColors.brandRing);
    expect(ViewerLook.rail, DesignColors.brandRing);
    for (final c in [...HubTokens.pageGradient.colors, DesignColors.brandLine]) {
      expect(_contrast(HubTokens.heading, c), greaterThanOrEqualTo(4.5));
    }
  });
}
