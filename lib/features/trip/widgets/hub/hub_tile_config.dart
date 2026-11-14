import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_routes.dart';
import '../../trip_strings_hub.dart';
import 'hub_art.dart';

enum HubTileStatus { live, soon, off }

enum HubTileSide { textLeft, textRight }

class HubArtItem {
  const HubArtItem(this.asset, this.size, {this.left, this.right, this.top, this.bottom, this.flipX = false});

  final String asset;
  final double size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final bool flipX;
}

class HubTileConfig {
  const HubTileConfig({
    required this.id,
    required this.line,
    required this.title,
    required this.side,
    required this.c1,
    required this.c2,
    required this.text,
    required this.art,
    required this.status,
    this.textWidthFactor = 0.52,
    this.route,
  });

  final String id;
  final String line;
  final String title;
  final HubTileSide side;
  final Color c1;
  final Color c2;
  final Color text;
  final double textWidthFactor;
  final List<HubArtItem> art;
  final HubTileStatus status;
  final String? route;
}

abstract final class HubTiles {
  static const List<HubTileConfig> all = [
    HubTileConfig(
      id: 'where',
      line: TripStringsHub.whereLine,
      title: TripStringsHub.whereTitle,
      side: HubTileSide.textLeft,
      c1: Color(0xFFECEFFE),
      c2: Color(0xFFC6D0FA),
      text: Color(0xFF1B2A8A),
      status: HubTileStatus.live,
      route: AppRoutes.tripWhere,
      art: [
        HubArtItem(HubArt.climber, 152, right: 4),
        HubArtItem(ListingArt.luggage, 58, left: -4, bottom: 6),
      ],
    ),
    HubTileConfig(
      id: 'guide',
      line: TripStringsHub.guideLine,
      title: TripStringsHub.guideTitle,
      side: HubTileSide.textRight,
      c1: Color(0xFFFFF4DD),
      c2: Color(0xFFFFDDA0),
      text: Color(0xFF6B3A00),
      status: HubTileStatus.soon,
      art: [
        HubArtItem(HubArt.manTipping, 150, left: 0),
        HubArtItem(ListingArt.worldMap, 58, left: 88, bottom: 6),
      ],
    ),
    HubTileConfig(
      id: 'rentals',
      line: TripStringsHub.rentalsLine,
      title: TripStringsHub.rentalsTitle,
      side: HubTileSide.textLeft,
      c1: Color(0xFFFFE7EF),
      c2: Color(0xFFFFC4D8),
      text: Color(0xFF8C1747),
      textWidthFactor: 0.34,
      status: HubTileStatus.soon,
      art: [
        HubArtItem(HubArt.dashing, 30, left: -76, bottom: 2),
        HubArtItem(HubArt.womanRaising, 62, left: -22, bottom: 64),
        HubArtItem(HubArt.scooter, 102, left: -48, bottom: 0, flipX: true),
        HubArtItem(HubArt.dashing, 28, left: 22, bottom: 2),
        HubArtItem(HubArt.manRaising, 72, left: 78, bottom: 54),
        HubArtItem(HubArt.motorcycle, 118, left: 50, bottom: 0, flipX: true),
      ],
    ),
    HubTileConfig(
      id: 'adventures',
      line: TripStringsHub.adventuresLine,
      title: TripStringsHub.adventuresTitle,
      side: HubTileSide.textRight,
      c1: Color(0xFFE3F8F5),
      c2: Color(0xFFB8EAE2),
      text: Color(0xFF0B5A52),
      status: HubTileStatus.soon,
      art: [
        HubArtItem(HubArt.rowing, 150, left: -4, bottom: 0),
        HubArtItem(HubArt.parachute, 100, left: 80, top: -4),
      ],
    ),
    HubTileConfig(
      id: 'buddy',
      line: TripStringsHub.buddyLine,
      title: TripStringsHub.buddyTitle,
      side: HubTileSide.textLeft,
      c1: Color(0xFFF1EAFD),
      c2: Color(0xFFD8C9F6),
      text: Color(0xFF4A2A8A),
      status: HubTileStatus.soon,
      art: [
        HubArtItem(HubArt.manRaising, 100, right: 50, bottom: 0),
        HubArtItem(HubArt.womanRaising, 100, right: -2, bottom: 0),
      ],
    ),
  ];

  static List<HubTileConfig> visible() => [
        for (final t in all)
          if (t.status != HubTileStatus.off) t,
      ];
}
