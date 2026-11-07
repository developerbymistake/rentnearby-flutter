import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/plan_badge_chip.dart';
import '../../trip/trip_colors.dart';
import '../../trip/utils/trip_format.dart';
import '../models/taxi_browse_item.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_status.dart';
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
    final tags = <String>[
      if (t.isMatch && t.matchedTripType == 'RoundTrip') 'Round trip',
      if (t.isMatch && t.matchReversed) 'reverse',
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: booked
              ? Border.all(color: TripStatusColors.booked, width: 1.5)
              : selected
              ? Border.all(color: TaxiColors.accent, width: 1.5)
              : Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(t.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ),
                    if (_tripMode) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: _tripLabelPill(t.tripReplyLabel)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(
                    child: Text(vehicleLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
                  ),
                  for (final tag in tags) ...[
                    const SizedBox(width: 6),
                    _tagChip(tag),
                  ],
                  if (t.isFeatured) ...[
                    const SizedBox(width: 6),
                    const PlanBadgeChip(color: TaxiColors.accent),
                  ],
                ]),
                if (metaLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                ],
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _fareText()),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _actionsBar(),
        ]),
      ),
    );
  }

  Widget _actionsBar() {
    final cells = <Widget>[
      _action(
        icon: const Icon(Iconsax.call, size: 14, color: TaxiColors.accentDark),
        label: 'Call',
        color: TaxiColors.accentDark,
      ),
      _action(
        icon: Image.asset('assets/images/whatsapp_icon.png',
            width: 14,
            height: 14,
            errorBuilder: (_, _, _) => const Icon(Icons.chat, color: AppColors.whatsApp, size: 14)),
        label: 'WhatsApp',
        color: AppColors.whatsApp,
      ),
      if (onEnquire != null) _enquireCell(),
      if (onSelect != null)
        _action(
          icon: Icon(selected ? Iconsax.tick_circle : Iconsax.add_circle,
              size: 14, color: selected ? AppColors.success : TaxiColors.accentDark),
          label: selected ? TripStrings.selected : TripStrings.select,
          color: selected ? AppColors.success : TaxiColors.accentDark,
          onTap: onSelect,
        ),
      if (onBook != null)
        _action(
          icon: Icon(booked ? Iconsax.tick_circle : Iconsax.receipt_edit,
              size: 14, color: booked ? TripStatusColors.booked : TaxiColors.accentDark),
          label: booked ? TripStrings.booked : TripStrings.iBooked,
          color: booked ? TripStatusColors.booked : TaxiColors.accentDark,
          onTap: onBook,
        ),
    ];
    final split = cells.length > 4 ? (cells.length + 1) ~/ 2 : cells.length;
    final rows = [cells.sublist(0, split), if (split < cells.length) cells.sublist(split)];
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Material(
        color: Colors.transparent,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
            Row(children: [for (final c in rows[i]) Expanded(child: c)]),
          ],
        ]),
      ),
    );
  }

  Widget _enquireCell() {
    final status = enquiryStatus;
    if (status == null) {
      return _action(
        icon: const Icon(Iconsax.send_2, size: 14, color: TaxiColors.accentDark),
        label: TripStrings.enquiry,
        color: TaxiColors.accentDark,
        onTap: onEnquire,
      );
    }
    return InkWell(
      onTap: onEnquire,
      child: SizedBox(
        height: 44,
        child: Center(child: TripStatusPill(status, taxi: true)),
      ),
    );
  }

  Widget _fareText() {
    final t = item;
    final List<InlineSpan> spans = t.isMatch
        ? [
            TextSpan(text: BrowseItem.inr(t.matchedFare!)),
            if (t.matchedToName != null && t.matchedToName!.isNotEmpty)
              TextSpan(
                text: ' to ${t.matchedToName}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
          ]
        : [
            TextSpan(
                text: t.localDayRate != null ? TaxiOptionSets.localRateLabel(t.localDayRate!) : 'Local taxi'),
            if (t.localDayRate != null && t.localDayKm != null)
              TextSpan(
                text: ' · ${t.localDayKm} km/day',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
          ];
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
    );
  }

  Widget _avatar() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [TaxiColors.accent.withValues(alpha: 0.18), TaxiColors.accent.withValues(alpha: 0.06)],
          ),
        ),
        child: const Icon(Iconsax.car5, size: 26, color: TaxiColors.accent),
      );

  Widget _tripLabelPill(String label) {
    final text = TaxiOptionSets.tripReplyLabelText(label);
    if (text.isEmpty) return const SizedBox.shrink();
    final (bg, fg) = switch (label) {
      'app' => (AppColors.successSurface, AppColors.successText),
      'phone' => (AppColors.warningSurface, AppColors.warningText),
      _ => (AppColors.neutralChip, AppColors.textMedium),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _tagChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: TaxiColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            maxLines: 1,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
      );

  Widget _action({required Widget icon, required String label, required Color color, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap ?? onOpen,
        child: SizedBox(
          height: 44,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
          ]),
        ),
      );
}

class TaxiCardSkeleton extends StatelessWidget {
  const TaxiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: 130,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      );
}
