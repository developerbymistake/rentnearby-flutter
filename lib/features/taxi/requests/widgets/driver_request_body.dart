import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../../trip/widgets/taxi_status/taxi_status_states.dart';
import '../models/driver_request_models.dart';
import '../strings/driver_request_detail_strings.dart';

typedef _S = DriverRequestDetailStrings;

DateTime? _parse(String raw) => DateTime.tryParse(raw);

String _short(String raw) {
  final d = _parse(raw);
  return d == null ? raw : _S.shortDate(d);
}

String _rangeOf(String from, String to) {
  final a = _parse(from);
  final b = _parse(to);
  return a == null || b == null ? '$from to $to' : _S.range(a, b);
}

class DriverRequestBody extends StatelessWidget {
  const DriverRequestBody({super.key, required this.offer, this.compact = false});

  final DriverOffer offer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trip = compact ? null : offer.trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TripCard(offer: offer, compact: compact),
        if (trip != null) ...[
          Gap.v(20),
          _RouteCard(offer: offer, trip: trip),
          Gap.v(28),
          _DaysHeading(count: trip.days.length),
          for (final d in trip.days) ...[Gap.v(44), DriverDayCard(key: ValueKey('request_day_${d.day}'), day: d)],
        ],
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.offer, required this.compact});

  final DriverOffer offer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final from = _parse(offer.dateFrom);
    final to = _parse(offer.dateTo);
    final rows = <(String, String)>[
      (_S.rowDates, from == null || to == null ? '${offer.dateFrom} to ${offer.dateTo}' : _S.fullRange(from, to)),
      (_S.rowLength, _S.length(offer.dayCount, offer.nightCount)),
      if (!compact) (_S.rowTravellers, _S.travellers(offer.travellers)),
      (_S.rowCar, _S.car(offer.seats)),
      if (!compact)
        (
          _S.rowIncludes,
          _S.includes(pickup: offer.sections.pickup, sightseeingDays: offer.sightseeingDayCount, drop: offer.sections.drop),
        ),
    ];
    return TaxiStatusCard(
      cardKey: const ValueKey('request_trip_card'),
      padding: DS.sym(h: 18, v: 16),
      children: [
        const _CardTitle(_S.sectionTrip),
        for (final r in rows) _TripRow(label: r.$1, value: r.$2),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(8)),
        child: Text(text, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
      );
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(v: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(13, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
          Gap.h(14),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.offer, required this.trip});

  final DriverOffer offer;
  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    final stops = <(String, String)>[
      if (offer.sections.pickup) (_S.pickup, _S.hubDate(trip.pickup.name, _short(trip.pickup.date))),
      for (final c in trip.cities) (c.name, _S.nightsRange(c.nights, _rangeOf(c.from, c.to))),
      if (offer.sections.drop)
        (
          _S.drop,
          trip.drop.sameAsPickup
              ? _S.sameAsPickup(trip.pickup.name, _short(trip.drop.date))
              : _S.hubDate(trip.drop.name, _short(trip.drop.date)),
        ),
    ];
    return TaxiStatusCard(
      cardKey: const ValueKey('request_route_card'),
      padding: DS.sym(h: 18, v: 16),
      children: [
        const _CardTitle(_S.sectionRoute),
        Gap.v(4),
        for (var i = 0; i < stops.length; i++) _RouteStop(title: stops[i].$1, line: stops[i].$2, first: i == 0, last: i == stops.length - 1),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.title, required this.line, required this.first, required this.last});

  final String title;
  final String line;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final dot = DS.s(14);
    final pad = DS.gv(8);
    final dotTop = pad + DS.s(4);
    final rail = Container(width: DS.s(2), color: TripLook.rail);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dot,
            child: Column(
              children: [
                SizedBox(height: dotTop, child: first ? null : rail),
                Container(width: dot, height: dot, decoration: const BoxDecoration(color: DesignColors.lunchEnd, shape: BoxShape.circle)),
                Expanded(child: last ? const SizedBox.shrink() : rail),
              ],
            ),
          ),
          Gap.h(14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(line, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysHeading extends StatelessWidget {
  const _DaysHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DS.sym(h: 4),
      child: Row(
        children: [
          Expanded(child: Text(_S.sectionDays, style: Ink3D.text(13, FontWeight.w700, Ink3D.body, letterSpacing: 0))),
          Gap.h(8),
          Text(_S.daysCount(count), style: Ink3D.text(13, FontWeight.w500, TripLook.mutedText, letterSpacing: 0)),
        ],
      ),
    );
  }
}

class DriverDayCard extends StatelessWidget {
  const DriverDayCard({super.key, required this.day});

  final DriverTripDay day;

  @override
  Widget build(BuildContext context) {
    final date = _parse(day.date);
    final title = _S.dayTitle(day.day, date == null ? day.date : _S.weekdayDate(date));
    final box = DecoratedBox(
      decoration: BoxDecoration(boxShadow: DS.shadows(TripLook.dayCardShadow), borderRadius: DS.br(CardRadius.hero)),
      child: ClipRRect(
        borderRadius: DS.br(CardRadius.hero),
        child: Container(
          color: DesignColors.surface,
          padding: DS.insets(b: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: DS.insets(l: 88, t: 14, r: 14, b: 14),
                decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: DS.s(40)),
                      child: Row(
                        children: [
                          Container(
                            width: DS.s(14),
                            height: DS.s(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: day.taxi ? TaxiStatusLook.dayDotOn : TaxiStatusLook.dayDotOff,
                              border: Border.all(color: Colors.white, width: DS.s(2.5)),
                            ),
                          ),
                          Gap.h(8),
                          Expanded(
                            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.3, letterSpacing: 0)),
                          ),
                        ],
                      ),
                    ),
                    Gap.v(2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: DS.gh(10),
                      runSpacing: DS.gv(8),
                      children: [
                        Text(day.taxi ? _S.km(day.km, day.minutes) : _S.ownPlan, style: Ink3D.text(13, FontWeight.w600, Colors.white, letterSpacing: 0)),
                        if (day.city.isNotEmpty) _Chip(label: day.city, filled: false),
                        _Chip(label: day.taxi ? _S.taxiNeeded : _S.noTaxiNeeded, filled: day.taxi),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: DS.insets(l: 16, t: 14, r: 16, b: 16),
                child: Text(
                  day.places.join(', '),
                  style: Ink3D.text(13, FontWeight.w400, day.taxi ? Ink3D.title : TripLook.mutedText, height: 1.6, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        Positioned(
          left: DS.s(12),
          top: DS.s(-12),
          child: Container(
            width: DS.s(62),
            height: DS.s(62),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v22)),
          ),
        ),
        Positioned(
          left: DS.s(10),
          top: DS.s(-13),
          child: const Art3D(asset: ListingArt.calendar, size: 63, shadowBlur: 5, shadowOffset: Offset(4, 6)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DS.s(28),
      padding: DS.sym(h: 10),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: Alpha.v26),
        borderRadius: DS.circular(10),
      ),
      child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, filled ? DesignColors.primary : Colors.white, letterSpacing: 0))),
    );
  }
}
