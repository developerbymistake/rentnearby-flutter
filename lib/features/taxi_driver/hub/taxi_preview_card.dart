import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../strings/taxi_hub_strings.dart';
import '../widgets/taxi_widgets.dart';

class TaxiPreviewCard extends StatelessWidget {
  const TaxiPreviewCard({super.key, required this.taxi, this.onView, this.onShare});

  final TaxiOwnerModel taxi;
  final VoidCallback? onView;
  final VoidCallback? onShare;

  String get _status {
    if (taxi.isPendingReview) return TaxiHubStrings.statusReview;
    if (taxi.isRejected) return TaxiHubStrings.statusRejected;
    if (taxi.isDraft) return TaxiHubStrings.statusDraft;
    if (taxi.isFeatured) return TaxiHubStrings.featured;
    return taxi.isAvailable ? TaxiHubStrings.live : TaxiHubStrings.statusOffline;
  }

  Widget _picture() {
    final url = taxi.displayPhotoUrl;
    if (url == null) return Art3D(asset: ListingArt.taxi, size: 56, halo: 72, haloColor: Colors.white.withValues(alpha: Alpha.v22));
    return SizedBox.square(
      dimension: DS.s(56),
      child: OverflowBox(
        maxWidth: DS.s(72),
        maxHeight: DS.s(72),
        child: PhotoCircle(url: url, art: ListingArt.taxi, size: 72, photoSize: 56, artSize: 56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final tone = taxi.isApproved ? ListingTone.cA : TaxiLook.grey;
    final plate = taxi.plateDisplay ?? taxi.numberPlate ?? TaxiHubStrings.taxiFallback;
    final chips = [
      TaxiHubStrings.routeChip(taxi.routes.length),
      if (taxi.localDayRate != null) TaxiHubStrings.localChip(Money.exact(taxi.localDayRate ?? 0)),
    ];
    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: TaxiLook.cardRadius(54), gradient: tone.gradient, boxShadow: tone.glow()),
        child: Padding(
          padding: DS.insets(l: 16, t: 16, r: 16, b: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: _picture()),
                  Gap.h(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_status, style: Ink3D.text(9.5, FontWeight.w700, white.withValues(alpha: Alpha.v92), letterSpacing: 0.6)),
                        Text(plate, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                        Text(
                          TaxiHubStrings.vehicleLine(taxi.vehicleTypeName ?? TaxiHubStrings.taxiFallback, taxi.seats),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Ink3D.text(12, FontWeight.w600, white.withValues(alpha: Alpha.v92), height: 1.3, letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.v(10),
              Wrap(
                spacing: DS.gh(6),
                runSpacing: DS.gv(4),
                children: [
                  for (final c in chips)
                    DecoratedBox(
                      decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(8)),
                      child: Padding(padding: DS.sym(h: 8, v: 2), child: Text(c, style: Ink3D.text(10, FontWeight.w700, white, letterSpacing: 0))),
                    ),
                ],
              ),
              if (taxi.minFare != null) ...[
                Gap.v(6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(TaxiHubStrings.from, style: Ink3D.text(10, FontWeight.w700, white.withValues(alpha: Alpha.v92), letterSpacing: 0.6)),
                    Gap.h(6),
                    Flexible(child: Text(Money.exact(taxi.minFare ?? 0), maxLines: 1, style: Ink3D.text(24, FontWeight.w600, white, letterSpacing: 0))),
                  ],
                ),
              ],
              Gap.v(8),
              Row(
                children: [
                  Expanded(child: _Btn(label: TaxiHubStrings.view, onTap: onView, locked: onView == null)),
                  if (onShare != null) ...[Gap.h(10), Expanded(child: _Btn(label: TaxiHubStrings.share, onTap: onShare))],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap, this.locked = false});

  final String label;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(48)),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: locked ? Alpha.strong : Alpha.full), borderRadius: DS.circular(22)),
              child: Center(child: Text(label, style: Ink3D.text(13, FontWeight.w700, TaxiLook.accentText, letterSpacing: 0))),
            ),
          ),
        ),
      );
}
