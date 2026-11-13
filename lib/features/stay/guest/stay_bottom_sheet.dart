import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../models/stay_nearby_model.dart';

class StayBottomSheet extends StatelessWidget {
  final StayNearbyModel stay;
  const StayBottomSheet({super.key, required this.stay});

  static const _tone = KitTone.stay;

  static Future<void> show(BuildContext context, StayNearbyModel stay) =>
      SheetFrame.show<void>(context, builder: (_) => StayBottomSheet(stay: stay));

  @override
  Widget build(BuildContext context) {
    return StaggerHost(
      count: 4,
      child: SheetFrame(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggerItem(
              index: 0,
              child: _SheetPhoto(url: stay.thumbnailUrl),
            ),
            const SizedBox(height: 16),
            StaggerItem(
              index: 1,
              child: Row(
                children: [
                  const TravelIcon(TravelIcon.stay, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(stay.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.title),
                  ),
                  if (stay.minPricePerNight != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(gradient: _tone.gradient, borderRadius: CardRadius.chip),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'From ${BrowseItem.inr(stay.minPricePerNight!)}/night',
                            maxLines: 1,
                            softWrap: false,
                            style: TypeTokens.style(13, FontWeight.w700, color: DesignColors.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            StaggerItem(index: 2, child: _typeRow()),
            const SizedBox(height: 20),
            StaggerItem(
              index: 3,
              child: PrimaryButton(
                label: 'View Details',
                tone: _tone,
                trailingArrow: true,
                onPressed: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.stayDetail, arguments: {'id': stay.id, 'distanceKm': stay.distanceKm});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeRow() {
    final distance = Row(mainAxisSize: MainAxisSize.min, children: [
      const TravelIcon(TravelIcon.place, size: 14),
      const SizedBox(width: 4),
      Text('${stay.distanceKm.toStringAsFixed(1)} km away', style: TypeTokens.label.copyWith(color: TypeTokens.secondary)),
    ]);
    if (stay.stayTypeName == null || stay.stayTypeName!.isEmpty) return Row(children: [distance]);
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _tone.tint, borderRadius: CardRadius.pill),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const TravelIcon(TravelIcon.stay, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(stay.stayTypeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(12, FontWeight.w600, color: _tone.accentDark)),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      distance,
    ]);
  }
}

class _SheetPhoto extends StatelessWidget {
  const _SheetPhoto({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => KitPhoto(
          url: url,
          width: c.maxWidth,
          height: 180,
          tone: KitTone.stay,
          radius: KitMetrics.photo,
          iconSize: 72,
        ),
      );
}
