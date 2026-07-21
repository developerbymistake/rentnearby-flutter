import 'package:flutter/material.dart';

/// Color zone for one service-catalog rail (band background, card fill, image
/// placeholder fill, accent for icon/"View all"). Shared by the Home rail,
/// the Services tab rails and the View-all grid so a category renders in the
/// same zone everywhere.
class ServiceZone {
  final Color background;
  final Color cardBg;
  final Color imgBg;
  final Color accent;
  const ServiceZone({
    required this.background,
    required this.cardBg,
    required this.imgBg,
    required this.accent,
  });
}

/// Fixed palette, assigned to categories by their position in the sorted
/// active list (index % length) — NEVER by category name. Name-based zone
/// picks (the old `_zoneForSection` in home/local_services) meant every new
/// admin-added category needed an app release to get a color; rotation gives
/// any future category a deliberate zone with zero app code. Order matches
/// the seeded catalog: green (Char Dham Yatra), blue (Tour, Travel &
/// Camping), amber (Yoga & Diet), then pink/purple for whatever the admin
/// adds next.
const kServiceZones = <ServiceZone>[
  ServiceZone( // green
    background: Color(0xFFECFDF5),
    cardBg: Colors.white,
    imgBg: Color(0xFFD1FAE5),
    accent: Color(0xFF059669),
  ),
  ServiceZone( // blue
    background: Color(0xFFEFF6FF),
    cardBg: Colors.white,
    imgBg: Color(0xFFDBEAFE),
    accent: Color(0xFF0284C7),
  ),
  ServiceZone( // amber
    background: Color(0xFFF3E4CE),
    cardBg: Color(0xFFFFFDF8),
    imgBg: Color(0xFFEAD9BE),
    accent: Color(0xFFC2410C),
  ),
  ServiceZone( // pink
    background: Color(0xFFFDF2F8),
    cardBg: Colors.white,
    imgBg: Color(0xFFFBCFE8),
    accent: Color(0xFFBE185D),
  ),
  ServiceZone( // purple
    background: Color(0xFFF5F3FF),
    cardBg: Colors.white,
    imgBg: Color(0xFFDDD6FE),
    accent: Color(0xFF7C3AED),
  ),
];

ServiceZone serviceZoneForIndex(int index) =>
    kServiceZones[index < 0 ? 0 : index % kServiceZones.length];
