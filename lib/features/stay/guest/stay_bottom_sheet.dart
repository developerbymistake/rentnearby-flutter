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
        padding: EdgeInsets.fromLTRB(DS.s(KitMetrics.gutter), 0, DS.s(KitMetrics.gutter), DS.s(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggerItem(
              index: 0,
              child: _SheetPhoto(url: stay.thumbnailUrl),
            ),
            Gap.v(16),
            StaggerItem(
              index: 1,
              child: Row(
                children: [
                  const TravelIcon(TravelIcon.stay, size: 24),
                  Gap.h(8),
                  Expanded(
                    flex: 3,
                    child: Text(stay.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.title),
                  ),
                  if (stay.minPricePerNight != null) ...[
                    Gap.h(8),
                    Flexible(
                      flex: 2,
                      child: Container(
                        padding: DS.sym(h: 12, v: 6),
                        decoration: BoxDecoration(gradient: _tone.gradient, borderRadius: DS.br(CardRadius.chip)),
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
            Gap.v(12),
            StaggerItem(index: 2, child: _typeRow()),
            Gap.v(20),
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
      Gap.h(4),
      Text('${stay.distanceKm.toStringAsFixed(1)} km away', style: TypeTokens.label.copyWith(color: TypeTokens.secondary)),
    ]);
    if (stay.stayTypeName == null || stay.stayTypeName!.isEmpty) return Row(children: [distance]);
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: DS.sym(h: 10, v: 4),
            decoration: BoxDecoration(color: _tone.tint, borderRadius: DS.br(CardRadius.pill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const TravelIcon(TravelIcon.stay, size: 16),
              Gap.h(5),
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
      Gap.h(8),
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
          height: DS.s(180),
          tone: KitTone.stay,
          radius: DS.br(KitMetrics.photo),
          iconSize: DS.s(72),
        ),
      );
}
