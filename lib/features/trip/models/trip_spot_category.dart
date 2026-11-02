import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';

class TripSpotCategory {
  static IconData iconOf(String category) => switch (category) {
        'temple' => Iconsax.building,
        'fort' => Iconsax.courthouse,
        'palace' => Iconsax.crown,
        'museum' => Iconsax.bank,
        'lake' => Iconsax.drop,
        'waterfall' => Iconsax.cloud_drizzle,
        'viewpoint' => Iconsax.eye,
        'park' || 'garden' => Iconsax.tree,
        'zoo' || 'wildlife' => Iconsax.pet,
        'bridge' => Iconsax.routing,
        'ghat' => Iconsax.ship,
        'cave' => Iconsax.moon,
        'historic' => Iconsax.archive_book,
        'beach' => Iconsax.sun_1,
        _ => Iconsax.location,
      };

  static Color colorOf(String category) => switch (category) {
        'lake' || 'waterfall' || 'ghat' || 'beach' => AppColors.accent,
        'viewpoint' || 'park' || 'garden' || 'zoo' || 'wildlife' => AppColors.plot,
        'temple' || 'fort' || 'palace' || 'museum' || 'historic' || 'cave' || 'bridge' => AppColors.gold,
        _ => AppColors.trip,
      };

  static String label(String category) {
    if (category.isEmpty) return 'Place';
    return category[0].toUpperCase() + category.substring(1);
  }
}
