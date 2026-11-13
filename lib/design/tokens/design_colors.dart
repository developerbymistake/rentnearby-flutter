import 'package:flutter/material.dart';
export 'design_shadows.dart';

class DesignColors {
  DesignColors._();

  // surfaces
  static const Color scaffold = Color(0xFFF2F3F8);
  static const Color scaffoldHotel = Color(0xFFF6F6F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAFAFA);
  static const Color surfaceMuted = Color(0xFFEDF0F2);
  static const Color surfaceTint = Color(0xFFE8EAF8);
  static const Color card = surface;
  static const Color sheet = surface;
  static const Color dialog = surface;
  static const Color navBar = surface;
  static const Color inputFill = surface;
  static const Color dismissBackground = Color(0xFF364A54);

  // text
  static const Color textStrong = Color(0xFF17262A);
  static const Color textPrimary = Color(0xFF253840);
  static const Color textSecondary = Color(0xFF4A6572);
  static const Color textMuted = Color(0xFF767676);
  static const Color textDisabled = Color(0xFFA4B0B8);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textInk = Color(0xFF213333);
  static const Color textGrey = Color(0xFF3A5160);
  static const Color textGreyDark = Color(0xFF313A44);

  // lines
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerSoft = Color(0xFFF2F2F2);
  static const Color border = Color(0x333A5160);
  static const Color borderStrong = Color(0x663A5160);

  // intro chapters
  static const Color introPlum = Color(0xFF7C2D5B);
  static const Color introSky = Color(0xFF0369A1);

  // brand
  static const Color primary = Color(0xFF2633C5);
  static const Color primaryLight = Color(0xFF00B6F0);
  static const Color primarySoft = Color(0x1A2633C5);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accentTeal = Color(0xFF54D3C2);
  static const Color accentTealDeep = Color(0xFF2FB5A4);

  // gradient stops
  static const Color breakfastStart = Color(0xFFFA7D82);
  static const Color breakfastEnd = Color(0xFFFFB295);
  static const Color lunchStart = Color(0xFF738AE6);
  static const Color lunchEnd = Color(0xFF5C5EDD);
  static const Color snackStart = Color(0xFFFE95B6);
  static const Color snackEnd = Color(0xFFFF5287);
  static const Color dinnerStart = Color(0xFF6F72CA);
  static const Color dinnerEnd = Color(0xFF1E1466);
  static const Color gold = Color(0xFFB8862E);
  static const Color amber = Color(0xFFF1B440);
  static const Color hotelStart = Color(0xFF54D3C2);
  static const Color hotelEnd = Color(0xFF2FB5A4);
  static const Color ringLight = Color(0xFF8A98E8);
  static const Color navAccentEnd = Color(0xFF6A88E5);
  static const Color brandStart = primary;
  static const Color brandEnd = primaryLight;

