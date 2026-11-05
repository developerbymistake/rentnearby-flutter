import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_shadows.dart';
import '../controllers/my_trips_controller.dart';
import '../models/trip_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';

class TripHomeCard extends StatefulWidget {
  const TripHomeCard({super.key});

  @override
  State<TripHomeCard> createState() => _TripHomeCardState();
}

class _TripHomeCardState extends State<TripHomeCard> {
  final _trips = MyTripsController.to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _trips.ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _trips.items.length;
      _trips.upcoming.length;
      final running = _trips.runningTrip;
      if (running == null) {
        return _card(
          title: TripStrings.homeCardTitle,
          subtitle: TripStrings.homeCardSubtitle,
          action: TripStrings.start,
          onTap: () => TripNavigation.start(context),
        );
      }
      return _card(
        title: _runningTitle(running),
        subtitle: TripStringsA4.runningBody,
        action: TripStringsA4.open,
        onTap: () => TripNavigation.openPlan(tripId: running.id, fresh: true),
      );
    });
  }

  static String _runningTitle(TripSummaryModel t) {
    final start = t.startDate;
    if (start == null) return TripStringsA4.tomorrowTitle(t.routeLine);
    final now = DateTime.now();
    final n = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
    if (n < 1) return TripStringsA4.tomorrowTitle(t.routeLine);
    return TripStringsA4.runningTitle(n, t.dayCount, t.routeLine);
  }

  Widget _card({
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: TripColors.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.25, blur: 16, offset: const Offset(0, 6)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Iconsax.routing_2, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: TripColors.accentDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  action,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
