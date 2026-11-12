import 'trip_ui.dart';
import 'package:bakhli/design/design.dart';
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
import 'trip_shortlist_toggle.dart';
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

  bool get _booked => status == TripDisplayStatus.bookedByYou || status == TripDisplayStatus.confirmedByBoth;

  @override
  Widget build(BuildContext context) {
    final t = item;
    final vehicle = [
      t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
      TaxiOptionSets.plateCheckedLabel,
    ].where((e) => e.isNotEmpty).join(' · ');
    final pickup = fit?.pickupKm;
    final meta = [
      t.plateDisplay,
      t.locality,
      if (pickup != null && pickup.isFinite && pickup >= 0) TripStringsFinalAa.kmAway(pickup),
    ].where((e) => e.isNotEmpty).join(' · ');
    return EntranceOnce(
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        border: _booked ? Border.all(color: KitTone.taxi.accentDark, width: 1.5) : null,
        boxShadow: ShadowTokens.elev2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: CardRadius.tile,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpen,
              splashColor: DesignColors.splash,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [DesignColors.tint(KitTone.taxi.accent, Alpha.soft), DesignColors.tint(KitTone.taxi.accentDark, Alpha.tint)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Image.asset(TravelIcon.taxi),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _info(vehicle, meta)),
                    const SizedBox(width: 8),
                    _price(),
                    SizedBox(
                      width: KitMetrics.touch,
                      height: KitMetrics.touch,
                      child: PopupMenuButton<int>(
                        padding: EdgeInsets.zero,
                        tooltip: TripStringsA3.more,
                        icon: const Icon(Icons.more_vert_rounded, size: 22, color: DesignColors.textMuted),
                        shape: const RoundedRectangleBorder(borderRadius: CardRadius.tile),
                        onSelected: onMenu,
                        itemBuilder: (_) => menuItems,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _actions(context),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _info(String vehicle, String meta) {
    final t = item;
    final reply = TaxiOptionSets.tripReplyLabelText(t.tripReplyLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(t.driverName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong, height: 1.2)),
            if (reply.isNotEmpty) _replyPill(t.tripReplyLabel, reply),
          ],
        ),
        const SizedBox(height: 2),
        Text(vehicle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(12, FontWeight.w600, color: KitTone.taxi.accentDark)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
        ],
        if (noReply && status == null) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: KitTagChip(TripStringsShortlist.noReply, color: TripUi.warn)),
        ],
        if (status != null) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: TripStatusPill(status!, taxi: true)),
        ],
      ],
    );
  }

  Widget _price() {
    final f = fit;
    final rate = f == null ? item.localDayRate : f.costFor(item.localDayRate);
    final cars = f?.carCount ?? 1;
    final extra = f?.extraKm;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(rate == null ? TripStringsA3.rateOnRequest : BrowseItem.inr(rate),
                maxLines: 1,
                style: TypeTokens.style(rate == null ? 12 : 16, FontWeight.w800, color: KitTone.taxi.accentDark)),
          ),
          if (rate != null)
            Text(cars > 1 ? TripStringsAlgoAa.carsPerDay(cars) : TripStringsV2Find.perDayShort,
                maxLines: 2, textAlign: TextAlign.end, style: TypeTokens.caption),
          if (rate != null && days > 1)
            Text(TripStringsV2Find.forDays(BrowseItem.inr(rate * days), days),
                maxLines: 2, textAlign: TextAlign.end, style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.textPrimary)),
          if (extra != null && extra > 0)
            Text(TripStringsAlgoAa.extraKm(extra),
                maxLines: 2, textAlign: TextAlign.end, style: TypeTokens.style(11, FontWeight.w500, color: TripUi.warn)),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final call = SecondaryButton(
      label: TripStringsV2Find.call,
      onPressed: contactBusy ? null : onCall,
      tone: KitTone.taxi,
      height: 44,
      icon: Icon(Icons.call_rounded, size: 16, color: contactBusy ? DesignColors.textDisabled : KitTone.taxi.accentDark),
    );
    final ask = status != null
        ? SecondaryButton(
            label: TripStringsA3.viewStatus,
            onPressed: onAsk,
            tone: KitTone.taxi,
            height: 44,
            icon: Icon(Icons.visibility_outlined, size: 18, color: KitTone.taxi.accentDark),
          )
        : onShortlist != null
            ? TripShortlistToggle(selected: shortlisted, busy: shortlistBusy, onTap: onShortlist, tone: KitTone.taxi)
            : PrimaryButton(
            label: TripStringsV2Find.ask,
            onPressed: onAsk,
            tone: KitTone.taxi,
            height: 44,
            icon: const Icon(Icons.send_rounded, size: 18, color: DesignColors.onPrimary),
          );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.15) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [call, const SizedBox(height: 8), ask]);
    }
    return Row(
      children: [
        Expanded(child: call),
        const SizedBox(width: 8),
        Expanded(child: ask),
      ],
    );
  }

  Widget _replyPill(String label, String text) {
    final c = switch (label) {
      'app' => TripUi.goodDark,
      'phone' => TripUi.warn,
      _ => DesignColors.textPrimary,
    };
    return KitTagChip(text, color: c);
  }
}

class TripDriverRowSkeleton extends StatelessWidget {
  const TripDriverRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TripDriverRow.height,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.tile, boxShadow: ShadowTokens.elev2),
      child: const Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemplatePlaceholder(width: 48, height: 48, radius: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TemplatePlaceholder(width: 140, height: 16, radius: 6),
                      SizedBox(height: 8),
                      TemplatePlaceholder(width: 180, height: 12, radius: 6),
                      SizedBox(height: 8),
                      TemplatePlaceholder(width: 120, height: 11, radius: 6),
                    ],
                  ),
                ),
                TemplatePlaceholder(width: 64, height: 18, radius: 6),
              ],
            ),
          ),
          Row(children: [
            Expanded(child: TemplatePlaceholder(height: 44, radius: 24)),
            SizedBox(width: 12),
            Expanded(child: TemplatePlaceholder(height: 44, radius: 24)),
          ]),
        ],
      ),
    );
  }
}
