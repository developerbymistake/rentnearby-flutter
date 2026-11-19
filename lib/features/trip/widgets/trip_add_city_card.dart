import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/geo_distance.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_city_catalog.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_mca_a2.dart';
import '../trip_strings_mca_a3.dart';
import '../utils/trip_state_rule.dart';
import 'customize/trip_customize_spot_row.dart' show TripDashBox;

class TripAddCityCard extends StatefulWidget {
  const TripAddCityCard({super.key});

  static const Key cardKey = ValueKey('trip-add-city');
  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(40),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  static String? _disabledText(TripLegEditBlock b) => switch (b) {
        TripLegEditBlock.offline => TripStringsMcaA3.connectToAddCity,
        TripLegEditBlock.maxLegs => TripStringsMcaA3.maxCities,
        TripLegEditBlock.noDays => TripStringsMcaA3.noDaysLeft,
        _ => null,
      };

  static List<String> nearbyNames(TripPlan p, {int take = 2}) {
    final catalog = TripCityCatalog.to;
    catalog.warmFromDisk();
    if (!catalog.hasData || p.legs.isEmpty) return const [];
    final last = p.legs.last;
    final inTrip = {for (final l in p.legs) l.cityKey};
    final states = TripStateRule.statesOf(inTrip, catalog.search(''));
    final pool = [
      for (final c in TripStateRule.filter(catalog.ready(''), states))
        if (!inTrip.contains(c.cityKey)) c,
    ]..sort((a, b) => GeoDistance.km(last.latitude, last.longitude, a.latitude, a.longitude)
        .compareTo(GeoDistance.km(last.latitude, last.longitude, b.latitude, b.longitude)));
    return [for (final c in pool.take(take)) c.name];
  }

  @override
  State<TripAddCityCard> createState() => _TripAddCityCardState();
}

class _TripAddCityCardState extends State<TripAddCityCard> {
  @override
  void initState() {
    super.initState();
    final catalog = TripCityCatalog.to;
    catalog.warmFromDisk();
    if (!catalog.hasData) {
      catalog.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.offline.value;
      c.trip.value;
      if (p == null || c.isReadOnly || c.needsUpdate.value) return const SizedBox.shrink();
      final block = c.canAddLeg(null);
      if (block == TripLegEditBlock.readOnly) return const SizedBox.shrink();
      final enabled = block == TripLegEditBlock.none;
      final names = TripAddCityCard.nearbyNames(p);
      final subtitle = TripAddCityCard._disabledText(block) ?? (names.isEmpty ? TripStringsMcaA3.upToFourCities : TripStringsMcaA3.nearbyCities(names));
      return TemplateEntranceOnce(
        child: Padding(
          padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(24), DS.s(18), 0),
          child: Opacity(
            opacity: enabled ? 1 : Alpha.v60,
            child: Tap3D(
              tapKey: TripAddCityCard.cardKey,
              onTap: enabled ? () => TripNavigation.addCity(context) : null,
              label: TripStringsMcaA2.addACity,
              child: CustomPaint(
                painter: TripDashBox(TripLook.rail, DS.size, fill: DesignColors.surface, radius: DS.br(TripAddCityCard.radius)),
                child: Stack(
                  children: [
                    Container(
                      constraints: BoxConstraints(minHeight: DS.s(80)),
                      padding: EdgeInsets.fromLTRB(DS.s(92), DS.s(16), DS.s(16), DS.s(16)),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(child: Text(TripStringsMcaA2.addACity, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, TripLook.ink, letterSpacing: 0))),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
                        ],
                      ),
                    ),
                    Positioned(left: DS.s(14), top: DS.s(12), child: const IgnorePointer(child: Art3D(asset: ListingArt.worldMap, size: 62, shadowAlpha: 0))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
