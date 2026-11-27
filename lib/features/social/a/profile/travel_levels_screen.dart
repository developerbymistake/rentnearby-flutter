import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/travel_level_widgets.dart';

class TravelLevelsScreen extends StatefulWidget {
  const TravelLevelsScreen({super.key});

  static const Key footerKey = ValueKey('travel_levels_footer');

  @override
  State<TravelLevelsScreen> createState() => _TravelLevelsScreenState();
}

class _TravelLevelsScreenState extends State<TravelLevelsScreen> {
  @override
  void initState() {
    super.initState();
    SocialMeController.maybe?.refreshQuiet();
  }

  @override
  Widget build(BuildContext context) {
    final c = SocialMeController.maybe;
    return BuddyPage(
      title: SocialStrings.travelLevelsTitle,
      subtitle: SocialStrings.travelLevelsSub,
      body: c == null ? _body(0, 0) : Obx(() {
        final p = c.me.value?.profile;
        if (p == null && c.loading.value) {
          return Padding(padding: DS.gapInsets(l: 18, t: 8, r: 18), child: SkeletonBox(height: DS.s(LevelSizes.skeleton), borderRadius: DS.br(CardRadius.hero)));
        }
        return _body(p?.completedTrips ?? 0, p?.level ?? 0);
      }),
    );
  }

  Widget _body(int trips, int level) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LevelTopCard(trips: trips, level: level),
          LevelListCard(level: level),
          Padding(
            padding: DS.gapInsets(l: 30, t: 14, r: 30, b: 10),
            child: Text(SocialStrings.levelsFooter, key: TravelLevelsScreen.footerKey, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35)),
          ),
        ],
      );
}
