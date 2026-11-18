import 'package:bakhli/design/design.dart';
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
  const DriverRequestBody({super.key, required this.offer});

  final DriverOffer offer;

  @override
  Widget build(BuildContext context) {
    final trip = offer.trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TripCard(offer: offer),
        if (trip != null) ...[
          Gap.v(16),
          _RouteCard(offer: offer, trip: trip),
          Gap.v(20),
          _DaysHeading(count: trip.days.length),
          for (final d in trip.days) ...[Gap.v(12), DriverDayCard(key: ValueKey('request_day_${d.day}'), day: d)],
        ],
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.offer});

  final DriverOffer offer;

  @override
  Widget build(BuildContext context) {
    final from = _parse(offer.dateFrom);
    final to = _parse(offer.dateTo);
    final rows = <(String, String)>[
      (_S.rowDates, from == null || to == null ? '${offer.dateFrom} to ${offer.dateTo}' : _S.fullRange(from, to)),
      (_S.rowLength, _S.length(offer.dayCount, offer.nightCount)),
      (_S.rowTravellers, _S.travellers(offer.travellers)),
      (_S.rowCar, _S.car(offer.seats)),
      (
        _S.rowIncludes,
        _S.includes(pickup: offer.sections.pickup, sightseeingDays: offer.sightseeingDayCount, drop: offer.sections.drop),
      ),
    ];
    return TaxiStatusCard(
      cardKey: const ValueKey('request_trip_card'),
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
  Widget build(BuildContext context) => Text(text, style: Ink3D.text(16, FontWeight.w700, Ink3D.title));
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: DS.gv(10)),
      padding: EdgeInsets.only(top: DS.gv(10)),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
          Gap.h(12),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: Ink3D.text(13, FontWeight.w700, Ink3D.title)),
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
      children: [
        const _CardTitle(_S.sectionRoute),
        Gap.v(12),
        for (var i = 0; i < stops.length; i++) _RouteStop(title: stops[i].$1, line: stops[i].$2, last: i == stops.length - 1),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.title, required this.line, required this.last});

  final String title;
  final String line;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final dot = DS.s(12);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dot,
            child: Column(
              children: [
                Container(
                  width: dot,
                  height: dot,
                  margin: EdgeInsets.only(top: DS.gv(3)),
                  decoration: const BoxDecoration(color: DesignColors.primary, shape: BoxShape.circle),
                ),
                if (!last) Expanded(child: Container(width: DS.s(2), color: DesignColors.primarySoft)),
              ],
            ),
          ),
          Gap.h(12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: DS.gv(last ? 0 : 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Ink3D.text(14, FontWeight.w700, Ink3D.title)),
                  Text(line, style: Ink3D.text(12, FontWeight.w400, Ink3D.copy)),
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
      padding: EdgeInsets.symmetric(horizontal: DS.s(4)),
      child: Row(
        children: [
          Expanded(child: Text(_S.sectionDays, style: Ink3D.text(14, FontWeight.w700, Ink3D.title))),
          Gap.h(8),
          Text(_S.daysCount(count), style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
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
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: DS.shadows(Ink3D.softShadow), borderRadius: DS.br(CardRadius.hero)),
      child: ClipRRect(
        borderRadius: DS.br(CardRadius.hero),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: DS.insets(l: 14, t: 12, r: 14, b: 12),
              decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Art3D(asset: ListingArt.calendar, size: 40, shadowBlur: 4, shadowOffset: Offset(2, 3)),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Colors.white)),
                        Gap.v(6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: DS.gh(8),
                          runSpacing: DS.gv(6),
                          children: [
                            Text(day.taxi ? _S.km(day.km, day.minutes) : _S.ownPlan, style: Ink3D.text(12, FontWeight.w700, Colors.white)),
                            if (day.city.isNotEmpty) _Chip(label: day.city, filled: false),
                            _Chip(label: day.taxi ? _S.taxiNeeded : _S.noTaxiNeeded, filled: day.taxi),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: DS.insets(l: 14, t: 12, r: 14, b: 12),
              color: DesignColors.surface,
              child: Text(day.places.join(', '), style: Ink3D.text(12, FontWeight.w400, Ink3D.body)),
            ),
          ],
        ),
      ),
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
      padding: DS.sym(h: 10, v: 3),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: Alpha.v22),
        borderRadius: DS.circular(999),
      ),
      child: Text(label, style: Ink3D.text(12, FontWeight.w700, filled ? DesignColors.primary : Colors.white)),
    );
  }
}
