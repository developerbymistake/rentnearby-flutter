import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

enum TripTileState { active, pending, disabled }

class TripDayActions extends StatelessWidget {
  final int day;

  const TripDayActions(this.day, {super.key});

  static String _price(int? v) => v == null ? 'On request' : BrowseItem.inr(v);

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      TabConfigController.to.version.value;
      final showTaxi = c.showTaxiOption;
      final showStay = c.showStayOption;
      final d = c.plan.value?.dayAt(day);
      if (d == null || (!showTaxi && !showStay)) return const SizedBox.shrink();
      if (!c.supplyAvailable) {
        final state = c.supplyPending ? TripTileState.pending : TripTileState.disabled;
        final subtitle = state == TripTileState.pending ? TripStrings.checking : TripStrings.notAvailableHere;
        final onTap = state == TripTileState.pending ? () {} : () => AppToast.warning(TripStrings.notAvailableHereSubtitle);
        return Row(
          children: [
            if (showTaxi)
              Expanded(
                child: _ActionTile(
                  icon: Iconsax.car,
                  accent: TaxiColors.accent,
                  surface: TaxiColors.surface,
                  title: 'Taxi',
                  subtitle: subtitle,
                  selected: false,
                  state: state,
                  onTap: onTap,
                ),
              ),
            if (showTaxi && showStay) const SizedBox(width: 8),
            if (showStay)
              Expanded(
                child: _ActionTile(
                  icon: Iconsax.building_4,
                  accent: StayColors.accent,
                  surface: StayColors.surface,
                  title: 'Stay',
                  subtitle: subtitle,
                  selected: false,
                  state: state,
                  onTap: onTap,
                ),
              ),
          ],
        );
      }
      final taxi = d.taxi;
      final stay = d.stay;
      final sameStay = stay != null && stay.isSameStay;
      return Row(
        children: [
          if (showTaxi)
            Expanded(
              child: _ActionTile(
                icon: Iconsax.car,
                accent: TaxiColors.accent,
                surface: TaxiColors.surface,
                title: taxi?.name ?? 'Taxi',
                subtitle: taxi == null
                    ? 'Find a driver'
                    : (taxi.vehicleTypeName == null
                        ? _price(taxi.fare)
                        : '${_price(taxi.fare)} · ${taxi.vehicleTypeName}'),
                selected: taxi != null,
                onTap: () => TripNavigation.openTaxi(day),
                onLongPress: taxi == null
                    ? null
                    : () => _confirmClear(context, 'Remove taxi?', taxi.name, () => c.clearTaxi(day)),
              ),
            ),
          if (showTaxi && showStay) const SizedBox(width: 8),
          if (showStay)
            Expanded(
              child: _ActionTile(
                icon: Iconsax.building_4,
                accent: StayColors.accent,
                surface: StayColors.surface,
                title: stay == null ? 'Stay' : (sameStay ? TripStrings.sameStay : stay.name),
                subtitle: stay == null
                    ? 'Find a stay'
                    : (sameStay ? stay.name : '${_price(stay.pricePerNight)} / night'),
                selected: stay != null,
                onTap: () => TripNavigation.openStay(day),
                onLongPress: stay == null
                    ? null
                    : () => _confirmClear(context, 'Remove stay?', stay.name, () => c.clearStay(day)),
              ),
            ),
        ],
      );
    });
  }

  Future<void> _confirmClear(BuildContext context, String title, String name, VoidCallback onRemove) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(sheetCtx) + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Remove', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok == true) onRemove();
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color surface;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final TripTileState state;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.state = TripTileState.active,
  });

  @override
  Widget build(BuildContext context) {
    final active = state == TripTileState.active;
    final muted = state == TripTileState.pending ? AppColors.textLight : AppColors.textHint;
    final iconColor = active ? accent : muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: active ? onLongPress : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active && selected ? accent.withValues(alpha: 0.6) : AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.textDark : muted),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: active ? AppColors.textLight : muted),
                  ),
                ],
              ),
            ),
            if (active) Icon(Icons.chevron_right_rounded, size: 18, color: selected ? accent : AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
