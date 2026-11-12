import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_spot_picks.dart';
import 'trip_spot_detail_sheet.dart';
import 'trip_spot_row.dart';
import 'trip_ui.dart';

class TripSpotsSectionHead extends StatelessWidget {
  final String title;
  final String? sub;

  const TripSpotsSectionHead({super.key, required this.title, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(width: 8),
              Text(sub!, style: TypeTokens.style(12, FontWeight.w600, color: KitTone.trip.accentDark)),
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
            height: RailCard.height + 24,
            child: RailReveal(
              itemCount: spots.length,
              padding: EdgeInsets.zero,
              separator: 12,
              itemBuilder: (_, i) => _card(context, spots[i]),
            ),
          ),
        ],
      );

  Widget _card(BuildContext context, TripSpotModel s) {
    final on = selected.contains(s.id);
    final locked = lockedOf(s);
    final toggle = toggleOf(s);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: SizedBox(
        width: RailCard.width,
        child: RailCard(
          title: s.title,
          tone: KitTone.trip,
          selected: on,
          tagLabel: TripSpotCategory.label(s.category),
          locationLabel: s.area,
          media: Stack(
            fit: StackFit.expand,
            children: [
              TripSpotMedia(spot: s),
              if (s.isFeatured) const Positioned(left: 8, bottom: 8, child: TripFeaturedChip()),
            ],
          ),
          trailing: TripSpotAddButton(selected: on, locked: locked, onTap: toggle),
          onTap: () => TripSpotDetailSheet.show(context, spot: s, selected: on, locked: locked, onToggle: toggle),
        ),
      ),
    );
  }
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
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bundles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => KitChoiceChip(
                label: '${bundles[i].title} · ${bundles[i].ids.length}',
                selected: true,
                tone: KitTone.trip,
                icon: const TravelIcon(TravelIcon.route, size: 18),
                onTap: () => onTap(bundles[i]),
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
  Widget build(BuildContext context) => TemplateEntranceOnce(
        child: TripSurface(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          shadow: ShadowTokens.elev1,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textStrong),
                ),
              ),
              TextLink(label: TripStringsSpotsX.add, onTap: onAdd, tone: KitTone.trip),
              IconButton(
                onPressed: onDismiss,
                tooltip: TripStringsSpotsX.dismiss,
                constraints: const BoxConstraints(minWidth: KitMetrics.touch, minHeight: KitMetrics.touch),
                icon: const Icon(Icons.close_rounded, size: 18, color: DesignColors.textMuted),
              ),
            ],
          ),
        ),
      );
}

class TripSpotsRouteStrip extends StatelessWidget {
  final TripRouteEstimate route;

  const TripSpotsRouteStrip({super.key, required this.route});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const TravelIcon(TravelIcon.route, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripSpotPicks.routeText(route),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textGrey),
            ),
          ),
        ],
      );
}

class TripOfflineBanner extends StatelessWidget {
  final VoidCallback onTap;

  const TripOfflineBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
        child: TripSurface(
          onTap: onTap,
          shadow: ShadowTokens.elev1,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const TravelIcon(TravelIcon.map, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  TripStringsSpotsX.offline,
                  style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textStrong),
                ),
              ),
            ],
          ),
        ),
      );
}
