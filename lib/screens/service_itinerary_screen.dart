import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../models/service_detail_model.dart';

/// "See Your Journey" — a pushed, back-navigable itinerary page reached from
/// Service Detail's CTA. Renders the already-loaded [ServiceDetailModel]
/// (no network call of its own): trip header, pickup/nights/meals info rows,
/// then the day-by-day timeline, with the disclaimer always visible at the
/// bottom when present.
class ServiceItineraryScreen extends StatelessWidget {
  final ServiceDetailModel service;

  const ServiceItineraryScreen({super.key, required this.service});

  String? get _duration {
    for (final p in service.packages) {
      if (p.durationDays == null) continue;
      return p.durationNights != null
          ? '${p.durationDays}D / ${p.durationNights}N'
          : '${p.durationDays} day${p.durationDays == 1 ? '' : 's'}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = service.itineraryDays;
    final disclaimer = service.itineraryDisclaimer;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Your Journey',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(duration: const Duration(milliseconds: 300), from: 12, child: _buildHeaderCard()),
            const SizedBox(height: 20),
            if (days.isNotEmpty) ...[
              FadeInUp(
                duration: const Duration(milliseconds: 260),
                from: 10,
                child: const Text(
                  'Day-by-Day Itinerary',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < days.length; i++)
                      FadeInUp(
                        duration: const Duration(milliseconds: 260),
                        delay: Duration(milliseconds: 60 * i),
                        from: 12,
                        child: _DayStep(
                          day: days[i],
                          isLast: i == days.length - 1,
                          // Each day gets its own tint along a single blend of the app's own two
                          // brand colours (primary -> accent) — distinct per day without pulling
                          // in colours the app doesn't already use elsewhere.
                          color: Color.lerp(AppColors.primary, AppColors.accent, days.length > 1 ? i / (days.length - 1) : 0)!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (disclaimer != null && disclaimer.isNotEmpty) ...[
              const SizedBox(height: 18),
              FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 60 * days.length + 120),
                from: 12,
                child: _buildDisclaimer(disclaimer),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.045),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, size: 16, color: AppColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PLEASE NOTE',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.primary),
                ),
                const SizedBox(height: 5),
                Text(
                  disclaimer,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textMedium, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final duration = _duration;
    final pickup = service.pickupDropLocation;
    final nights = service.nightsBreakdown;
    final meals = service.mealsNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.map_1, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.name,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          if (duration != null) ...[
            const SizedBox(height: 8),
            Text(
              duration,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ],
          if ((pickup != null && pickup.isNotEmpty) ||
              (nights != null && nights.isNotEmpty) ||
              (meals != null && meals.isNotEmpty)) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
          ],
          if (pickup != null && pickup.isNotEmpty) ...[
            _infoRow(Iconsax.location, 'Pickup & Drop', pickup),
            const SizedBox(height: 10),
          ],
          if (nights != null && nights.isNotEmpty) ...[
            _infoRow(Iconsax.moon, 'Stay', nights),
            const SizedBox(height: 10),
          ],
          if (meals != null && meals.isNotEmpty) _infoRow(Iconsax.cup, 'Meals', meals),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Colors.white, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _DayStep extends StatelessWidget {
  final ItineraryDayModel day;
  final bool isLast;
  final Color color;

  const _DayStep({required this.day, required this.isLast, required this.color});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 4)],
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.only(top: 6), color: color.withValues(alpha: 0.35))),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAY ${day.dayNumber.toString().padLeft(2, '0')}',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: color),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    day.title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    day.description,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
