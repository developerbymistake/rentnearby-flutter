import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Package pricing block — price OR "Get Custom Quote" OR "Starting at ₹X",
/// plus the discount badge. The badge/strikethrough treatment (green pill,
/// "X% Savings", struck-through "was" price) is ported verbatim from
/// go_live_plan_sheet.dart's `_PlanListView` — but note the field roles are
/// NOT copied verbatim, because ServicePackage's Price/OriginalPrice are the
/// conventional way round (Price = current/charged, OriginalPrice = "was"),
/// the opposite of how CoinPlan's Price/OriginalPrice happen to be used
/// there. See ServicePackageModel's doc comment.
///
/// Used by both the Service Detail package-preview cards and the full
/// Package List cards — one shared rendering so the two screens can never
/// drift on how a discount/quote/starting-at price looks.
class ServicePackagePrice extends StatelessWidget {
  final int? price;
  final int? originalPrice;
  final int? discountPercent;
  final bool isStartingAtPrice;
  final String? priceUnit;
  final double priceFontSize;
  final Color priceColor;

  const ServicePackagePrice({
    super.key,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.isStartingAtPrice,
    required this.priceUnit,
    this.priceFontSize = 18,
    this.priceColor = AppColors.textDark,
  });

  bool get _hasDiscount => (discountPercent ?? 0) > 0 && price != null && (originalPrice ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    if (price == null) {
      return const Text(
        'Get Custom Quote',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasDiscount)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹$originalPrice',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '$discountPercent% Savings',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isStartingAtPrice)
              Text(
                'Starting at ',
                style: TextStyle(fontFamily: 'Poppins', fontSize: priceFontSize * 0.6, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
            Text(
              '₹$price',
              style: TextStyle(fontFamily: 'Poppins', fontSize: priceFontSize, fontWeight: FontWeight.w800, color: priceColor),
            ),
            if (priceUnit != null && priceUnit!.trim().isNotEmpty)
              Text(
                ' / ${priceUnit!}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textLight),
              ),
          ],
        ),
      ],
    );
  }
}
