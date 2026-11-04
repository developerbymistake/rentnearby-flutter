import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../config/app_colors.dart';
import '../../../../controllers/location_controller.dart';
import '../../../../models/place_result_model.dart';
import '../../../../utils/app_toast.dart';
import '../../guest/traveller_city.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_navigation.dart';
import '../trip_strings_a6.dart';

class TripWaysLink extends StatelessWidget {
  final String cityName;
  final double lat;
  final double lng;
  final DateTime? date;
  final int? people;
  final EdgeInsets? padding;

  const TripWaysLink({
    super.key,
    required this.cityName,
    required this.lat,
    required this.lng,
    this.date,
    this.people,
    this.padding,
  });

  static PlaceResult? myLocation() {
    if (!Get.isRegistered<LocationController>()) return null;
    final loc = Get.find<LocationController>();
    final city = travellerCity(loc);
    if (city != null) return city.place;
    final gps = loc.userLocation.value;
    return gps == null ? null : PlaceResult(name: '', subtitle: '', latLng: gps);
  }

  void _open() {
    final from = myLocation();
    if (from == null) {
      AppToast.warning(TripStringsA6.noLocation);
      return;
    }
    TaxiWaysNavigation.openFeed(
      from: from,
      to: PlaceResult(name: cityName, subtitle: '', latLng: LatLng(lat, lng)),
      fromMyLocation: true,
      date: date,
      people: people,
      fromTrip: date != null || people != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Material(
            color: TaxiColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: TaxiColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Iconsax.routing_2, size: 17, color: TaxiColors.accentDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          TripStringsA6.waysLinkTitle(cityName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TaxiColors.accentDark,
                          ),
                        ),
                        const Text(
                          TripStringsA6.waysLinkBody,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMedium),
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
          ),
        ),
      ),
    );
  }
}
