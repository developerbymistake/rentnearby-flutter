import 'package:flutter/material.dart';

import '../../../design/extra/art_3d.dart';
import '../../../design/extra/ext_buddy.dart';
import '../../../design/tokens/alpha_tokens.dart';
import '../../../design/tokens/listing_palette.dart';

abstract final class BuddyLook {
  static const Color roseStart = Color(0xFFF0508A);
  static const Color roseEnd = Color(0xFFB0245A);
  static const Color roseGlow = Color(0xFFFF5287);
  static const Color tealStart = Color(0xFF1FA396);
  static const Color tealEnd = Color(0xFF14756B);
  static const Color dangerStart = Color(0xFFFA7D82);
  static const Color dangerEnd = Color(0xFFE0525C);
  static const Color dangerText = Color(0xFFB83A40);
  static const Color dangerBorder = Color(0xFFF0B7BB);
  static const Color amberText = Color(0xFF8A5200);
  static const Color snackBg = Color(0xFF17262A);
  static const Color snackAction = Color(0xFFFFC371);
  static const Color countBadge = Color(0xFFFF5287);
  static const Color greyText = Color(0xFF767676);
  static const Color subText = Color(0xFF4A6572);
  static const Color hairline = Color(0xFFEEF0F4);
  static const Color chevron = Color(0xFFB8BCC6);
  static const Color checkOff = Color(0xFFC9CDD6);
  static const Color pillOff = Color(0xFFECEDF2);
  static const Color closeBg = Color(0xFFF2F3F8);
  static const Color closeX = Color(0xFFE5484D);
  static const Color indigoText = Color(0xFF2633C5);
  static const Color cardShadow = Color(0xFF3A5160);
  static const Color reasonBg = Color(0xFFFFF1EC);
  static const Color scanDark = Color(0xFF0E1116);
  static const Color scanTeal = Color(0xFF5EE0CF);
  static const Color scanRose = Color(0xFFFF8A8A);
  static const Color scanAmber = Color(0xFFF5C26B);

  static ListingTone get teal => BuddyInk.tone;

  static final ListingTone rose = ListingTone(
    g1: roseStart,
    g2: roseEnd,
    shadow: roseGlow.withValues(alpha: Alpha.v45),
    haloBase: roseStart,
    text: roseEnd,
  );

  static ListingTone get indigo => ListingTone.indigo;

  static ListingTone get green => ListingTone.palette(ListingPalette.forest);

  static final ListingTone danger = ListingTone(
    g1: dangerStart,
    g2: dangerEnd,
    shadow: dangerEnd.withValues(alpha: Alpha.v45),
    haloBase: dangerEnd,
    text: dangerText,
  );

  static const List<List<Color>> avatarGradients = [
    [Color(0xFF738AE6), Color(0xFF5C5EDD)],
    [Color(0xFF1FA396), Color(0xFF14756B)],
    [Color(0xFFF0508A), Color(0xFFB0245A)],
    [Color(0xFFFFC371), Color(0xFFFF8A3D)],
    [Color(0xFF66BB6A), Color(0xFF2E7D32)],
    [Color(0xFF6F72CA), Color(0xFF1E1466)],
  ];

  static int avatarIndex(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % avatarGradients.length;
  }

  static LinearGradient avatarGradient(String seed) {
    final g = avatarGradients[avatarIndex(seed)];
    return LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  static const Map<BuddyBadgeColor, (Color, Color)> badge = {
    BuddyBadgeColor.teal: (Color(0xFFEAF8F6), Color(0xFF14756B)),
    BuddyBadgeColor.grey: (Color(0xFFE3E5EC), Color(0xFF4A4F5C)),
    BuddyBadgeColor.view: (Color(0xFFEEF0FC), Color(0xFF2633C5)),
    BuddyBadgeColor.owner: (Color(0xFFFFF0F5), Color(0xFFB0245A)),
    BuddyBadgeColor.pending: (Color(0xFFFFF4E0), Color(0xFF8A5200)),
    BuddyBadgeColor.ok: (Color(0xFFE8F5E9), Color(0xFF17501B)),
    BuddyBadgeColor.danger: (Color(0xFFFDECEE), Color(0xFFB83A40)),
  };

  static const Map<NoteToneColor, (Color, Color)> note = {
    NoteToneColor.indigo: (Color(0xFFEEF0FC), Color(0xFF2633C5)),
    NoteToneColor.teal: (Color(0xFFEAF8F6), Color(0xFF14756B)),
    NoteToneColor.rose: (Color(0xFFFFF0F5), Color(0xFFB0245A)),
    NoteToneColor.danger: (Color(0xFFFDECEE), Color(0xFFB83A40)),
    NoteToneColor.amber: (Color(0xFFFFF4E0), Color(0xFF8A5200)),
  };

  static List<BoxShadow> cardShadows(double size) => [
        BoxShadow(color: cardShadow.withValues(alpha: Alpha.v22), offset: Offset(1.1 * size, 1.1 * size), blurRadius: 10 * size),
      ];
}

enum BuddyBadgeColor { teal, grey, view, owner, pending, ok, danger }

enum NoteToneColor { indigo, teal, rose, danger, amber }

abstract final class BuddyArt {
  static const String dir = 'assets/images/design/travel3d/';
  static const String panda = '${dir}panda.png';
  static const String luggage = '${dir}luggage.png';
  static const String moneyBag = '${dir}money_bag.png';
  static const String locked = '${dir}locked.png';
  static const String shield = '${dir}shield.png';
  static const String warning = '${dir}warning.png';
  static const String magnifier = '${dir}magnifying_glass_tilted_left.png';
  static const String camera = '${dir}camera.png';
  static const String bell = '${dir}bell.png';
  static const String busts = '${dir}busts_in_silhouette.png';
  static const String bust = '${dir}bust_in_silhouette.png';
  static const String memo = '${dir}memo.png';
  static const String calendar = '${dir}calendar.png';
  static const String clipboard = '${dir}clipboard.png';
  static const String antenna = '${dir}antenna_bars.png';
  static const String worldMap = '${dir}world_map.png';
  static const String key = '${dir}key.png';
  static const String alarm = '${dir}alarm_clock.png';
}
