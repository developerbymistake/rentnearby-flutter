import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/user_roles.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../models/role_model.dart';

class RoleVisuals {
  const RoleVisuals._();

  static const String _dir = 'assets/images/design/travel3d/';

  static const LinearGradient seekerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [TravelPalette.skyStart, TravelPalette.skyEnd],
  );

  static const LinearGradient stayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
  );

  static const LinearGradient taxiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [TravelPalette.roseStart, TravelPalette.roseEnd],
  );

  static IconData icon(String key) => switch (key) {
        UserRoleKeys.stayOwner => Iconsax.building_4,
        UserRoleKeys.taxiDriver => Iconsax.car,
        _ => Iconsax.search_normal,
      };

  static String iconAsset(String key) => switch (key) {
        UserRoleKeys.stayOwner => '${_dir}house_with_garden.png',
        UserRoleKeys.taxiDriver => '${_dir}taxi.png',
        _ => '${_dir}luggage.png',
      };

  static Color start(String key) => switch (key) {
        UserRoleKeys.stayOwner => TravelPalette.sunriseStart,
        UserRoleKeys.taxiDriver => TravelPalette.roseStart,
        _ => TravelPalette.skyStart,
      };

  static Color end(String key) => switch (key) {
        UserRoleKeys.stayOwner => TravelPalette.sunriseEnd,
        UserRoleKeys.taxiDriver => TravelPalette.roseEnd,
        _ => TravelPalette.skyEnd,
      };

  static LinearGradient gradient(String key) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start(key), end(key)],
      );

  static Color accent(String key) => switch (key) {
        UserRoleKeys.stayOwner => TravelPalette.sunriseStart,
        UserRoleKeys.taxiDriver => TravelPalette.roseEnd,
        _ => TravelPalette.skyEnd,
      };

  static String displayName(String key) => switch (key) {
        UserRoleKeys.stayOwner => 'Stay Owner',
        UserRoleKeys.taxiDriver => 'Taxi Driver',
        _ => 'Seeker',
      };
}

class RoleOptionCard extends StatelessWidget {
  final RoleModel role;
  final bool selected;
  final bool isCurrent;
  final VoidCallback? onTap;

  const RoleOptionCard({
    super.key,
    required this.role,
    this.selected = false,
    this.isCurrent = false,
    this.onTap,
  });

  static KitTone toneOf(String key) => switch (key) {
        UserRoleKeys.stayOwner => KitTone.stayOwner,
        UserRoleKeys.taxiDriver => KitTone.taxiDriver,
        _ => KitTone.seeker,
      };

  static ListingTone listingToneOf(String key) => switch (key) {
        UserRoleKeys.stayOwner => ListingTone.forest,
        UserRoleKeys.taxiDriver => ListingTone.coral,
        _ => ListingTone.indigo,
      };

  @override
  Widget build(BuildContext context) {
    return AuthRoleCard(
      tone: listingToneOf(role.key),
      art: RoleVisuals.iconAsset(role.key),
      title: role.name,
      description: role.description,
      selected: selected,
      badge: isCurrent && !selected ? 'CURRENT' : null,
      dimmed: isCurrent && !selected,
      onTap: onTap,
    );
  }
}

class RoleLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const RoleLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AuthStateCard(
      tone: ListingTone.coral,
      art: ListingArt.compass,
      title: 'Could not load roles.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
