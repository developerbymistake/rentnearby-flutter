import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../viewer_strings.dart';

class ViewerOverviewHeader extends StatelessWidget {
  const ViewerOverviewHeader({super.key, required this.title, this.subtitle, required this.onBack, this.trailing = const [], this.tripTitle, this.tripLine});

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> trailing;
  final String? tripTitle;
  final String? tripLine;

  @override
  Widget build(BuildContext context) {
    final name = tripTitle;
    if (name == null) return TripFlowHeader(title: title, subtitle: subtitle, onBack: onBack, trailing: trailing);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ModuleHeader.lightIcons,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: ListingTone.indigo.gradient,
          borderRadius: DS.br(CardRadius.header),
          boxShadow: DS.shadows(TripLook.headerShadow),
        ),
        padding: EdgeInsets.fromLTRB(DS.s(14), MediaQuery.paddingOf(context).top, DS.s(14), DS.s(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TripFlowHeaderRow(title: title, subtitle: subtitle, onBack: onBack, trailing: trailing),
            Padding(
              padding: EdgeInsets.only(top: DS.gv(16)),
              child: Container(
                key: const ValueKey('viewer_trip_line'),
                padding: DS.sym(h: 16, v: 14),
                decoration: BoxDecoration(
                  gradient: TripCustomizeLook.tripCardGradient,
                  border: Border.all(color: TripCustomizeLook.tripCardBorder, width: DS.s(1)),
                  borderRadius: DS.br(TripCustomizeLook.tripLineRadius),
                  boxShadow: DS.shadows(TripCustomizeLook.tripCardShadow),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: DS.s(72),
                      height: DS.s(72),
                      child: Center(
                        child: Art3D(
                          asset: ListingArt.luggage,
                          size: 50,
                          halo: 72,
                          haloColor: DesignColors.surface,
                          shadowBlur: 4,
                          shadowOffset: const Offset(2, 3),
                        ),
                      ),
                    ),
                    Gap.h(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, TripCustomizeLook.tripCardName)),
                          if (tripLine != null)
                            Text(tripLine!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, TripCustomizeLook.tripCardSub, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripFlowHeaderRow extends StatelessWidget {
  const TripFlowHeaderRow({super.key, required this.title, this.subtitle, required this.onBack, this.trailing = const []});

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    const white = DesignColors.surface;
    final sub = subtitle;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(44)),
      child: Row(
        children: [
          Tap3D(
            tapKey: const ValueKey('viewer_back'),
            onTap: onBack,
            child: Container(
              width: DS.s(44),
              height: DS.s(44),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DesignColors.tint(white, Alpha.v22), shape: BoxShape.circle),
              child: Text(ViewerStrings.back, textScaler: TextScaler.noScaling, style: Ink3D.text(24, FontWeight.w400, white, height: 1, letterSpacing: 0)),
            ),
          ),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, white, height: 1.25, letterSpacing: 0)),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, DesignColors.tint(white, Alpha.v93), letterSpacing: 0)),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
