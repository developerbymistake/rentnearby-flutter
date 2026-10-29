import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
    final plateLine = [t.plateDisplay, t.locality].where((e) => e.isNotEmpty).join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.08, blur: 14, offset: const Offset(0, 5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: TaxiColors.gradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Iconsax.car, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(t.driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  const SizedBox(width: 6),
                  _badge('AVAILABLE', AppColors.success),
                ]),
                const SizedBox(height: 2),
                Text(vehicleLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
                if (plateLine.isNotEmpty)
                  Text(plateLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _fareBlock()),
            const SizedBox(width: 8),
            _badge('Plate checked', TaxiColors.accentDark, icon: Icons.verified_outlined),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _button(Icons.call_rounded, 'Call', const Color(0xFFF59E0B))),
            const SizedBox(width: 10),
            Expanded(child: _button(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366))),
          ]),
        ]),
      ),
    );
  }

  Widget _fareBlock() {
    final t = item;
    final List<InlineSpan> spans;
    final tags = <String>[];
    if (t.isMatch) {
      spans = [
        TextSpan(text: BrowseItem.inr(t.matchedFare!)),
        if (t.matchedToName != null && t.matchedToName!.isNotEmpty)
          TextSpan(
            text: ' to ${t.matchedToName}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
      ];
      if (t.matchedTripType == 'RoundTrip') tags.add('Round trip');
      if (t.matchReversed) tags.add('reverse');
    } else {
      spans = [
        const TextSpan(
          text: 'From ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
        TextSpan(text: t.minFare != null ? BrowseItem.inr(t.minFare!) : '-'),
        TextSpan(
          text: ' · ${t.routeCount} route${t.routeCount == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      ];
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold),
      ),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [for (final tag in tags) _badge(tag, AppColors.textMedium)]),
      ],
    ]);
  }

  Widget _badge(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _button(IconData icon, String label, Color color) => ElevatedButton.icon(
        onPressed: onOpen,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      );
}
