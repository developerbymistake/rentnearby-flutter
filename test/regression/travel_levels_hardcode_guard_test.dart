import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _levelFiles = [
  'lib/features/social/shared/travel_levels.dart',
  'lib/features/social/shared/widgets/travel_level_widgets.dart',
  'lib/features/social/shared/widgets/level_up_host.dart',
  'lib/features/social/a/profile/travel_levels_screen.dart',
];

final _rules = <String, RegExp>{
  'raw colour': RegExp(r'Color\(0x'),
  // \b keeps token classes such as LevelColors / DesignColors out; only the Material Colors class is banned.
  'Material colour': RegExp(r'\bColors\.(?!transparent\b)[a-z]'),
  'inline alpha': RegExp(r'withValues\(alpha:\s*[0-9.]|withOpacity\('),
  'raw size/radius/blur': RegExp(r'DS\.(s|circular|radius|shadowBlur)\(\s*[0-9]'),
  'raw art size': RegExp(r'Art3D\([^)]*\bsize:\s*[0-9]'),
  'raw art shadow': RegExp(r'shadowBlur:\s*[0-9]|Offset\(\s*-?[0-9]'),
  'raw alignment': RegExp(r'Alignment\(\s*-?[0-9]'),
  'inline copy': RegExp(r"Text\(\s*'[^'$]*[A-Za-z]"),
};

void main() {
  test('travel level widgets use tokens, DS scale and strings files only', () {
    final hits = <String>[];
    for (final path in _levelFiles) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        _rules.forEach((name, re) {
          if (re.hasMatch(line)) hits.add('$path:${i + 1} $name');
        });
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('the Material colour rule flags Colors.x only, never token classes', () {
    final rule = _rules['Material colour']!;
    expect(rule.hasMatch('color: Colors.red,'), isTrue);
    expect(rule.hasMatch('color: Colors.white70,'), isTrue);
    expect(rule.hasMatch('(Colors.black)'), isTrue);
    expect(rule.hasMatch('color: Colors.transparent,'), isFalse);
    expect(rule.hasMatch('tint: LevelColors.tint0, ink: LevelColors.ink0'), isFalse);
    expect(rule.hasMatch('color: DesignColors.surface'), isFalse);
    expect(rule.hasMatch('ProfileStatColors.tileShadow'), isFalse);
  });

  test('level sizes keep the built values', () {
    expect(LevelSizes.tile, 50);
    expect(LevelSizes.badge, 24);
    expect(LevelSizes.medal, 62);
    expect(LevelSizes.medalArt, 46);
    expect(LevelSizes.markArt, 48);
    expect(LevelSizes.hero, 104);
    expect(LevelSizes.heroArt, 74);
    expect(LevelSizes.nextArt, 22);
    expect(LevelSizes.bar, 10);
    expect(LevelSizes.sheetBar, 8);
    expect(LevelSizes.rowMinHeight, 76);
    expect(LevelSizes.roundArtRatio, 0.78);
    expect(LevelSizes.tileArtRatio, 1.08);
    expect(LevelSizes.tileArtLift, 0.14);
    expect(LevelSizes.artShadowBlur, 3);
    expect(LevelSizes.artShadowOffset, const Offset(2, 4));
    expect(LevelSizes.medalLightCentre, const Alignment(0, -0.3));
    expect(LevelSizes.panelShadowOffset, const Offset(0, 4));
    expect(LevelSizes.statShadowOffset, const Offset(0, 3));
  });

  test('composed level labels read the same as before', () {
    expect(SocialStrings.openLevelsLabel('Pathfinder', 124), 'Open travel levels. Pathfinder, 124 trips');
    expect(SocialStrings.levelRowLabel('Trekker', 'Level 3 · 30 to 79 trips'), 'Trekker, Level 3 · 30 to 79 trips');
    expect(SocialStrings.levelRowLabel('Trekker', 'Level 3 · 30 to 79 trips', current: true), 'Trekker, Level 3 · 30 to 79 trips, You are here');
    expect(SocialStrings.toNext('Wanderer'), ' to Wanderer');
    expect(SocialStrings.toNext(null), ' to');
  });

  test('hub brand stand-ins point at the primary navy', () {
    final config = File('lib/features/trip/widgets/hub/hub_tile_config.dart').readAsStringSync();
    expect(config.contains('1B2A8A'), isFalse);
    final tile = File('lib/features/trip/widgets/hub/hub_tile.dart').readAsStringSync();
    expect(RegExp(r'611E286E|61374196').hasMatch(tile), isFalse);
    expect(HubTokens.deviceShadowFar, const Color(0x611E286E));
    expect(HubTokens.deviceShadowNear, const Color(0x61374196));
    expect(HubTokens.heading, DesignColors.brandNavy);
  });
}
