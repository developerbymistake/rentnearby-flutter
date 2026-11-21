import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../stay/models/stay_owner_model.dart';
import '../strings/stay_hub_strings.dart';
import '../widgets/stay_widgets.dart';

class StayPreviewCard extends StatelessWidget {
  const StayPreviewCard({super.key, required this.stay, this.onView, this.onShare});

  final StayOwnerModel stay;
  final VoidCallback? onView;
  final VoidCallback? onShare;

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
    final type = (stay.stayTypeName ?? StayHubStrings.stayFallback).toUpperCase();
    Widget chip(String t) => DecoratedBox(
          decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(10)),
          child: Padding(padding: DS.sym(h: 8, v: 2), child: Text(t, style: Ink3D.text(10, FontWeight.w700, white, letterSpacing: 0))),
        );
    return Padding(
      padding: DS.insets(l: 18, t: 36, r: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(borderRadius: StayLook.cardRadius(54), gradient: tone.gradient, boxShadow: tone.glow()),
            child: ClipRRect(
              borderRadius: StayLook.cardRadius(54),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: DS.insets(l: 14, t: 18, r: 14, b: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: DS.s(86)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(type, style: Ink3D.text(10, FontWeight.w700, white.withValues(alpha: Alpha.high), letterSpacing: 0.6)),
                              Text(stay.name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, white, height: 1.25, letterSpacing: 0)),
                              if (stay.locality.isNotEmpty)
                                Text(stay.locality, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, white.withValues(alpha: Alpha.v92), letterSpacing: 0)),
                            ],
                          ),
                        ),
                        Gap.v(10),
                        Wrap(
                          spacing: DS.gh(8),
                          runSpacing: DS.gv(4),
                          children: [
                            chip(_chip),
                            if (stay.isFeatured) chip(StayHubStrings.featuredChip),
                            if (stay.isApproved && stay.acceptingGuests) chip(StayHubStrings.accepting),
                          ],
                        ),
                        if (from != null) ...[
                          Gap.v(10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(StayHubStrings.from, style: Ink3D.text(10, FontWeight.w700, white.withValues(alpha: Alpha.high), letterSpacing: 0)),
                              Gap.h(6),
                              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(Money.exact(from), style: Ink3D.text(22, FontWeight.w700, white, letterSpacing: 0)))),
                              Gap.h(4),
                              Text(StayHubStrings.perNightUnit, style: Ink3D.text(12, FontWeight.w500, white.withValues(alpha: Alpha.v92), letterSpacing: 0)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onView != null || onShare != null)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: Alpha.soft),
                      child: Row(
                        children: [
                          if (onView != null) Expanded(child: _Action(label: StayHubStrings.view, onTap: onView)),
                          if (onView != null && onShare != null) SizedBox(width: DS.s(1), height: DS.s(36), child: ColoredBox(color: white.withValues(alpha: Alpha.soft))),
                          if (onShare != null) Expanded(child: _Action(label: StayHubStrings.share, onTap: onShare)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(left: DS.s(8), top: -DS.s(30), child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: ListingArt.camping, size: 84, halo: 96, haloColor: white.withValues(alpha: Alpha.v22))))),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: DS.s(48),
            child: Center(child: Text(label, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0))),
          ),
        ),
      );
}
