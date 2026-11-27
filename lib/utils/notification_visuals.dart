import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../design/design.dart';
import '../config/app_routes.dart';
import '../features/social/shared/travel_levels.dart';

enum NotificationKind { approved, rejected, takedown, other }

/// Backend-string -> Color/IconData mapper for NotificationModel; add a case per new type.
abstract final class NotificationVisuals {
  static NotificationKind kind(String type, String title) {
    final t = type.toLowerCase();
    if (t.contains('approved')) return NotificationKind.approved;
    if (t.contains('rejected')) {
      return title.toLowerCase().contains('taken down') ? NotificationKind.takedown : NotificationKind.rejected;
    }
    return NotificationKind.other;
  }

  static Color color(String type, String title) => switch (kind(type, title)) {
        NotificationKind.approved => UtilTokens.notifApproved,
        NotificationKind.rejected => UtilTokens.notifRejected,
        NotificationKind.takedown => UtilTokens.notifTakedown,
        NotificationKind.other => UtilTokens.notifOther,
      };

  static IconData icon(String type, String title) => switch (kind(type, title)) {
        NotificationKind.approved => Icons.check_circle_rounded,
        NotificationKind.rejected => Icons.cancel_rounded,
        NotificationKind.takedown => Icons.flag_rounded,
        NotificationKind.other => Iconsax.info_circle,
      };

  /// Kind label of the inbox row: from the type when it has its own label, else from the route it opens.
  static String? listingKind(String? actionRoute, {String? type}) {
    final byType = _typeLabels[(type ?? '').replaceAll('_', '').toLowerCase()];
    if (byType != null) return byType;
    return switch (actionRoute) {
      AppRoutes.myStays => 'STAY',
      AppRoutes.myTaxi => 'TAXI',
      AppRoutes.stayEnquiries => 'ENQUIRY',
      AppRoutes.staySpecialPrices => 'PRICE',
      AppRoutes.stayPlanVisible => 'PLAN',
      AppRoutes.stayCalendar => 'REMINDER',
      AppRoutes.plansBilling => 'PLAN',
      _ => null,
    };
  }

  static const Map<String, String> _typeLabels = {
    'tripchangerequest': 'CHANGE REQUEST',
    'triptravellercancelled': 'BOOKING',
    'tripproblemreported': 'BOOKING',
    'rolerequestapproved': 'ROLE',
    'rolerequestrejected': 'ROLE',
    travelLevelUp: 'LEVEL',
  };

  static const String travelLevelUp = 'travellevelup';

  /// Level-up congratulation row: the trophy of the level named in the server copy (title + body).
  static ({String art, ListingTone tone})? levelLook(String? type, String? actionRoute, String text) {
    if ((type ?? '').replaceAll('_', '').toLowerCase() != travelLevelUp && actionRoute != AppRoutes.travelLevels) return null;
    for (final l in TravelLevels.all.reversed) {
      if (text.contains(l.name)) return (art: l.asset, tone: ListingTone.indigo);
    }
    return (art: TravelLevels.at(1).asset, tone: ListingTone.indigo);
  }

  /// Art and tone of a stay owner inbox row (o_st_22); null keeps the generic look.
  static ({String art, ListingTone tone})? ownerLook(String? type, String? actionRoute) {
    final t = (type ?? '').replaceAll('_', '').toLowerCase();
    if (actionRoute == AppRoutes.stayEnquiries) {
      final art = switch (t) {
        'tripchangerequest' => ListingArt.calendar,
        'tripofferaccepted' => ListingArt.key,
        'tripproblemreported' => ListingArt.warning,
        'triptravellercancelled' || 'triptravellerleft' || 'tripenquiryclosedbyadmin' => ListingArt.clipboard,
        _ => ListingArt.speechBalloon,
      };
      return (art: art, tone: ListingTone.teal);
    }
    return switch (actionRoute) {
      AppRoutes.myStays => (art: ListingArt.camping, tone: ListingTone.cB),
      AppRoutes.staySpecialPrices => (art: ListingArt.diyaLamp, tone: ListingTone.cB),
      AppRoutes.stayCalendar => (art: ListingArt.alarmClock, tone: ListingTone.cB),
      AppRoutes.stayPlanVisible || AppRoutes.plansBilling => (art: ListingArt.crown, tone: ListingTone.cB),
      _ => null,
    };
  }
}
