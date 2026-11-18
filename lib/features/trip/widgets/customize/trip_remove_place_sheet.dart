import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/trip_plan_model.dart';
import '../../trip_strings_customize.dart';

class TripRemovePlaceSheet extends StatelessWidget {
  final TripSpotRef spot;
  final String dayLabel;

  const TripRemovePlaceSheet({super.key, required this.spot, required this.dayLabel});

  static Future<bool> show(BuildContext context, {required TripSpotRef spot, required String dayLabel}) async =>
      await SheetFrame.show<bool>(context, builder: (_) => TripRemovePlaceSheet(spot: spot, dayLabel: dayLabel)) ?? false;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return SheetFrame(
      tone: tone,
      art: ListingArt.clipboard,
      size: SheetSize.confirm,
      title: TripStringsCustomize.removeTitle(spot.name),
      subtitle: dayLabel,
      footer: PillButtonRow(
        children: [
          WhitePillButton(
            tone: tone,
            label: TripStringsCustomize.keepIt,
            neutral: true,
            onTap: () => Navigator.pop(context, false),
          ),
          GradientPillButton(
            key: const ValueKey('customize-remove-confirm'),
            tone: tone,
            label: TripStringsCustomize.removeFromTrip,
            danger: true,
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: DS.sym(h: 12, v: 10),
            decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(16)),
            child: Row(
              children: [
                Art3D(asset: TripSpotLook.assetOf(spot.category), size: 36, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
                Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title)),
                      Text(
                        TripStringsCustomize.spotLine(spot.category, spot.visitMinutes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.v(12),
          Text(TripStringsCustomize.removeBody, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w500, Ink3D.sub)),
        ],
      ),
    );
  }
}
