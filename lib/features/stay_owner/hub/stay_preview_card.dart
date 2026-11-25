import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/home/numbers_row.dart';
import '../../stay/models/stay_owner_model.dart';
import '../strings/stay_hub_strings.dart';
import '../widgets/stay_widgets.dart';

class StayPreviewCard extends StatelessWidget {
  const StayPreviewCard({super.key, required this.stay, this.onView});

  final StayOwnerModel stay;
  final VoidCallback? onView;

  String get _chip {
    if (stay.isApproved) return stay.acceptingGuests ? StayHubStrings.live : StayHubStrings.paused;
    if (stay.isPendingReview) return StayHubStrings.underReviewChip;
    if (stay.isRejected) return StayHubStrings.rejectedChip;
    return StayHubStrings.draftChip;
  }

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.forest;
    const white = Colors.white;
    final from = stay.minPricePerNight;
    final radius = StayLook.cardRadius(54);
    final place = [if (stay.locality.isNotEmpty) stay.locality, if (stay.isApproved && stay.acceptingGuests) StayHubStrings.accepting].join(' · ');
    Widget chip(String t) => DecoratedBox(
          decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(10)),
          child: Padding(padding: DS.sym(h: 8, v: 2), child: Text(t, style: Ink3D.text(10, FontWeight.w700, white, letterSpacing: 0))),
        );
    final band = Padding(
      padding: DS.insets(l: 14, t: 14, r: 14, b: 14),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: ListingArt.camping, size: 56, halo: 68, haloColor: white.withValues(alpha: Alpha.v22))),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(stay.name ?? '', maxLines: 2, style: Ink3D.text(16, FontWeight.w700, white, height: 1.25, letterSpacing: 0)),
                if (place.isNotEmpty) Text(place, maxLines: 2, style: Ink3D.text(12, FontWeight.w500, white.withValues(alpha: Alpha.v92), letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              chip(_chip),
              if (stay.isFeatured) ...[Gap.v(4), chip(StayHubStrings.featuredChip)],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: tone.gradient), child: band),
              OwnerFacts(
                padding: DS.insets(t: 10, b: 6),
                facts: [
                  NumberTile(value: '${stay.rooms.length}', label: StayHubStrings.roomsFact),
                  NumberTile(value: '${stay.photos.length}', label: StayHubStrings.photos),
                  if (from != null) NumberTile(value: Money.exact(from), label: StayHubStrings.fromNight),
                ],
              ),
              if (onView != null)
                Padding(
                  padding: DS.insets(l: 14, t: 6, r: 14, b: 14),
                  child: GradientPillButton(tone: tone, label: StayHubStrings.view, height: 42, fontSize: 13, onTap: onView),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