  // status
  static const Color statusTodo = Color(0xFF767676);
  static const Color statusAsked = Color(0xFFFFB295);
  static const Color statusOffer = Color(0xFF738AE6);
  static const Color statusConfirmed = Color(0xFF2633C5);
  static const Color statusBooked = Color(0xFF2FB5A4);
  static const Color statusOwn = Color(0xFF6F72CA);
  static const Color statusSaved = Color(0xFFFF5287);
  static const Color statusSkipped = Color(0xFFA4B0B8);
  static const Color statusAttention = Color(0xFFFA7D82);
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF2FB5A4);
  static const Color warning = Color(0xFFF5A25D);
  static const Color info = Color(0xFF00B6F0);
  static const Color errorSoft = Color(0x1AE5484D);
  static const Color successSoft = Color(0x1A2FB5A4);
  static const Color warningSoft = Color(0x1AF5A25D);
  static const Color infoSoft = Color(0x1A00B6F0);
  static const Color statusTodoSoft = Color(0x1A767676);
  static const Color statusAskedSoft = Color(0x26FFB295);
  static const Color statusOfferSoft = Color(0x1A738AE6);
  static const Color statusConfirmedSoft = Color(0x1A2633C5);
  static const Color statusBookedSoft = Color(0x1A2FB5A4);
  static const Color statusOwnSoft = Color(0x1A6F72CA);
  static const Color statusSavedSoft = Color(0x1AFF5287);
  static const Color statusSkippedSoft = Color(0x1AA4B0B8);
  static const Color statusAttentionSoft = Color(0x1AFA7D82);

  // overlays
  static const Color scrim = Color(0x8A17262A);
  static const Color scrimLight = Color(0x3317262A);
  static const Color overlayDark = Color(0x9917262A);
  static const Color overlayWhite = Color(0xCCFFFFFF);
  static const Color overlayWhiteSoft = Color(0x33FFFFFF);
  static const Color overlayWhiteFaint = Color(0x1AFFFFFF);
  static const Color splash = Color(0x1F2633C5);
  static const Color highlight = Color(0x0F2633C5);
  static const Color shadowBase = Color(0xFF3A5160);

  // chip
  static const Color chipBackground = Color(0xFFEDF0F2);
  static const Color chipSelected = primary;
  static const Color chipSelectedSoft = Color(0x1A2633C5);
  static const Color chipLabel = textPrimary;
  static const Color chipLabelSelected = onPrimary;
  static const Color chipBorder = Color(0x333A5160);

  // input
  static const Color inputBorder = Color(0x333A5160);
  static const Color inputBorderFocus = primary;
  static const Color inputBorderError = error;
  static const Color inputHint = textMuted;
  static const Color inputLabel = textSecondary;
  static const Color inputCursor = primary;

  // controls
  static const Color switchTrackOff = Color(0xFFD5DBE0);
  static const Color switchThumbOff = Color(0xFFFFFFFF);
  static const Color progressTrack = Color(0xFFE3E6F3);
  static const Color skeletonBase = Color(0xFFE6E9EF);
  static const Color skeletonHighlight = Color(0xFFF5F6FA);
  static const Color snackBackground = Color(0xFF17262A);
  static const Color snackText = Color(0xFFFFFFFF);
  static const Color rating = Color(0xFFFFB295);

  // brand extras
  static const Color whatsApp = Color(0xFF25D366);
  static const Color scrimClear = Color(0x00000000);
  static const Color scrimMid = Color(0x22000000);
  static const Color scrimBlack = Color(0xCC000000);
  static const Color primaryFaint = Color(0x142633C5);
  static const Color primaryTint = Color(0x1F2633C5);
  static const Color infoTint = Color(0x1F00B6F0);
  static const Color attentionTint = Color(0x1FFA7D82);
  static const Color savedTint = Color(0x1FFF5287);
  static const Color askedTint = Color(0x1FFFB295);
  static const Color offerTint = Color(0x1F738AE6);
  static const Color offerTintMid = Color(0x26738AE6);
  static const Color askedTintMid = Color(0x33FFB295);
  static const Color snackTintMid = Color(0x26FE95B6);
  static const Color borderSoft = Color(0x1F3A5160);
  static const Color shadowSoft = Color(0x1A3A5160);
  static const Color shadowCool = Color(0x33CBD0DB);
  static const Color bookedSoft = Color(0x1A5C5EDD);

  // alpha statics (Alpha ladder)
  static const Color whiteSoft = Color(0x33FFFFFF);
  static const Color whiteHigh = Color(0xD9FFFFFF);
  static const Color greyTint = Color(0x1F3A5160);
  static const Color textSecondaryHigh = Color(0xD9253840);

  // contrast-safe gradient ends for white text (>= 4.5:1)
  static const Color sunriseDeep = Color(0xFFC94A52);
  static const Color skyDeepStart = Color(0xFF5A6CD0);
  static const Color sunriseDeepEnd = Color(0xFFB03A4A);
  static const Color roseDeepStart = Color(0xFFD8406F);
  static const Color roseDeep = Color(0xFFCF2F62);
  static const Color duskDeepStart = Color(0xFF6467C0);

  // deep status text colours, >= 4.5:1 on their tinted pill surface
  static const Color warnDeep = Color(0xFFA24E16);
  static const Color goodDeep = Color(0xFF006F8F);

  // template pager idle dot
  static const Color idleDot = Color(0xFFE3E4E4);

  static Color tint(Color color, double alpha) => color.withValues(alpha: alpha);
}

class DesignGradients {
  DesignGradients._();

  static const Alignment begin = Alignment.topLeft;
  static const Alignment end = Alignment.bottomRight;

  static const LinearGradient breakfast = LinearGradient(
      colors: [DesignColors.sunriseDeep, DesignColors.sunriseDeepEnd],
      begin: begin,
      end: end);
  static const LinearGradient lunch = LinearGradient(
      colors: [DesignColors.skyDeepStart, DesignColors.lunchEnd],
      begin: begin,
      end: end);
  static const LinearGradient snack = LinearGradient(
      colors: [DesignColors.roseDeepStart, DesignColors.roseDeep],
      begin: begin,
      end: end);
  static const LinearGradient dinner = LinearGradient(
      colors: [DesignColors.duskDeepStart, DesignColors.dinnerEnd],
      begin: begin,
      end: end);
  static const LinearGradient seekerDeep = lunch;
  static const LinearGradient stayOwnerDeep = breakfast;
  static const LinearGradient taxiDriverDeep = snack;
  static const LinearGradient hotel = LinearGradient(
      colors: [DesignColors.hotelStart, DesignColors.hotelEnd],
      begin: begin,
      end: end);
  static const LinearGradient brand = LinearGradient(
      colors: [DesignColors.brandStart, DesignColors.brandEnd],
      begin: begin,
      end: end);
  static const LinearGradient ring = LinearGradient(
      colors: [DesignColors.ringLight, DesignColors.primary],
      begin: begin,
      end: end);
  static const LinearGradient scrimBottom = LinearGradient(
      colors: [Colors.transparent, DesignColors.overlayDark],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter);
  static const LinearGradient scrimTop = LinearGradient(
      colors: [DesignColors.overlayDark, Colors.transparent],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter);
}
