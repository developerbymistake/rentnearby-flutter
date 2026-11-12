import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../design/extra/trip_plan_look.dart';
import '../../../models/browse_item.dart';
import '../../../models/card_fact.dart';
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
  });

  bool get _tripMode => onSelect != null;

  @override
  Widget build(BuildContext context) {
    final t = item;
    final vehicleLine = [
      t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ].join(' · ');
    final metaLine = [
      t.locality,
      if (_tripMode) TripStrings.listed(TripFormat.monthYear(t.createdAt)),
    ].where((e) => e.isNotEmpty).join(' · ');
    final facts = <CardFact>[
      if (t.isMatch && t.matchedTripType == 'RoundTrip') const CardFact('Round trip'),
      if (t.isMatch && t.matchReversed) const CardFact('reverse', tone: FactTone.slate),
      if (_tripMode)
        ?_replyFact(t.tripReplyLabel),
    ];
    final (fareValue, fareUnit) = _fare();
    final card = DriverOptionCard(
      name: t.driverName,
      vehicle: vehicleLine,
      subtitle: metaLine.isEmpty ? null : metaLine,
      facts: facts,
      fareValue: fareValue,
      fareUnit: fareUnit,
      isFeatured: t.isFeatured,
      avatarAsset: TaxiVehicleIcon.assetFor(t.vehicleTypeName),
      onTap: onOpen,
      margin: EdgeInsets.zero,
      actions: _actions(),
    );
    final ring = booked
        ? TripLook.booked
        : selected
            ? KitTone.taxi.accent
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
      child: ring == null
          ? card
          : Stack(
              children: [
                card,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: CardRadius.tile,
                        border: Border.all(color: ring, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  CardFact? _replyFact(String label) {
    final text = TaxiOptionSets.tripReplyLabelText(label);
    if (text.isEmpty) return null;
    return CardFact(text, tone: label == 'app' ? FactTone.cyan : FactTone.slate);
  }

  (String?, String?) _fare() {
    final t = item;
    if (t.isMatch) {
      final to = t.matchedToName;
      return (BrowseItem.inr(t.matchedFare!), to != null && to.isNotEmpty ? 'to $to' : null);
    }
    if (t.localDayRate != null) {
      return (
        TaxiOptionSets.localRateLabel(t.localDayRate!),
        t.localDayKm != null ? '${t.localDayKm} km/day' : null,
      );
    }
    return ('Local taxi', null);
  }

  List<Widget> _actions() {
    const tone = KitTone.taxi;
    return [
      PillAction(
        label: 'Call',
        tone: tone,
        icon: const Icon(Icons.call_outlined, size: 16, color: DesignColors.primary),
        onTap: onOpen,
      ),
      PillAction(
        label: 'WhatsApp',
        tone: tone,
        icon: const TravelIcon(TravelIcon.chat, size: 18),
        onTap: onOpen,
      ),
      if (onEnquire != null) _enquire(),
      if (onSelect != null)
        PillAction(
          label: selected ? TripStrings.selected : TripStrings.select,
          tone: tone,
          filled: selected,
          onTap: onSelect,
        ),
      if (onBook != null)
        PillAction(
          label: booked ? TripStrings.booked : TripStrings.iBooked,
          tone: tone,
          filled: booked,
          onTap: onBook,
        ),
    ];
  }

  Widget _enquire() {
    final status = enquiryStatus;
    if (status == null) {
      return PillAction(label: TripStrings.enquiry, tone: KitTone.taxi, onTap: onEnquire);
    }
    return InkWell(
      onTap: onEnquire,
      child: SizedBox(height: 44, child: Center(child: TripStatusPill(status, taxi: true))),
    );
  }
}

class TaxiCardSkeleton extends StatelessWidget {
  const TaxiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => DriverOptionCard.skeleton();
}
