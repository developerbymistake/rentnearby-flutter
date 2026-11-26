import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/widgets/public_trip_card.dart';
import '../social_strings_b.dart';
import 'trips_rail_controller.dart';

class TripsToJoinRail extends StatefulWidget {
  const TripsToJoinRail({super.key});

  static const double cardWidth = 290;

  @override
  State<TripsToJoinRail> createState() => _TripsToJoinRailState();
}

class _TripsToJoinRailState extends State<TripsToJoinRail> {
  @override
  void initState() {
    super.initState();
    final c = TripsRailController.maybe;
    if (c != null && !c.loaded.value && !c.loading.value) c.load();
  }

  void _open(PublicTrip t) {
    if (t.sample || t.tripId.isEmpty) {
      SocialNav.openTravelBuddies();
    } else {
      SocialNav.openTripPost(t.tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TripsRailController.maybe;
    if (c == null) return const SizedBox.shrink();
    return Obx(() {
      final items = c.items.toList();
      if (c.failed.value || items.isEmpty) return const SizedBox.shrink();
      return Column(
        key: const ValueKey('trips_to_join_rail'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: TitleRow3D(title: SocialStringsB.tripsToJoin, action: SocialStringsB.seeAll, onAction: () => SocialNav.openTravelBuddies()),
          ),
          LayoutBuilder(builder: (context, box) {
            final width = DS.s(TripsToJoinRail.cardWidth).clamp(0.0, box.maxWidth - DS.s(36)).toDouble();
            final pad = DS.insets(l: 18, t: 4, r: 18, b: 14);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: pad,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Gap.h(12),
                      SizedBox(
                        width: width,
                        child: PublicTripCard(
                          key: ValueKey('rail-${items[i].tripId}-$i'),
                          trip: items[i],
                          mode: PublicTripCardMode.rail,
                          onTap: () => _open(items[i]),
                        ),
                      ),
                    ],
                  ],
                ),
            );
          }),
        ],
      );
    });
  }
}
