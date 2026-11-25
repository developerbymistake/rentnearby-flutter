import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../../owner_core/home/numbers_row.dart';
import 'driver_state_chip.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_requests_strings.dart';
import '../../../taxi_driver/strings/taxi_work_strings.dart';

const double _buttonFont = 13;
const double _buttonHeight = 48;
const double _artFade = 0.6;

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

  bool get _ended => offer.state == OfferState.missed || offer.state == OfferState.declined;

  bool get _earlier => offer.bucket == OfferBucket.earlier;

  bool get _named => offer.state == OfferState.accepted || offer.state == OfferState.selected || offer.state == OfferState.confirmed;

  bool get _booked => offer.state == OfferState.confirmed && !DriverRequestsStrings.isEndedBooking(offer);

  bool get _active => offer.state == OfferState.ringing || offer.state == OfferState.accepted || offer.state == OfferState.selected;

  @override
  Widget build(BuildContext context) {
    final muted = _earlier && !_active;
    final ringing = offer.state == OfferState.ringing;
    final line = Ink3D.text(13, FontWeight.w400, muted ? TripLook.mutedText : Ink3D.body, height: 1.5, letterSpacing: 0);
    final chip = _chip(muted);
    const art = Art3D(asset: ListingArt.taxi, size: 44, shadowAlpha: 0);
    final card = Container(
      key: ValueKey('request_card_${offer.offerId}'),
      padding: DS.all(16),
      decoration: BoxDecoration(
        color: muted ? TaxiStatusLook.dimCard : DesignColors.surface,
        borderRadius: DS.br(TripCustomizeLook.addDayRadius),
        border: _booked ? Border.all(color: TaxiStatusLook.goodLine, width: DS.s(2)) : null,
        boxShadow: muted ? null : DS.shadows(TripLook.cardShadowSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ringing) ..._ringingHead(chip) else ...[
            Row(
              children: [
                muted ? const ColorFiltered(colorFilter: _grey, child: Opacity(opacity: _artFade, child: art)) : art,
                Gap.h(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _named ? DriverRequestsStrings.travellerName(offer) : TaxiWorkStrings.traveller,
                        style: Ink3D.text(15, FontWeight.w700, muted ? TripLook.mutedText : Ink3D.title, letterSpacing: 0),
                      ),
                      Text(
                        DriverRequestsStrings.subtitleFor(offer),
                        key: ValueKey('request_subtitle_${offer.offerId}'),
                        style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                      ),
                    ],
                  ),
                ),
                if (chip != null) ...[Gap.h(8), chip],
              ],
            ),
            if (muted) ...[
              Gap.v(8),
              Text(_shortLine(), key: ValueKey('request_line_${offer.offerId}'), style: line),
            ] else ...[
              Gap.v(10),
              Text(DriverRequestsStrings.lengthLine(offer), style: line),
              Gap.v(6),
              Text(_routeSeats(), key: ValueKey('request_line_${offer.offerId}'), style: line),
              if (_active) ...[Gap.v(10), _sections()],
            ],
          ],
          if (ringing) ...[
            Gap.v(16),
            Row(
              children: [
                Expanded(
                  child: WhitePillButton(
                    key: ValueKey('request_decline_${offer.offerId}'),
                    tone: ListingTone.coral,
                    label: TaxiWorkStrings.decline,
                    onTap: enabled && !expired ? onDecline : null,
                    height: _buttonHeight,
                    fontSize: _buttonFont,
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: GradientPillButton(
                    key: ValueKey('request_accept_${offer.offerId}'),
                    tone: ListingTone.coral,
                    label: TaxiWorkStrings.accept,
                    onTap: enabled && !expired ? onAccept : null,
                    shadows: TaxiStatusLook.redPill,
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
    return Tap3D(tapKey: ValueKey('request_open_${offer.offerId}'), onTap: _ended ? null : onOpen, child: card);
  }

  String _dates() {
    final r = DriverRequestsStrings.dateRange(offer.fromDay, offer.toDay);
    return r.isEmpty ? NumberTile.missing : r;
  }

  List<Widget> _ringingHead(Widget? chip) => [
        Row(
          children: [
            Expanded(child: Text(DriverRequestsStrings.newRequest, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6))),
            if (chip != null) ...[Gap.h(8), chip],
          ],
        ),
        Gap.v(8),
        Text(
          offer.routeLine,
          key: ValueKey('request_line_${offer.offerId}'),
          style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0),
        ),
        Text(
          DriverRequestsStrings.subtitleFor(offer),
          key: ValueKey('request_subtitle_${offer.offerId}'),
          style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
        ),
        Gap.v(10),
        OwnerFacts(
          labelFirst: true,
          facts: [
            NumberTile(value: _dates(), label: DriverRequestsStrings.datesLabel),
            NumberTile(value: DriverRequestsStrings.daysNights(offer), label: DriverRequestsStrings.lengthLabel),
            NumberTile(value: offer.seats > 0 ? TaxiWorkStrings.seater(offer.seats) : NumberTile.missing, label: DriverRequestsStrings.carLabel),
          ],
        ),
        Gap.v(10),
        _sections(),
      ];

  String _routeSeats() =>
      [if (offer.routeLine.isNotEmpty) offer.routeLine, if (offer.seats > 0) TaxiWorkStrings.seater(offer.seats)].join(' · ');

  String _shortLine() => [if (offer.dayCount > 0) TaxiWorkStrings.daysShort(offer.dayCount), if (offer.routeLine.isNotEmpty) offer.routeLine].join(' · ');

  Widget? _chip(bool muted) {
    final fixed = DriverRequestsStrings.chipFor(offer);
    final label = fixed ?? timeLeft;
    if (label == null) return null;
    return DriverStateChip(label: label, muted: muted, positive: _booked);
  }

  Widget _sections() {
    final s = offer.sections;
    return Wrap(
      spacing: DS.gh(8),
      runSpacing: DS.gv(8),
      children: [
        if (s.pickup) const DriverStateChip(label: TaxiWorkStrings.pickup),
        if (s.sightseeing) DriverStateChip(label: TaxiWorkStrings.sightseeing(offer.sightseeingDayCount)),
        if (s.drop) const DriverStateChip(label: TaxiWorkStrings.drop),
      ],
    );
  }
}
