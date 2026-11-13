import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/browse_item.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../stay/models/stay_nearby_model.dart';
import '../../../trip/utils/trip_format.dart';
import '../taxi_ways_strings.dart';

class DestinationStayCard extends StatelessWidget {
  static const List<String> _stickers = [ListingArt.key, ListingArt.bed, ListingArt.hotel];

  final StayNearbyModel stay;
  final String cityName;
  final DateTime date;
  final int people;
  final double width;
  final int index;

  const DestinationStayCard({
    super.key,
    required this.stay,
    required this.cityName,
    required this.date,
    required this.people,
    this.width = 160,
    this.index = 0,
  });

  static double heightFor(BuildContext context) => JourneyRailCard3D.heightFor(context);

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
    final url = stay.thumbnailUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final place = (stay.cityName ?? '').isNotEmpty ? stay.cityName! : cityName;
    return JourneyRailCard3D(
      tone: ListingTone.forest,
      title: stay.title,
      lines: [
        [place, TripFormat.km(stay.distanceKm)].where((e) => e.isNotEmpty).join(' · '),
        if (stay.stayTypeName != null) stay.stayTypeName!,
      ],
      photo: hasPhoto ? KitPhoto(url: url, width: 100, height: 100, asset: TravelIcon.stay, iconSize: 40) : null,
      sticker: hasPhoto ? _stickers[index % _stickers.length] : null,
      art: hasPhoto ? null : ListingArt.hotel,
      number: price == null ? null : BrowseItem.inr(price),
      unit: price == null ? '' : ' /night',
      buttonLabel: TaxiWaysStrings.askRoom,
      width: width,
      onTap: _ask,
    );
  }
}
