import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_algo_aa.dart';
import '../trip_strings_final_aa.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_taxi_fit.dart';
import 'trip_status.dart';

class TripDriverRow extends StatelessWidget {
  const TripDriverRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onCall,
    required this.onWhatsApp,
    required this.onAsk,
    required this.onMenu,
    this.status,
    this.days = 1,
    this.contactBusy = false,
    this.menuItems = const [],
    this.fit,
  });

  static const double height = 172;

  final TaxiBrowseItem item;
  final TripTaxiFit? fit;
  final TripDisplayStatus? status;
  final int days;
  final bool contactBusy;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onAsk;
  final ValueChanged<int> onMenu;
  final List<PopupMenuEntry<int>> menuItems;

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
    final border = _booked
        ? Border.all(color: TripStatusColors.booked, width: 1.5)
        : Border.all(color: AppColors.divider.withValues(alpha: 0.8));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _info(vehicle, meta)),
                  const SizedBox(width: 8),
                  _price(),
                  SizedBox(
                    width: 40,
                    height: 44,
                    child: PopupMenuButton<int>(
                      padding: EdgeInsets.zero,
                      tooltip: TripStringsA3.more,
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: onMenu,
                      itemBuilder: (_) => menuItems,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: _actions(),
          ),
        ],
      ),
    );
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
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (reply.isNotEmpty) _replyPill(t.tripReplyLabel, reply),
          ],
        ),
        const SizedBox(height: 2),
        Text(vehicle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
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
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: rate == null ? 12 : 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
          ),
          if (rate != null)
            Text(cars > 1 ? TripStringsAlgoAa.carsPerDay(cars) : TripStringsV2Find.perDayShort,
                maxLines: 2,
                textAlign: TextAlign.end,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight)),
          if (rate != null && days > 1)
            Text(TripStringsV2Find.forDays(BrowseItem.inr(rate * days), days),
                maxLines: 2,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          if (extra != null && extra > 0)
            Text(TripStringsAlgoAa.extraKm(extra),
                maxLines: 2,
                textAlign: TextAlign.end,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.warningText)),
        ],
      ),
    );
  }

  Widget _actions() {
    final call = _button(
      icon: const Icon(Iconsax.call, size: 16, color: TaxiColors.accentDark),
      label: TripStringsV2Find.call,
      color: TaxiColors.accentDark,
      onTap: contactBusy ? null : onCall,
    );
    final wa = SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: contactBusy ? null : onWhatsApp,
        tooltip: TripStrings.whatsApp,
        style: IconButton.styleFrom(
          side: BorderSide(color: AppColors.whatsApp.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Image.asset('assets/images/whatsapp_icon.png',
            width: 20,
            height: 20,
            errorBuilder: (_, _, _) => const Icon(Icons.chat, color: AppColors.whatsApp, size: 20)),
      ),
    );
    final asked = status != null;
    final ask = SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onAsk,
        icon: Icon(asked ? Iconsax.eye : Iconsax.send_2, size: 16, color: asked ? TaxiColors.accentDark : Colors.white),
        label: Text(asked ? TripStringsA3.viewStatus : TripStringsV2Find.ask,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: asked ? TaxiColors.accentDark : Colors.white)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 44),
          backgroundColor: asked ? TaxiColors.surface : TaxiColors.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: call),
        const SizedBox(width: 8),
        wa,
        const SizedBox(width: 8),
        Expanded(child: ask),
      ],
    );
  }

  Widget _button({
    required Widget icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final c = onTap == null ? AppColors.textHint : color;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: filled ? AppColors.successSurface : null,
        side: BorderSide(color: c.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
          ),
        ],
      ),
    );
  }

  Widget _replyPill(String label, String text) {
    final (bg, fg) = switch (label) {
      'app' => (AppColors.successSurface, AppColors.successText),
      'phone' => (AppColors.warningSurface, AppColors.warningText),
      _ => (AppColors.neutralChip, AppColors.textMedium),
    };
    return _tag(text, fg, bg);
  }

  Widget _tag(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}
