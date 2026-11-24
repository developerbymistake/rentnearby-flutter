import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/taxi_calm_card.dart';
import '../../../widgets/listing_contact_actions.dart';
import '../../../models/browse_item.dart';
import '../../nearby/card_strings.dart';
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
        inLabel != null ? [_goCall(context)] : _enquiryRow());
  }

  Widget _card(BuildContext context, TaxiBrowseItem t, String vehicle, List<String> chips, String? fareValue,
      String? fareUnit, NearbyDistance? d, List<CalmAction> actions) {
    final address = d != null ? CardStrings.addressFor(d) : inLabel;
    final hasAddress = address != null && address.trim().isNotEmpty;
    return TaxiCalmCard(
      layout: TaxiCalmLayout.listing,
      tag: null,
      title: t.driverName,
      lines: [vehicle, if (!hasAddress) t.locality].where((e) => e.isNotEmpty).toList(),
      photoUrl: t.displayPhotoUrl,
      art: TaxiVehicleIcon.assetFor(t.vehicleTypeName),
      featured: t.isFeatured,
      chips: chips,
      price: fareValue ?? CardStrings.askForFare,
      unit: fareUnit ?? '',
      address: address,
      actions: actions,
      moreActions: _tripMode ? _pickRow() : const [],
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

  CalmAction _goCall(BuildContext context) => CalmAction(
        kind: CalmActionKind.call,
        label: CardStrings.call,
        itemKey: callKey,
        onTap: () => ListingContactActions.call(context,
            kind: ListingKind.taxi, id: item.id, detailArguments: _detailArguments),
      );

  List<CalmAction> _browseRow(BuildContext context) => [
        CalmAction(
          kind: CalmActionKind.call,
          label: CardStrings.call,
          busy: ListingContactActions.isBusy(ListingKind.taxi, item.id, action: ListingContactActions.actionCall),
          itemKey: callKey,
          onTap: () => ListingContactActions.call(context,
              kind: ListingKind.taxi, id: item.id, detailArguments: _detailArguments),
        ),
        CalmAction(
          kind: CalmActionKind.whatsApp,
          label: CardStrings.whatsApp,
          busy: ListingContactActions.isBusy(ListingKind.taxi, item.id, action: ListingContactActions.actionWhatsApp),
          itemKey: whatsAppKey,
          onTap: () => ListingContactActions.whatsApp(context,
              kind: ListingKind.taxi, id: item.id, detailArguments: _detailArguments),
        ),
      ];

  List<CalmAction> _enquiryRow() {
    final status = enquiryStatus;
    return [
      CalmAction(kind: CalmActionKind.call, label: CardStrings.call, onTap: onOpen),
      if (onEnquire != null)
        CalmAction(
          kind: CalmActionKind.plain,
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
          style: TypeTokens.style(11.5, FontWeight.w700, color: ListingPalette.coral.text),
        ),
      );

  List<CalmAction> _pickRow() => [
        if (onSelect != null)
          CalmAction(
            kind: CalmActionKind.primary,
            selected: selected,
            label: selected ? TripStrings.selected : TripStrings.select,
            onTap: onSelect,
          ),
        if (onBook != null)
          CalmAction(
            kind: CalmActionKind.primary,
            selected: booked,
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
          height: DS.s(h),
          width: w == null ? null : DS.s(w),
          decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v28), borderRadius: DS.circular(8)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(60), DS.s(14), DS.gv(8)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: DS.br(kMealsRadius), gradient: t.gradient, boxShadow: t.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: DS.insets(l: 160, t: 20, r: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(10, 60), Gap.v(8), bar(18, 120), Gap.v(8), bar(12, 90)]),
                ),
                Gap.v(28),
                Padding(padding: DS.sym(h: 20), child: Align(alignment: Alignment.centerLeft, child: bar(26, 110))),
                Gap.v(14),
                Container(height: DS.s(46), color: white.withValues(alpha: Alpha.soft)),
              ],
            ),
          ),
          Positioned(
            left: DS.s(4),
            top: -DS.s(46),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v24)),
              child: SizedBox(width: DS.s(132), height: DS.s(132)),
            ),
          ),
          Positioned(
            left: DS.s(18),
            top: -DS.s(34),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v40)),
              child: SizedBox(width: DS.s(100), height: DS.s(100)),
            ),
          ),
        ],
      ),
    );
  }
}
