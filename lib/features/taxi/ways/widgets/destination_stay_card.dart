import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../stay/models/stay_nearby_model.dart';
import '../../../trip/utils/trip_format.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_strings.dart';

class DestinationStayCard extends StatelessWidget {
  static const double baseHeight = 232;

  final StayNearbyModel stay;
  final String cityName;
  final DateTime date;
  final int people;
  final double width;

  const DestinationStayCard({
    super.key,
    required this.stay,
    required this.cityName,
    required this.date,
    required this.people,
    this.width = 190,
  });

  static double heightFor(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return baseHeight + (s - 1) * 90;
  }

  void _open() => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': stay.id});

  void _ask() {
    final phone = stay.ownerPhone;
    if (phone == null || phone.isEmpty) {
      _open();
      return;
    }
    ContactLauncher.whatsApp(phone, message: TaxiWaysStrings.roomAskMessage(cityName, date, people));
  }

  @override
  Widget build(BuildContext context) {
    final price = stay.minPricePerNight;
    final sub = [if (stay.stayTypeName != null) stay.stayTypeName!, TripFormat.km(stay.distanceKm)].join(' · ');
    return SizedBox(
      width: width,
      height: heightFor(context),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: _open,
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: stay.thumbnailUrl == null
                  ? _placeholder()
                  : CachedNetworkImage(
                      imageUrl: stay.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _placeholder(),
                      placeholder: (_, _) => _placeholder(),
                    ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stay.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  if (price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(TaxiWaysStrings.perNight(price),
                            maxLines: 1,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TaxiColors.accentDark)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _ask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TaxiColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(TaxiWaysStrings.askRoom,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: TaxiColors.surface,
        alignment: Alignment.center,
        child: const Icon(Iconsax.home_2, size: 28, color: TaxiColors.accent),
      );
}
