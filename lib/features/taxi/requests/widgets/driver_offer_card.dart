import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../../trip/trip_strings_taxi_driver.dart';
import '../../../trip/widgets/taxi_status/taxi_driver_card.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_requests_strings.dart';

const double _buttonFont = 14;
const double _buttonHeight = 44;

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class DriverOfferCard extends StatelessWidget {
  const DriverOfferCard({
    super.key,
    required this.offer,
    required this.timeLeft,
    required this.expired,
    required this.enabled,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final DriverOffer offer;
  final String? timeLeft;
  final bool expired;
  final bool enabled;
  final VoidCallback? onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _earlier => offer.bucket == OfferBucket.earlier;

  bool get _booked => offer.state == OfferState.confirmed && !DriverRequestsStrings.isEndedBooking(offer);

  bool get _active => offer.state == OfferState.ringing || offer.state == OfferState.accepted || offer.state == OfferState.selected;

  @override
  Widget build(BuildContext context) {
    final muted = _earlier && !_active;
    final ringing = offer.state == OfferState.ringing;
    final bodyColor = muted ? Ink3D.grey : Ink3D.body;
    final line = Ink3D.text(14, FontWeight.w400, bodyColor);
    final chip = _chip(muted);
    final art = Art3D(asset: ListingArt.taxi, size: 48, shadowBlur: 4, shadowOffset: const Offset(2, 3));
    final card = Container(
      key: ValueKey('request_card_${offer.offerId}'),
      padding: DS.insets(l: 16, t: 16, r: 16, b: 16),
      decoration: BoxDecoration(
        color: muted ? DesignColors.chipBackground.withValues(alpha: Alpha.v55) : DesignColors.surface,
        borderRadius: DS.br(CardRadius.hero),
        border: _booked ? Border.all(color: DesignColors.success.withValues(alpha: Alpha.v45), width: DS.s(1.5)) : null,
        boxShadow: muted ? null : DS.shadows(Ink3D.softShadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              muted ? ColorFiltered(colorFilter: _grey, child: Opacity(opacity: Alpha.strong, child: art)) : art,
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverRequestsStrings.travellerName(offer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(16, FontWeight.w700, muted ? Ink3D.grey : Ink3D.title),
                    ),
                    Text(
                      DriverRequestsStrings.subtitleFor(offer),
                      key: ValueKey('request_subtitle_${offer.offerId}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(13, FontWeight.w400, Ink3D.copy),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[Gap.h(8), chip],
            ],
          ),
          if (_active) ...[Gap.v(12), _sections()],
          Gap.v(12),
          Text(DriverRequestsStrings.lengthLine(offer), style: line),
          if (offer.routeLine.isNotEmpty) ...[Gap.v(8), Text(offer.routeLine, style: line)],
          Gap.v(8),
          Text(TripStringsTaxiDriver.seatsLine(offer.seats, offer.travellers), style: line),
          if (ringing) ...[
            Gap.v(14),
            Row(
              children: [
                Expanded(
                  child: WhitePillButton(
                    key: ValueKey('request_decline_${offer.offerId}'),
                    tone: ListingTone.indigo,
                    label: TripStringsTaxiDriver.decline,
                    onTap: enabled && !expired ? onDecline : null,
                    height: _buttonHeight,
                    fontSize: _buttonFont,
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: GradientPillButton(
                    key: ValueKey('request_accept_${offer.offerId}'),
                    tone: ListingTone.indigo,
                    label: TripStringsTaxiDriver.accept,
                    onTap: enabled && !expired ? onAccept : null,
                    height: _buttonHeight,
                    fontSize: _buttonFont,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return Tap3D(tapKey: ValueKey('request_open_${offer.offerId}'), onTap: onOpen, child: card);
  }

  Widget? _chip(bool muted) {
    final fixed = DriverRequestsStrings.chipFor(offer);
    final label = fixed ?? timeLeft;
    if (label == null) return null;
    return TaxiStateChip(label: label, muted: muted, positive: _booked);
  }

  Widget _sections() {
    final s = offer.sections;
    return Wrap(
      spacing: DS.gh(8),
      runSpacing: DS.gv(8),
      children: [
        if (s.pickup) const TaxiStateChip(label: TripStringsTaxiDriver.sectionPickup),
        if (s.sightseeing) TaxiStateChip(label: TripStringsTaxiDriver.sectionSightseeing(offer.sightseeingDayCount)),
        if (s.drop) const TaxiStateChip(label: TripStringsTaxiDriver.sectionDrop),
      ],
    );
  }
}
