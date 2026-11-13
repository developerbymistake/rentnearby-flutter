import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_algo_aa.dart';
import '../trip_strings_final_aa.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_taxi_fit.dart';
import '../trip_strings_shortlist.dart';
import 'trip_status.dart';

class TripDriverRow extends StatelessWidget {
  const TripDriverRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onCall,
    required this.onAsk,
    required this.onMenu,
    this.status,
    this.days = 1,
    this.contactBusy = false,
    this.menuItems = const [],
    this.fit,
    this.onShortlist,
    this.shortlisted = false,
    this.shortlistBusy = false,
    this.noReply = false,
    this.tone,
  });

  static const double height = 172;

  final TaxiBrowseItem item;
  final TripTaxiFit? fit;
  final TripDisplayStatus? status;
  final int days;
  final bool contactBusy;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onAsk;
  final ValueChanged<int> onMenu;
  final List<PopupMenuEntry<int>> menuItems;
  final VoidCallback? onShortlist;
  final bool shortlisted;
  final bool shortlistBusy;
  final bool noReply;
  final ListingTone? tone;

  bool get _booked => status == TripDisplayStatus.bookedByYou || status == TripDisplayStatus.confirmedByBoth;

  @override
  Widget build(BuildContext context) {
    final t = item;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final vehicle = [
      t.vehicleTypeName.trim(),
      if (t.seats != null) _keep('${TaxiOptionSets.seatsLabel(t.seats!)} seats'),
    ].where((e) => e.isNotEmpty).join(narrow ? '\n' : ' · ');
    final pickup = fit?.pickupKm;
    final near = pickup != null && pickup.isFinite && pickup >= 0 ? pickup : null;
    final place = t.locality;
    final where = place.isEmpty
        ? (near == null ? _nearby : TripStringsFinalAa.kmAway(near))
        : (near == null ? 'In $place' : 'Based near $place. About ${TripStringsFinalAa.kmAway(near)}');
    final reply = TaxiOptionSets.tripReplyLabelText(t.tripReplyLabel);
    final st = status;
    final f = fit;
    final rate = f == null ? item.localDayRate : f.costFor(item.localDayRate);
    final cars = f?.carCount ?? 1;
    final extra = f?.extraKm;
    final forDays = rate != null && days > 1 ? TripStringsV2Find.forDays(BrowseItem.inr(rate * days), days) : null;
    final extraText = extra != null && extra > 0 ? TripStringsAlgoAa.extraKm(extra) : null;
    final menu = SizedBox(
      width: KitMetrics.touch,
      height: KitMetrics.touch,
      child: PopupMenuButton<int>(
        padding: EdgeInsets.zero,
        tooltip: TripStringsA3.more,
        icon: const Icon(Icons.more_vert_rounded, size: 22, color: DesignColors.textInverse),
        shape: const RoundedRectangleBorder(borderRadius: CardRadius.tile),
        onSelected: onMenu,
        itemBuilder: (_) => menuItems,
      ),
    );
    return EntranceOnce(
      child: WideCard(
        tone: tone ?? ListingTone.cA,
        art: ListingArt.forVehicle(t.vehicleTypeName),
        tag: t.isFeatured ? '$_tag · ${KitText.star} Featured' : _tag,
        title: t.driverName,
        subtitle: [vehicle, [t.plateDisplay, place].where((e) => e.isNotEmpty).join(' · ')].where((e) => e.isNotEmpty).join('\n'),
        chips: [
          TaxiOptionSets.plateCheckedLabel,
          if (reply.isNotEmpty) reply,
          if (noReply && st == null) TripStringsShortlist.noReply,
          if (st != null) TripStatusVisuals.label(st),
          ?forDays,
          ?extraText,
        ],
        number: rate == null ? TripStringsA3.rateOnRequest : BrowseItem.inr(rate),
        unit: rate == null ? '' : (cars > 1 ? TripStringsAlgoAa.carsPerDay(cars) : TripStringsV2Find.perDayShort),
        label: where,
        trailing: menu,
        trailingWidth: 30,
        actions: _actions(),
        picked: shortlisted && !_booked,
        ringColor: _booked ? TripLook.booked : null,
        onTap: onOpen,
      ),
    );
  }

  static const String _tag = 'Taxi';
  static String _keep(String s) => s.trim().replaceAll(' ', '\u00A0');
  static const String _nearby = 'Near this city';

  List<WideAction> _actions() {
    final call = WideAction(icon: Icons.call_rounded, label: TripStringsV2Find.call, onTap: onCall, busy: contactBusy);
    final WideAction second;
    if (status != null) {
      second = WideAction(icon: Icons.visibility_outlined, label: TripStringsA3.viewStatus, onTap: onAsk);
    } else if (onShortlist != null) {
      second = WideAction(
        icon: shortlisted ? Icons.check_rounded : Icons.add_rounded,
        label: shortlisted ? TripStringsShortlist.shortlisted : TripStringsShortlist.shortlist,
        onTap: onShortlist,
        selected: shortlisted,
        busy: shortlistBusy,
      );
    } else {
      second = WideAction(icon: Icons.send_rounded, label: TripStringsV2Find.ask, onTap: onAsk);
    }
    return [call, second];
  }
}

class TripDriverRowSkeleton extends StatelessWidget {
  const TripDriverRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const WideCardSkeleton();
}
