import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_format.dart';
import '../utils/trip_spot_picks.dart';
import 'trip_spot_detail_sheet.dart';
import 'trip_spot_row.dart';

final _tone = ListingTone.indigo;

class TripSpotsSectionHead extends StatelessWidget {
  final String title;
  final String? sub;

  const TripSpotsSectionHead({super.key, required this.title, this.sub});

  @override
  Widget build(BuildContext context) => TitleRow3D(title: title, subtitle: sub, tone: _tone);
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TripSpotsSectionHead(title: TripStringsSpotsX.mustSee(city), sub: TripStringsSpotsX.featuredFirst),
          MealsRail(children: [for (final s in spots) _card(context, s)]),
        ],
      );

  Widget _card(BuildContext context, TripSpotModel s) {
    final on = selected.contains(s.id);
    final locked = lockedOf(s);
    final toggle = toggleOf(s);
    final art = TripSpotLook.assetOf(s.category);
    final off = locked && !on;
    final label = on ? TripStringsSpotsX.addedWishlist : TripStringsSpotsX.addWishlist;
    return Opacity(
      opacity: off ? Alpha.v60 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MealsCardV(
            tone: _tone,
            width: 168,
            title: s.title,
            description: '${TripSpotCategory.label(s.category)}\n~${TripFormat.visit(s.visitMinutes)}',
            photo: s.hasPhoto ? TripSpotMedia(spot: s) : null,
            sticker: s.hasPhoto ? art : null,
            art: s.hasPhoto ? null : art,
            goIcon: on ? Icons.check_rounded : Icons.add_rounded,
            onTap: () => TripSpotDetailSheet.show(context, spot: s, selected: on, locked: locked, onToggle: toggle),
          ),
          Positioned(
            left: 18,
            bottom: 26,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: Tap3D(
                onTap: toggle,
                label: label,
                selected: on,
                child: const SizedBox(width: 48, height: 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TripQuickStartRail extends StatelessWidget {
  final List<TripQuickStart> bundles;
  final void Function(TripQuickStart) onTap;
  final String Function(String id)? nameOf;

  const TripQuickStartRail({super.key, required this.bundles, required this.onTap, this.nameOf});

  static const List<String> _arts = [ListingArt.beach, ListingArt.star, ListingArt.mountain];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TripSpotsSectionHead(title: TripStringsSpotsX.quickStarts, sub: TripStringsSpotsX.quickSub),
          MealsRail(
            children: [
              for (var i = 0; i < bundles.length; i++)
                MealsCardV(
                  tone: _tone,
                  width: 176,
                  titleLines: 2,
                  art: _arts[i % _arts.length],
                  title: bundles[i].title,
                  description: _names(bundles[i]),
                  number: '${bundles[i].ids.length}',
                  unit: 'places',
                  semanticsLabel: '${bundles[i].title}, ${bundles[i].ids.length} places',
                  onTap: () => onTap(bundles[i]),
                ),
            ],
          ),
        ],
      );

  String _names(TripQuickStart b) {
    final f = nameOf;
    if (f == null) return '';
    return b.ids.map(f).where((e) => e.isNotEmpty).take(2).join('\n');
  }
}

class TripSuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const TripSuggestionCard({super.key, required this.text, required this.onAdd, required this.onDismiss});

  @override
  Widget build(BuildContext context) => TemplateEntranceOnce(
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: Banner3D.radius, boxShadow: Ink3D.softShadow),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: _tone.tint, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Art3D(asset: ListingArt.compass, size: 40, shadowBlur: 3, shadowOffset: Offset(2, 3))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(13, FontWeight.w600, Ink3D.title),
                ),
              ),
              const SizedBox(width: 8),
              GradientPillButton(tone: _tone, label: TripStringsSpotsX.add, onTap: onAdd, height: 34, fontSize: 13, expand: false),
              IconButton(
                onPressed: onDismiss,
                tooltip: TripStringsSpotsX.dismiss,
                constraints: const BoxConstraints(minWidth: KitMetrics.touch, minHeight: KitMetrics.touch),
                icon: Icon(Icons.close_rounded, size: 20, color: Ink3D.grey),
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
          const Art3D(asset: ListingArt.compass, size: 22, shadowBlur: 2, shadowOffset: Offset(1, 2)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripSpotPicks.routeText(route),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(12, FontWeight.w600, Ink3D.grey),
            ),
          ),
        ],
      );
}

class TripOfflineBanner extends StatelessWidget {
  final VoidCallback onTap;

  const TripOfflineBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Banner3D(
        kind: BannerKind.info,
        tone: _tone,
        art: ListingArt.worldMap,
        title: TripStringsSpotsX.offline,
        onTap: onTap,
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      );
}
