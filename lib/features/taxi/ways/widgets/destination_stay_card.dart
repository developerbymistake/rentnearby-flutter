import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../../config/app_routes.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../stay/models/stay_nearby_model.dart';
import '../../../trip/utils/trip_format.dart';
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
      child: Container(
        decoration: TripLook.card(radius: TripLook.softRadius),
        child: ClipRRect(
          borderRadius: TripLook.softRadius,
          child: Material(
            color: DesignColors.surface,
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
                          style: FitnessAppTheme.title.copyWith(fontSize: 13)),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitnessAppTheme.caption.copyWith(fontSize: 11)),
                      if (price != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(TaxiWaysStrings.perNight(price),
                                maxLines: 1,
                                style: FitnessAppTheme.title.copyWith(fontSize: 13, color: DesignColors.primary)),
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
                  child: PrimaryButton(
                    label: TaxiWaysStrings.askRoom,
                    tone: KitTone.stay,
                    compact: true,
                    scaleLabel: true,
                    onPressed: _ask,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: double.infinity,
        color: PickKit.stayTint,
        alignment: Alignment.center,
        child: const TravelIcon(TravelIcon.stay, size: 28),
      );
}
