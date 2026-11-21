import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../owner_core/data/single_flight.dart';
import 'seeker_rail_art.dart';
import 'seeker_trip_card.dart';
import 'strings/seeker_home_strings.dart';

class SeekerHomeSkeleton extends StatelessWidget {
  const SeekerHomeSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SeekerHomeStrings.loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SeekerTripCardSkeleton(),
            for (var r = 0; r < rows; r++) ...[
              Padding(
                padding: DS.insets(l: 18, t: 34),
                child: SkeletonBox(width: DS.s(170), height: DS.s(20), radius: DS.radius(10), tone: SkeletonTone.sunrise),
              ),
              Padding(
                padding: DS.insets(l: 18, t: 14, r: 18),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) Gap.h(12),
                      Expanded(child: SkeletonBox(height: DS.s(150), borderRadius: DS.br(tileRadius), tone: SkeletonTone.sunrise)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const BorderRadius tileRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(8),
    bottomLeft: Radius.circular(40),
    bottomRight: Radius.circular(8),
  );
}

class SeekerRailsErrorCard extends StatelessWidget {
  const SeekerRailsErrorCard({super.key, required this.onRetry});

  static const double retryHeight = 44;
  static const double retryFont = 14;

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: Semantics(
        container: true,
        label: '${SeekerHomeStrings.railsErrorTitle}. ${SeekerHomeStrings.railsErrorBody}',
        child: DecoratedBox(
          decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.br(SeekerTripCardView.radius), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Padding(
            padding: DS.insets(l: 22, t: 24, r: 22, b: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.warning, size: 84, shadowBlur: 5, shadowOffset: Offset(4, 6), shadowAlpha: 0.22))),
                Gap.v(6),
                ExcludeSemantics(
                  child: Text(SeekerHomeStrings.railsErrorTitle, textAlign: TextAlign.center, style: Ink3D.text(19, FontWeight.w700, Ink3D.title)),
                ),
                Gap.v(4),
                ExcludeSemantics(
                  child: Text(SeekerHomeStrings.railsErrorBody, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
                ),
                Gap.v(14),
                Center(
                  child: SingleFlightButton(
                    onPressed: onRetry,
                    builder: (context, tap, busy) => GradientPillButton(
                      tone: ListingTone.cB,
                      label: SeekerHomeStrings.retry,
                      onTap: tap,
                      loading: busy,
                      expand: false,
                      height: retryHeight,
                      fontSize: retryFont,
                      semanticsLabel: SeekerHomeStrings.retry,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SeekerRecentRow extends StatelessWidget {
  const SeekerRecentRow({super.key, required this.title, required this.subtitle, required this.onTap, this.photoUrl, this.stayTypeName});

  final String? stayTypeName;
  final String title;
  final String subtitle;
  final String? photoUrl;
  final VoidCallback onTap;

  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(30),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final tint = ListingPalette.forest;
    return Padding(
      padding: DS.insets(l: 18, t: 12, r: 18),
      child: Semantics(
        button: true,
        label: subtitle.isEmpty ? title : '$title, $subtitle',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            padding: DS.insets(l: 10, t: 10, r: 14, b: 10),
            decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.br(radius), boxShadow: DS.shadows(Ink3D.softShadow)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: DS.circular(12),
                  child: SizedBox(
                    width: DS.s(76),
                    height: DS.s(60),
                    child: hasPhoto
                        ? KitPhoto(url: url, width: DS.s(76), height: DS.s(60), asset: TravelIcon.stay, iconSize: 32)
                        : DecoratedBox(
                            decoration: BoxDecoration(color: tint.line),
                            child: Center(child: Art3D(asset: SeekerRailArt.forStay(stayTypeName), size: 40)),
                          ),
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey)),
                    ],
                  ),
                ),
                Gap.h(8),
                Text(SeekerHomeStrings.rowArrow, style: Ink3D.text(24, FontWeight.w500, ListingPalette.indigo.g2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
