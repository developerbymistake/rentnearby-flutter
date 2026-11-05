import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings_mca_a3.dart';

class TripAddCityCard extends StatelessWidget {
  const TripAddCityCard({super.key});

  static String? _disabledText(TripLegEditBlock b) => switch (b) {
        TripLegEditBlock.offline => TripStringsMcaA3.connectToAddCity,
        TripLegEditBlock.maxLegs => TripStringsMcaA3.maxCities,
        TripLegEditBlock.noDays => TripStringsMcaA3.noDaysLeft,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.offline.value;
      c.trip.value;
      if (p == null || c.isReadOnly || c.needsUpdate.value) return const SizedBox.shrink();
      final block = c.canAddLeg(null);
      if (block == TripLegEditBlock.readOnly) return const SizedBox.shrink();
      final disabled = _disabledText(block);
      final enabled = block == TripLegEditBlock.none;
      final tone = enabled ? TripColors.accentDark : AppColors.textHint;
      return Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => TripNavigation.addCity(context) : null,
          child: CustomPaint(
            painter: _DashedBorder(color: enabled ? TripColors.accent.withValues(alpha: 0.7) : AppColors.divider),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: enabled ? TripColors.surface.withValues(alpha: 0.5) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Iconsax.add, size: 20, color: tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TripStringsMcaA3.addAnotherCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled ? AppColors.textDark : AppColors.textHint),
                        ),
                        Text(
                          disabled ?? TripStringsMcaA3.upToFourCities,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)).deflate(0.75));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
