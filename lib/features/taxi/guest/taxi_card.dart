import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../widgets/listing_contact_actions.dart';
import '../../../models/browse_item.dart';
import '../../nearby/models/nearby_models.dart';
import '../../nearby/nearby_strings.dart';
import '../../nearby/widgets/nearby_label_text.dart';
import '../../trip/trip_strings.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_status.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';

class TaxiCard extends StatelessWidget {
  final TaxiBrowseItem item;
  final VoidCallback onOpen;
  final VoidCallback? onSelect;
  final bool selected;
  final VoidCallback? onBook;
  final bool booked;
  final VoidCallback? onEnquire;
  final TripDisplayStatus? enquiryStatus;
  final ListingTone? tone;
  final NearbyDistance? distance;
  final String? inLabel;

  const TaxiCard({
    super.key,
    required this.item,
    required this.onOpen,
    this.onSelect,
    this.selected = false,
    this.onBook,
    this.booked = false,
    this.onEnquire,
    this.enquiryStatus,
    this.tone,
    this.distance,
    this.inLabel,
  });

  bool get _tripMode => onSelect != null;

  static String vehicleLine(TaxiBrowseItem t) => [
        t.vehicleTypeName,
        if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
      ].where((e) => e.isNotEmpty).join(' · ');

  static const _maxVehicleChars = 22;

  static (String, String?) _vehicleParts(TaxiBrowseItem t) {
    final seats = t.seats == null ? null : '${TaxiOptionSets.seatsLabel(t.seats!)} seats';
    final full = vehicleLine(t);
    if (seats != null && full.length > _maxVehicleChars) return (t.vehicleTypeName, seats);
    return (full, null);
  }

  @override
  Widget build(BuildContext context) {
    final t = item;
    final (vehicle, seatsChip) = _vehicleParts(t);
    final (fareValue, fareUnit) = _fare();
    final reply = _tripMode ? TaxiOptionSets.tripReplyLabelText(t.tripReplyLabel) : '';
    final chips = <String>[
      if (!t.isMatch) 'Local taxi',
      if (t.isMatch && t.matchedTripType == 'RoundTrip') 'Round trip',
      ?seatsChip,
      if (reply.isNotEmpty) reply,
      if (t.isMatch && t.matchReversed) 'Reverse',
      if (!t.isMatch && t.localDayRate != null && t.localDayKm != null) '${t.localDayKm} km/day',
      if (_tripMode) TripStrings.listed(TripFormat.monthYear(t.createdAt)),
    ];
    final d = distance;
    if (inLabel == null && !_tripMode) {
      return Obx(() => _card(context, t, vehicle, chips, fareValue, fareUnit, d, _browseRow(context)));
    }
    return _card(context, t, vehicle, chips, fareValue, fareUnit, d,
        inLabel != null ? const [] : _enquiryRow());
  }

  Widget _card(BuildContext context, TaxiBrowseItem t, String vehicle, List<String> chips, String? fareValue,
      String? fareUnit, NearbyDistance? d, List<WideAction> actions) {
    return WideCard(
      tone: tone ?? ListingTone.cA,
      art: TaxiVehicleIcon.assetFor(t.vehicleTypeName),
      tag: t.isFeatured ? 'Taxi · ${KitText.star} Featured' : 'Taxi',
      title: t.driverName,
      subtitle: [vehicle, t.locality].where((e) => e.isNotEmpty).join('\n'),
      chips: chips,
      number: fareValue ?? 'Ask for fare',
      unit: fareUnit ?? '',
      label: d == null ? inLabel : labelFor(d),
      labelNote: d != null && d.isFar ? NearbyStrings.byRoad : null,
      actions: actions,
      onGo: inLabel != null ? onOpen : null,
      actionRows: _tripMode ? [_pickRow()] : null,
      picked: selected || booked,
      onTap: onOpen,
    );
  }

  static String labelFor(NearbyDistance d) =>
      d.isFar ? NearbyStrings.far(d.city, d.state, d.km) : NearbyLabelText.textFor(d, taxi: true);

  static const callKey = ValueKey('taxi-card-call');
  static const whatsAppKey = ValueKey('taxi-card-whatsapp');

  Map<String, dynamic>? get _detailArguments => item.isMatch
      ? {'matchedFare': ?item.matchedFare, 'matchedToName': ?item.matchedToName}
      : null;

  List<WideAction> _browseRow(BuildContext context) => [
        WideAction(
          icon: Icons.call_rounded,
          label: 'Call',
          busy: ListingContactActions.isBusy(ListingKind.taxi, item.id, action: ListingContactActions.actionCall),
          itemKey: callKey,
          onTap: () => ListingContactActions.call(context,
              kind: ListingKind.taxi, id: item.id, detailArguments: _detailArguments),
        ),
        WideAction(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          busy: ListingContactActions.isBusy(ListingKind.taxi, item.id, action: ListingContactActions.actionWhatsApp),
          itemKey: whatsAppKey,
          onTap: () => ListingContactActions.whatsApp(context,
              kind: ListingKind.taxi, id: item.id, detailArguments: _detailArguments),
        ),
      ];

  List<WideAction> _enquiryRow() {
    final status = enquiryStatus;
    return [
      WideAction(icon: Icons.call_rounded, label: 'Call', onTap: onOpen),
      if (onEnquire != null)
        WideAction(
          icon: Icons.mail_rounded,
          label: TripStrings.enquiry,
          onTap: onEnquire,
          child: status == null ? null : _statusText(status),
        ),
    ];
  }

  Widget _statusText(TripDisplayStatus status) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          TripStatusVisuals.label(status, taxi: true),
          maxLines: 1,
          style: Ink3D.text(14, FontWeight.w700, DesignColors.onPrimary),
        ),
      );

  List<WideAction> _pickRow() => [
        if (onSelect != null)
          WideAction(
            icon: selected ? Icons.check_rounded : Icons.add_rounded,
            label: selected ? TripStrings.selected : TripStrings.select,
            onTap: onSelect,
          ),
        if (onBook != null)
          WideAction(
            icon: booked ? Icons.check_rounded : Icons.event_available_rounded,
            label: booked ? TripStrings.booked : TripStrings.iBooked,
            onTap: onBook,
          ),
      ];

  (String?, String?) _fare() {
    final t = item;
    if (t.isMatch) {
      final to = t.matchedToName;
      return (BrowseItem.inr(t.matchedFare!), to != null && to.isNotEmpty ? 'to $to' : null);
    }
    if (t.localDayRate != null) return (BrowseItem.inr(t.localDayRate!), '/day local');
    return (null, null);
  }
}

class TaxiCardSkeleton extends StatelessWidget {
  const TaxiCardSkeleton({super.key, this.tone});

  final ListingTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.cA;
    const white = DesignColors.onPrimary;
    Widget bar(double h, [double? w]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v28), borderRadius: BorderRadius.circular(8)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: kMealsRadius, gradient: t.gradient, boxShadow: t.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(160, 20, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(10, 60), const SizedBox(height: 8), bar(18, 120), const SizedBox(height: 8), bar(12, 90)]),
                ),
                const SizedBox(height: 28),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerLeft, child: bar(26, 110))),
                const SizedBox(height: 14),
                Container(height: 46, color: white.withValues(alpha: Alpha.soft)),
              ],
            ),
          ),
          Positioned(
            left: 4,
            top: -46,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v24)),
              child: const SizedBox(width: 132, height: 132),
            ),
          ),
          Positioned(
            left: 18,
            top: -34,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v40)),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ],
      ),
    );
  }
}
