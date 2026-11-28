import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/tab_config_controller.dart';
import '../../design/design.dart';
import '../../navigation/traveller_gate.dart';
import '../social/shared/social_me_controller.dart';
import '../social/shared/social_models.dart';
import '../social/shared/social_nav.dart';
import '../trip/widgets/hub/hub_art.dart';
import 'strings/seeker_home_strings.dart';

abstract final class HomeUpdateTargets {
  static void tripInvites() => Get.toNamed(AppRoutes.myTrips, arguments: {'tab': 'joined'});

  static void followRequests() => SocialNav.openPeople(tab: 'requests');

  static void joinRequests() => SocialNav.openTravelBuddies(tab: SocialNav.groupsMine);
}

class _UpdateTile {
  const _UpdateTile({required this.id, required this.title, required this.tone, required this.art, required this.count, required this.onTap});

  final String id;
  final String title;
  final ListingTone tone;
  final String art;
  final int count;
  final VoidCallback onTap;
}

class HomeUpdates extends StatelessWidget {
  const HomeUpdates({super.key});

  static const double tileContentScale = 0.9;

  static double tileWidth(double maxWidth) => (maxWidth - DS.s(20)) / 3;

  // FX-25: the Trip invites tile is hidden while the Trips module is off.
  static bool get _tripsOn {
    if (Get.isRegistered<AuthController>() && Get.isRegistered<TabConfigController>()) return Get.find<AuthController>().tripsEnabled;
    return TravellerGate.allowed && (!Get.isRegistered<TabConfigController>() || TabConfigController.to.isActiveForIndex(AppTabs.trips));
  }

  static List<_UpdateTile> _tiles(SocialMe? me) {
    if (!TravellerGate.allowed) return const [];
    return [
      if (_tripsOn)
        _UpdateTile(
          id: 'invites',
          title: SeekerHomeStrings.tileInvitesTitle,
          tone: ListingTone.cB,
          art: ListingArt.memo,
          count: me?.tripInvites ?? 0,
          onTap: HomeUpdateTargets.tripInvites,
        ),
      _UpdateTile(
        id: 'follow',
        title: SeekerHomeStrings.tileFollowTitle,
        tone: ListingTone.teal,
        art: HubArt.manRaising,
        count: me?.followRequests ?? 0,
        onTap: HomeUpdateTargets.followRequests,
      ),
      _UpdateTile(
        id: 'join',
        title: SeekerHomeStrings.tileJoinTitle,
        tone: ListingTone.coral,
        art: ListingArt.tent,
        count: me?.joinRequests ?? 0,
        onTap: HomeUpdateTargets.joinRequests,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = Get.isRegistered<TabConfigController>();
    final social = Get.isRegistered<SocialMeController>();
    if (!tabs && !social) return _build(_tiles(null));
    return Obx(() {
      if (tabs) TabConfigController.to.version.value;
      if (Get.isRegistered<AuthController>()) Get.find<AuthController>().roleKey.value;
      final me = social ? SocialMeController.to.me.value : null;
      return _build(_tiles(me));
    });
  }

  Widget _build(List<_UpdateTile> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: const TitleRow3D(title: SeekerHomeStrings.updatesTitle)),
        LayoutBuilder(
          builder: (context, box) {
            final width = tileWidth(box.maxWidth);
            return MealsRail(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final u in list)
                  Stack(
                    key: ValueKey('home-upd-${u.id}'),
                    clipBehavior: Clip.none,
                    fit: StackFit.passthrough,
                    children: [
                      MealsCardV(
                        width: width,
                        tone: u.tone,
                        art: u.art,
                        title: u.title,
                        titleLines: 2,
                        minCardHeight: 0,
                        contentScale: tileContentScale,
                        goIcon: Icons.arrow_forward,
                        onTap: u.onTap,
                        semanticsLabel: '${u.title}, ${u.count}',
                      ),
                      Positioned(
                        top: MealsCardV.cellPadding.top - DS.s(8),
                        right: MealsCardV.cellPadding.right - DS.s(3),
                        child: IgnorePointer(child: ExcludeSemantics(child: _CountPill(u.count))),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    if (count > 0) return RoundIconButton3D.count(text);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DS.s(5), vertical: DS.s(1)),
      constraints: BoxConstraints(minWidth: DS.s(17)),
      decoration: BoxDecoration(color: Ink3D.grey, borderRadius: BorderRadius.circular(DS.s(9))),
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: Ink3D.text(10, FontWeight.w500, Colors.white, letterSpacing: 0),
      ),
    );
  }
}
