import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../models/taxi_browse_item.dart';
import '../taxi_option_sets.dart';

class TaxiCard extends StatelessWidget {
  final TaxiBrowseItem item;
  final VoidCallback onOpen;

  const TaxiCard({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = item;
    final vehicleLine = [
      t.vehicleTypeName,
      if (t.seats != null) '${TaxiOptionSets.seatsLabel(t.seats!)} seats',
    ].join(' · ');
    final metaLine = [t.plateDisplay, t.locality].where((e) => e.isNotEmpty).join(' · ');
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
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(t.driverName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              const SizedBox(width: 8),
              const _AvailablePill(),
            ],
          ),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
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
          ]),
          if (metaLine.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(metaLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _fareText(),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _checkedChip(),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            child: Material(
              color: Colors.transparent,
              child: Row(children: [
                Expanded(
                  child: _action(
                    icon: const Icon(Iconsax.call, size: 14, color: TaxiColors.accentDark),
                    label: 'Call',
                    color: TaxiColors.accentDark,
                  ),
                ),
                Expanded(
                  child: _action(
                    icon: Image.asset('assets/images/whatsapp_icon.png',
                        width: 14,
                        height: 14,
                        errorBuilder: (_, _, _) => const Icon(Icons.chat, color: AppColors.whatsApp, size: 14)),
                    label: 'WhatsApp',
                    color: AppColors.whatsApp,
                  ),
                ),
              ]),
            ),
          ),
        ]),
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
        : [const TextSpan(text: 'Local taxi')];
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
    );
  }

  Widget _checkedChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: TaxiColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Iconsax.tick_circle, size: 12, color: TaxiColors.accent),
          SizedBox(width: 4),
          Text(TaxiOptionSets.plateCheckedLabel,
              maxLines: 1,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: TaxiColors.accent)),
        ]),
      );

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

  Widget _action({required Widget icon, required String label, required Color color}) => InkWell(
        onTap: onOpen,
        child: SizedBox(
          height: 36,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 6),
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

class _AvailablePill extends StatelessWidget {
  const _AvailablePill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.successSurface, borderRadius: BorderRadius.circular(999)),
        child: const Text('AVAILABLE',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.successText)),
      );
}

class TaxiCardSkeleton extends StatelessWidget {
  const TaxiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: 150,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      );
}
