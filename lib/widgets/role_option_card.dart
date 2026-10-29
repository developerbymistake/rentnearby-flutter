import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';
import '../config/user_roles.dart';
import '../models/role_model.dart';

class RoleVisuals {
  const RoleVisuals._();

  static const LinearGradient seekerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentLight, AppColors.accent],
  );

  static const LinearGradient stayGradient = AppColors.stayGradient;

  static const LinearGradient taxiGradient = AppColors.taxiGradient;

  static IconData icon(String key) => switch (key) {
        UserRoleKeys.rentOwner => Iconsax.home_2,
        UserRoleKeys.propertyOwner => Icons.landscape_rounded,
        UserRoleKeys.stayOwner => Iconsax.building_4,
        UserRoleKeys.taxiDriver => Iconsax.car,
        _ => Iconsax.search_normal,
      };

  static LinearGradient gradient(String key) => switch (key) {
        UserRoleKeys.rentOwner => AppColors.primaryGradient,
        UserRoleKeys.propertyOwner => AppColors.plotGradient,
        UserRoleKeys.stayOwner => stayGradient,
        UserRoleKeys.taxiDriver => taxiGradient,
        _ => seekerGradient,
      };

  static Color accent(String key) => switch (key) {
        UserRoleKeys.rentOwner => AppColors.primary,
        UserRoleKeys.propertyOwner => AppColors.plot,
        UserRoleKeys.stayOwner => AppColors.stay,
        UserRoleKeys.taxiDriver => AppColors.taxi,
        _ => AppColors.accent,
      };

  static String displayName(String key) => switch (key) {
        UserRoleKeys.rentOwner => 'Rent Owner',
        UserRoleKeys.propertyOwner => 'Property Owner',
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

  @override
  Widget build(BuildContext context) {
    final accent = RoleVisuals.accent(role.key);
    final borderColor = selected ? accent : AppColors.divider;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: selected
              ? AppShadows.premium(
                  accent,
                  alpha: 0.14,
                  blur: 20,
                  offset: const Offset(0, 8),
                )
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: RoleVisuals.gradient(role.key),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(RoleVisuals.icon(role.key), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role.name,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text(role.description,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                ),
              )
            else if (isCurrent)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(999)),
                  child: const Text('CURRENT',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RoleLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const RoleLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load roles.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
