import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../design/tokens/owner_tokens.dart';

class OwnerLook {
  const OwnerLook({
    required this.palette,
    required this.tone,
    required this.kit,
    required this.active,
    required this.badge,
    required this.lockFill,
    required this.lockLine,
    required this.lockText,
  });

  final ListingPalette palette;
  final ListingTone tone;
  final KitTone kit;
  final Color active;
  final Color badge;
  final Color lockFill;
  final Color lockLine;
  final Color lockText;

  Color get page => palette.page;
  Color get tint => palette.tint;
  Color get line => palette.line;
  Color get accent => palette.g2;
  Color get text => palette.text;
  LinearGradient get hero => LinearGradient(colors: [palette.g1, palette.g2], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static const Color appDot = OwnerTokens.appDot;
  static const Color ownDot = OwnerTokens.ownDot;
  static const Color blockedDot = OwnerTokens.blockedDot;
  static const Color pastDay = OwnerTokens.pastDay;
  static const Color pastText = OwnerTokens.pastText;
  static const Color hatch = OwnerTokens.hatch;
  static const Color hatchText = OwnerTokens.hatchText;
  static const Color specialBand = OwnerTokens.specialBand;
  static const Color todayRing = OwnerTokens.todayRing;
  static const Color cancelled = Ink3D.hint;
  static const Color amber = OwnerTokens.amber;
  static const Color amberSoft = OwnerTokens.amberSoft;
  static const Color gateBox = OwnerTokens.gateBox;
  static const Color greySoft = OwnerTokens.greySoft;
  static const Color plus = DesignColors.primary;

  static BorderRadius cardRadius([double topRight = 36]) => DS.br(topRight >= 36 ? CardRadius.hero : topRight >= 26 ? CardRadius.tile : CardRadius.card);

  static final OwnerLook stay = OwnerLook(
    palette: ListingPalette.forest,
    tone: ListingTone.forest,
    kit: KitTone.stayOwner,
    active: DesignColors.primary,
    badge: DesignColors.statusSaved,
    lockFill: amberSoft,
    lockLine: OwnerTokens.lockLine,
    lockText: amber,
  );

  static final OwnerLook taxi = OwnerLook(
    palette: ListingPalette.coral,
    tone: ListingTone.coral,
    kit: KitTone.taxiDriver,
    active: ListingPalette.coral.text,
    badge: DesignColors.error,
    lockFill: amberSoft,
    lockLine: OwnerTokens.lockLine,
    lockText: amber,
  );
}
