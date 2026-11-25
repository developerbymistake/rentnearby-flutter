import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../../owner_core/home/numbers_row.dart';
import '../strings/taxi_hub_strings.dart';
import '../widgets/taxi_widgets.dart';

class TaxiPreviewCard extends StatelessWidget {
  const TaxiPreviewCard({super.key, required this.taxi, this.onView});

  final TaxiOwnerModel taxi;
  final VoidCallback? onView;

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
    final radius = TaxiLook.cardRadius(36);
    final n = taxi.routes.length;
    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(gradient: tone.gradient),
                child: Padding(
                  padding: DS.insets(l: 16, t: 16, r: 16, b: 16),
                  child: Row(
                    children: [
                      ExcludeSemantics(child: _picture()),
                      Gap.h(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                      Gap.h(8),
                      DecoratedBox(
                        decoration: BoxDecoration(color: white, borderRadius: DS.circular(8)),
                        child: Padding(
                          padding: DS.sym(h: 8, v: 3),
                          child: Text(_status, style: Ink3D.text(9.5, FontWeight.w700, TaxiLook.accentText, letterSpacing: 0.6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              OwnerFacts(
                padding: DS.insets(t: 4, b: 4),
                facts: [
                  NumberTile(value: '$n', label: TaxiHubStrings.routeLabel(n)),
                  if (taxi.localDayRate != null) NumberTile(value: Money.exact(taxi.localDayRate ?? 0), label: TaxiHubStrings.localDay),
                  if (taxi.minFare != null) NumberTile(value: Money.exact(taxi.minFare ?? 0), label: TaxiHubStrings.from),
                ],
              ),
              Padding(
                padding: DS.insets(l: 16, t: 4, r: 16, b: 16),
                child: GradientPillButton(tone: ListingTone.coral, label: TaxiHubStrings.view, onTap: onView, enabled: onView != null, height: 48, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
