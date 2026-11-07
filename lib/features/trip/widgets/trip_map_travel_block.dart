import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/taxi_option_sets.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_journey_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_format.dart';
import 'trip_journey_strip.dart';

class TripMapTravelBlock extends StatelessWidget {
  final int legIndex;
  final bool dense;

  const TripMapTravelBlock({super.key, required this.legIndex, this.dense = true});

  static String? _validPhone(String? raw) => raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;

  static String? _phoneOf(List<String?> all) {
    for (final p in all) {
      final v = _validPhone(p);
      if (v != null) return v;
    }
    return null;
  }

  String _lineOf(TripPlanController c) => TripStringsMcbA1.stateLabel(c.travelStateOf(legIndex));

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.trip.value;
      c.enquiryList.length;
      final p = c.plan.value;
      final leg = p?.legAt(legIndex);
      if (p == null || leg == null || legIndex < 2) return const SizedBox.shrink();
      final from = p.legAt(legIndex - 1)?.cityName ?? leg.arrival?.fromName ?? '';
      final headline = c.travelHeadline(legIndex);
      final route = [TripStringsMcaA3.fromTo(from, leg.cityName), ?headline].join(' · ');
      final a = leg.arrival;
      final rows = <Widget>[];
      Widget? open;
      if (a == null) {
        final own = leg.travelMark?.isOwn ?? false;
        rows.add(_row(
          initial: null,
          icon: Iconsax.routing_2,
          title: own ? TripStringsV2Plan.todayYourTravel : TripStringsMcaA3.travelTo(leg.cityName),
          subtitle: own ? null : TripStringsMcaA3.notPlannedYet,
          phone: null,
        ));
      } else {
        final j = c.segmentJourney(legIndex);
        if (j != null) {
          for (var i = 0; i < j.legs.length; i++) {
            rows.add(_carRow(c, j.legs[i], i + 1));
          }
          open = Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => TripNavigation.openJourney(j.id),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Iconsax.routing_2, size: 16, color: TaxiColors.accentDark),
              label: const Text(
                TripStringsMcbA2.openJourney,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
              ),
            ),
          );
        } else {
          rows.add(_row(
            initial: null,
            icon: Iconsax.routing_2,
            title: TripStringsMcaA3.travelTo(leg.cityName),
            subtitle: _lineOf(c),
            phone: null,
          ));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Iconsax.car, size: 14, color: TaxiColors.accentDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  route,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          for (final r in rows) ...[SizedBox(height: dense ? 6 : 8), r],
          ?open,
        ],
      );
    });
  }

  Widget _carRow(TripPlanController c, TripJourneyLeg l, int car) {
    final booking = c.carBooking(legIndex, car);
    final pickup = booking?.taxi?.pickupTime;
    final agreed = booking?.taxi?.agreedFare;
    final fare = (agreed != null && agreed > 0) ? agreed : TripJourneyStrip.fareOf(l);
    final subtitle = [
      TripStringsMcbA2.carTo(car, l.toName),
      if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
      if (fare != null) BrowseItem.inr(fare),
    ].join(' · ');
    final name = TripJourneyStrip.driverOf(l.driverName);
    return _row(
      initial: name.isEmpty ? null : name.substring(0, 1).toUpperCase(),
      icon: Iconsax.car,
      title: name,
      subtitle: subtitle,
      phone: _phoneOf([booking?.owner.phone, l.phone, l.whatsApp]),
      tone: TripJourneyStrip.carColor(car - 1),
    );
  }

  Widget _row({
    required String? initial,
    required IconData icon,
    required String title,
    required String? subtitle,
    required String? phone,
    Color tone = TaxiColors.accentDark,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: TaxiColors.surface, shape: BoxShape.circle),
          child: initial != null
              ? Text(
                  initial,
                  maxLines: 1,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: tone),
                )
              : Icon(icon, size: 15, color: tone),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
            ],
          ),
        ),
        if (phone != null)
          TextButton.icon(
            onPressed: () => ContactLauncher.call(phone),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
            icon: const Icon(Iconsax.call, size: 16, color: TaxiColors.accentDark),
            label: const Text(
              TripStringsMcbA2.call,
              maxLines: 1,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
            ),
          ),
      ],
    );
  }
}
