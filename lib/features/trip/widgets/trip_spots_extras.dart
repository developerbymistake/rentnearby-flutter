import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
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
  final int? cityKey;
  final String? version;

  const TripMustSeeRail({
    super.key,
    required this.city,
    required this.spots,
    required this.selected,
    required this.lockedOf,
    required this.toggleOf,
    this.cityKey,
    this.version,
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
    final label = on ? TripStringsSpotsX.addedToTrip : TripStringsSpotsX.addToTrip;
    return Opacity(
      opacity: off ? Alpha.v60 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MealsCardV(
            tone: _tone,
            width: DS.s(168),
            title: s.title,
            description: '${TripSpotCategory.label(s.category)}\n~${TripFormat.visit(s.visitMinutes)}',
            photo: s.hasPhoto ? TripSpotMedia(spot: s, size: SpotPhotoSize.square) : null,
            sticker: s.hasPhoto ? art : null,
            art: s.hasPhoto ? null : art,
            goIcon: on ? Icons.check_rounded : Icons.add_rounded,
            onTap: () => TripSpotDetailSheet.show(context, spot: s, selected: on, locked: locked, onToggle: toggle, cityKey: cityKey, version: version),
          ),
          Positioned(
            left: DS.s(18),
            bottom: DS.s(26),
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: Tap3D(
                onTap: toggle,
                label: label,
                selected: on,
                child: SizedBox(width: DS.s(48), height: DS.s(48)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TripSuggestionCard extends StatelessWidget {
  final TripSpotModel spot;
  final String away;
  final String? semanticsLabel;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const TripSuggestionCard({super.key, required this.spot, required this.away, this.semanticsLabel, required this.onAdd, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final notch = DS.s(14);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(spot.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, Ink3D.title, height: 1.25)),
        SizedBox(height: DS.s(2)),
        Text(away, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.body.withValues(alpha: Alpha.high))),
      ],
    );
    return TemplateEntranceOnce(
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(14), DS.gv(4), DS.s(14), DS.gv(14)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(20), boxShadow: DS.shadows(Ink3D.softShadow)),
              child: Padding(
                padding: DS.insets(l: 12, t: 12, r: 4, b: 12),
                child: Row(
                  children: [
                    _SuggestionThumb(spot: spot),
                    Gap.h(12),
                    Expanded(child: Semantics(container: true, label: semanticsLabel, excludeSemantics: semanticsLabel != null, child: text)),
                    Gap.h(12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: onAdd,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
                        child: Center(widthFactor: 1, child: GradientPillButton(tone: _tone, label: TripStringsSpotsX.add, onTap: onAdd, height: 34, fontSize: 13, expand: false)),
                      ),
                    ),
                    Gap.h(12),
                    IconButton(
                      onPressed: onDismiss,
                      tooltip: TripStringsSpotsX.dismiss,
                      constraints: BoxConstraints(minWidth: DS.s(KitMetrics.touch), minHeight: DS.s(KitMetrics.touch)),
                      icon: Icon(Icons.close_rounded, size: DS.s(20), color: Ink3D.grey),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: DS.s(44),
              top: -DS.s(7),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: notch,
                      height: notch,
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.s(3))),
                        boxShadow: DS.shadows([BoxShadow(color: Ink3D.title.withValues(alpha: Alpha.v04), offset: const Offset(-2, -2), blurRadius: 4)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionThumb extends StatelessWidget {
  final TripSpotModel spot;

  const _SuggestionThumb({required this.spot});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: DS.circular(14),
        child: SizedBox(
          width: DS.s(54),
          height: DS.s(54),
          child: spot.hasPhoto
              ? TripSpotMedia(spot: spot, size: SpotPhotoSize.square)
              : ColoredBox(
                  color: _tone.tint,
                  child: Center(child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
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
          Gap.h(6),
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
        margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(8), DS.s(18), DS.gv(4)),
      );
}
