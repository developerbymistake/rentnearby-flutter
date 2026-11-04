import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_shadows.dart';
import '../../../../models/place_result_model.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_navigation.dart';
import '../taxi_ways_strings.dart';

class TaxiWaysEntryCard extends StatelessWidget {
  final PlaceResult from;
  final PlaceResult to;
  final bool empty;
  final bool fromMyLocation;

  const TaxiWaysEntryCard({
    super.key,
    required this.from,
    required this.to,
    this.empty = false,
    this.fromMyLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = empty ? TaxiWaysStrings.entryEmptyTitle : TaxiWaysStrings.entryTitle;
    final body = empty ? TaxiWaysStrings.entryEmptyBody : TaxiWaysStrings.entryBody(to.name);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, empty ? 16 : 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => TaxiWaysNavigation.openFeed(from: from, to: to, fromMyLocation: fromMyLocation),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: BoxDecoration(
              gradient: TaxiColors.heroGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.35)),
              boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.10, blur: 14, offset: const Offset(0, 5)),
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: TaxiColors.gradient, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Iconsax.routing_2, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium),
                  ),
                ]),
              ),
              const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.chevron_right_rounded, size: 24, color: TaxiColors.accentDark),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
