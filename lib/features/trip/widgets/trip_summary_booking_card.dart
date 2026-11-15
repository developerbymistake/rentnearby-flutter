import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import 'trip_status.dart';

class TripSummaryBookingCard extends StatelessWidget {
  const TripSummaryBookingCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.pill,
    this.rows = const [],
    this.body,
    this.payLine,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? pill;
  final List<(String, String)> rows;
  final Widget? body;
  final String? payLine;

  static double get topRoom => DS.s(40);

  static Widget statusPill(TripDisplayStatus s, {bool taxi = false, String? label}) => StatusPill3D(
        label: label ?? TripStatusVisuals.label(s, taxi: taxi),
        status: StatusTone3D.of(s.name),
      );

  @override
  Widget build(BuildContext context) {
    const white = DesignColors.surface;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 92.0 : 112.0;
    final artScaled = DS.s(artSize);
    final textLeft = DS.s(artSize + 20);
    final soft = DesignColors.tint(white, Alpha.v90);
    final labelStyle = Ink3D.text(12, FontWeight.w600, soft);
    final scaler = MediaQuery.textScalerOf(context);
    var labelW = DS.s(narrow ? 74.0 : 86.0);
    for (final r in rows) {
      final w = KitText.widthOf(r.$1, labelStyle, scaler) + DS.s(10);
      if (w > labelW) labelW = w;
    }
    labelW = labelW.clamp(0.0, MediaQuery.sizeOf(context).width * 0.4);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(DS.s(18), topRoom, DS.s(18), DS.gv(8)),
          child: Container(
            decoration: BoxDecoration(
              gradient: tone.gradient,
              borderRadius: DS.br(kMealsRadius),
              boxShadow: [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: artScaled - topRoom + DS.s(8)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(textLeft, DS.s(16), DS.s(16), DS.s(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((eyebrow ?? '').isNotEmpty)
                          Text(eyebrow!.toUpperCase(),
                              maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, soft, letterSpacing: 0.6)),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, white, height: 1.25)),
                        if ((subtitle ?? '').isNotEmpty)
                          Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, soft)),
                      ],
                    ),
                  ),
                ),
                if (pill != null)
                  Padding(
                    padding: DS.insets(l: 16, t: 8, r: 16),
                    child: Align(alignment: Alignment.centerLeft, child: pill),
                  ),
                if (rows.isNotEmpty)
                  Container(
                    margin: DS.insets(l: 14, t: 12, r: 14),
                    padding: DS.insets(l: 12, t: 8, r: 12, b: 10),
                    decoration: BoxDecoration(color: DesignColors.tint(white, Alpha.soft), borderRadius: DS.circular(14)),
                    child: Column(
                      children: [
                        for (final r in rows)
                          Padding(
                            padding: EdgeInsets.only(top: DS.s(3)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: labelW,
                                  child: Text(r.$1, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle),
                                ),
                                Expanded(child: Text(r.$2, style: Ink3D.text(12.5, FontWeight.w600, white))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (body != null) Padding(padding: DS.insets(l: 14, t: 12, r: 14), child: body),
                Gap.v(14),
                if ((payLine ?? '').isNotEmpty)
                  Container(
                    padding: DS.insets(l: 16, t: 10, r: 16, b: 12),
                    decoration: BoxDecoration(
                      color: DesignColors.tint(DesignColors.shadowBase, Alpha.tint),
                      borderRadius: DS.br(const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Art3D(asset: ListingArt.roundPushpin, size: 18, shadowBlur: 1, shadowOffset: Offset(1, 1)),
                        Gap.h(8),
                        Expanded(child: Text(payLine!, style: Ink3D.text(12, FontWeight.w600, white, height: 1.35))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: DS.s(26),
          top: 0,
          child: IgnorePointer(
            child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: DesignColors.tint(white, Alpha.v22)),
          ),
        ),
      ],
    );
  }
}
