import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_spot_picks.dart';
import 'trip_spot_detail_sheet.dart';
import 'trip_spot_row.dart';

const _poppins = 'Poppins';

class TripSpotsSectionHead extends StatelessWidget {
  final String title;
  final String? sub;

  const TripSpotsSectionHead({super.key, required this.title, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: _poppins, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(width: 8),
              Text(sub!, style: const TextStyle(fontFamily: _poppins, fontSize: 11.5, color: AppColors.textHint)),
            ],
          ],
        ),
      );
}

class TripMustSeeRail extends StatelessWidget {
  final String city;
  final List<TripSpotModel> spots;
  final Set<String> selected;
  final bool Function(TripSpotModel) lockedOf;
  final VoidCallback? Function(TripSpotModel) toggleOf;

  const TripMustSeeRail({
    super.key,
    required this.city,
    required this.spots,
    required this.selected,
    required this.lockedOf,
    required this.toggleOf,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripSpotsSectionHead(title: TripStringsSpotsX.mustSee(city), sub: TripStringsSpotsX.featuredFirst),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: spots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final s = spots[i];
                final on = selected.contains(s.id);
                final locked = lockedOf(s);
                final toggle = toggleOf(s);
                return GestureDetector(
                  onTap: () => TripSpotDetailSheet.show(context, spot: s, selected: on, locked: locked, onToggle: toggle),
                  child: Container(
                    width: 138,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? TripColors.accent : Colors.transparent, width: 1.6),
                      boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.08, blur: 8, offset: const Offset(0, 3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TripSpotMedia(spot: s),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), Color(0xCC000000)],
                                stops: [0.45, 1],
                              ),
                            ),
                          ),
                          if (s.isFeatured)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                                child: const Text(
                                  TripStringsSpotsX.featured,
                                  style: TextStyle(
                                      fontFamily: _poppins, fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 10,
                            right: 50,
                            bottom: 10,
                            child: Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: _poppins, fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: TripSpotAddButton(selected: on, locked: locked, onTap: toggle),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
}

class TripQuickStartRail extends StatelessWidget {
  final List<TripQuickStart> bundles;
  final void Function(TripQuickStart) onTap;

  const TripQuickStartRail({super.key, required this.bundles, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TripSpotsSectionHead(title: TripStringsSpotsX.quickStarts, sub: TripStringsSpotsX.quickSub),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => InkWell(
                onTap: () => onTap(bundles[i]),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TripColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TripColors.accent),
                  ),
                  child: Text(
                    '${bundles[i].title} · ${bundles[i].ids.length}',
                    style: const TextStyle(
                        fontFamily: _poppins, fontSize: 12.5, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      );
}

class TripSuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const TripSuggestionCard({super.key, required this.text, required this.onAdd, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: TripColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TripColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: _poppins, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
            ),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(minimumSize: const Size(44, 40)),
              child: const Text(
                TripStringsSpotsX.add,
                style: TextStyle(fontFamily: _poppins, fontWeight: FontWeight.w700, color: TripColors.accentDark),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: TripStringsSpotsX.dismiss,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
            ),
          ],
        ),
      );
}

class TripSpotsRouteStrip extends StatelessWidget {
  final TripRouteEstimate route;

  const TripSpotsRouteStrip({super.key, required this.route});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.route_rounded, size: 16, color: TripColors.accentDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripSpotPicks.routeText(route),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: _poppins, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
          ),
        ],
      );
}

class TripOfflineBanner extends StatelessWidget {
  final VoidCallback onTap;

  const TripOfflineBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          color: AppColors.warningSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.warningText),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  TripStringsSpotsX.offline,
                  style: TextStyle(fontFamily: _poppins, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warningText),
                ),
              ),
            ],
          ),
        ),
      );
}

class TripSpotsViewSwitch extends StatelessWidget {
  final bool map;
  final ValueChanged<bool> onChanged;

  const TripSpotsViewSwitch({super.key, required this.map, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            _seg(TripStringsSpotsX.list, Icons.view_agenda_outlined, !map, () => onChanged(false)),
            const SizedBox(width: 8),
            _seg(TripStringsSpotsX.map, Icons.map_outlined, map, () => onChanged(true)),
          ],
        ),
      );

  Widget _seg(String label, IconData icon, bool on, VoidCallback tap) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? TripColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? TripColors.accent : AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: on ? Colors.white : AppColors.textHint),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : AppColors.textHint),
              ),
            ],
          ),
        ),
      );
}
