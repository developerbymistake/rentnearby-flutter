import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../models/browse_item.dart';
import '../models/stay_nearby_model.dart';
import 'stay_guest_controller.dart';

class StayNearbyRow extends StatelessWidget {
  const StayNearbyRow({super.key, required this.stay, required this.index, this.onOpen});

  final StayNearbyModel stay;
  final int index;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final url = stay.thumbnailUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final place = [stay.cityName, stay.districtName].where((e) => e != null && e.isNotEmpty).join(', ');
    final price = stay.minPricePerNight;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: WideCard(
        tone: ListingTone.list(ListingTone.forest, index),
        kind: WideKind.photo,
        photo: hasPhoto ? SizedBox.expand(child: KitPhoto(url: url, width: double.infinity, height: double.infinity)) : null,
        art: hasPhoto ? null : ListingArt.hotel,
        badge: stay.isFeatured ? 'Featured' : null,
        tag: 'FOR STAY',
        title: stay.title,
        subtitle: place,
        chips: [
          if (stay.stayTypeName != null && stay.stayTypeName!.isNotEmpty) stay.stayTypeName!,
          if (stay.maxGuests != null) '${stay.maxGuests} guests',
        ],
        priceCaption: 'FROM',
        number: price != null ? BrowseItem.inr(price) : 'On request',
        unit: price != null ? '/night' : '',
        label: '${stay.distanceKm.toStringAsFixed(1)} km away',
        onTap: onOpen ?? () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': stay.id, 'distanceKm': stay.distanceKm}),
      ),
    );
  }
}

class StayNearbyListSheet extends StatelessWidget {
  const StayNearbyListSheet({super.key, required this.guest, required this.scrollController, required this.sheetContext});

  final StayGuestController guest;
  final ScrollController scrollController;
  final BuildContext sheetContext;

  static Future<void> show(BuildContext context, StayGuestController guest) {
    return SheetFrame.show<void>(
      context,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, controller) =>
            StayNearbyListSheet(guest: guest, scrollController: controller, sheetContext: sheetContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DesignColors.sheet, borderRadius: CardRadius.sheet, boxShadow: DesignShadows.top),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textGrey, Alpha.half), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() {
                  final count = guest.nearbyStays.length;
                  return Text(
                    '$count Stay${count == 1 ? '' : 's'} Nearby',
                    style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27),
                  );
                }),
                PressScale(
                  child: SizedBox(
                    width: KitMetrics.touch,
                    height: KitMetrics.touch,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: DesignColors.splash,
                      highlightColor: Colors.transparent,
                      onTap: () => Navigator.pop(sheetContext),
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(color: DesignColors.scaffold, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16, color: DesignColors.textStrong),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DesignColors.dividerSoft),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              final items = guest.nearbyStays.toList();
              return ListView.builder(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final row = StayNearbyRow(key: ValueKey(items[i].id), stay: items[i], index: i);
                  return i >= 10 ? row : KitCardEntrance(index: i, child: row);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
