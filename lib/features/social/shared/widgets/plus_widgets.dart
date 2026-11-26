import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../models/plan_model.dart';
import '../../../buddy/shared/buddy_format.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../trip/widgets/hub/hub_art.dart';
import '../../c/plus/seeker_plan_keys.dart';
import '../../c/social_strings_c.dart';
import '../social_error_types.dart';
import '../social_me_controller.dart';
import '../social_models.dart';
import '../social_nav.dart';

class PlusBanner extends StatefulWidget {
  const PlusBanner({super.key, this.from = 'feed'});

  final String from;

  @override
  State<PlusBanner> createState() => _PlusBannerState();
}

class _PlusBannerState extends State<PlusBanner> {
  @override
  void initState() {
    super.initState();
    final plans = SeekerPlanKeys.plans;
    if (plans != null && plans.catalog.value == null) plans.loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final me = SocialMeController.maybe;
    if (me == null) return const SizedBox.shrink();
    return Obx(() {
      final limits = me.limits;
      if (limits.isPlus || !limits.canUpgrade) return const SizedBox.shrink();
      final plus = SeekerPlanKeys.plusPlan(SeekerPlanKeys.plans?.catalog.value);
      return _BannerCard(plus: plus, onTap: () => SocialNav.openPlus(from: widget.from));
    });
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.plus, required this.onTap});

  final PlanModel? plus;
  final VoidCallback onTap;

  static BorderRadius get _radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  List<(String, String)> _perks() {
    final p = plus;
    if (p == null) return const [];
    final join = p.feature(SeekerPlanKeys.joinRequests);
    final chats = p.feature(SeekerPlanKeys.newChats);
    final pub = p.feature(SeekerPlanKeys.publicTrips);
    final act = p.feature(SeekerPlanKeys.activeTrips);
    return [
      if (join > 0) (ListingArt.panda, SocialStringsC.joinRequests(join)),
      if (chats > 0) (ListingArt.speechBalloon, SocialStringsC.bannerChats(chats)),
      if (pub > 0 && act > 0) (ListingArt.luggage, SocialStringsC.bannerTrips(pub, act)),
      if (p.feature(SeekerPlanKeys.genderOnly) > 0) (HubArt.womanRaising, SocialStringsC.genderOnly),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.cF;
    return Padding(
      padding: DS.gapInsets(l: 18, t: 18, r: 18, b: 18),
      child: Tap3D(
        onTap: onTap,
        label: '${SocialStringsC.bannerKicker}. ${SocialStringsC.bannerTitle}. ${SocialStringsC.seePlus}',
        exclude: true,
        child: Container(
          key: const ValueKey('plus_banner'),
          padding: DS.insets(l: 18, t: 16, r: 18, b: 16),
          decoration: BoxDecoration(gradient: tone.gradient, borderRadius: _radius, boxShadow: tone.glow(dy: 6, blur: 14)),
          child: Stack(
            children: [
              Positioned(right: 0, top: DS.s(6), child: const ExcludeSemantics(child: Art3D(asset: ListingArt.star, size: 72))),
              Padding(
                padding: DS.insets(r: 84),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SocialStringsC.bannerKicker, style: Ink3D.text(11.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 1)),
                    Gap.v(2),
                    Text(SocialStringsC.bannerTitle, style: Ink3D.text(22, FontWeight.w700, DesignColors.onPrimary, height: 1.2)),
                    for (final (art, text) in _perks()) ...[
                      Gap.v(6),
                      Row(children: [
                        Image.asset(art, width: DS.s(24), height: DS.s(24)),
                        Gap.h(8),
                        Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, DesignColors.onPrimary, letterSpacing: 0))),
                      ]),
                    ],
                    Gap.v(12),
                    Container(
                      padding: DS.sym(h: 14, v: 5),
                      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(16)),
                      child: Text('${SocialStringsC.seePlus} →', style: Ink3D.text(13, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlusLockLine extends StatelessWidget {
  const PlusLockLine({super.key, required this.text, required this.from});

  final String text;
  final String from;

  @override
  Widget build(BuildContext context) {
    final me = SocialMeController.maybe;
    final canUpgrade = me == null || me.limits.canUpgrade;
    return Padding(
      padding: DS.gapInsets(t: 6, b: 6),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: DS.s(16), color: BuddyLook.greyText),
          Gap.h(6),
          Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0, height: 1.4))),
          if (canUpgrade)
            Tap3D(
              key: const ValueKey('plus_lock_see_plus'),
              onTap: () => SocialNav.openPlus(from: from),
              label: SocialStringsC.seePlus,
              exclude: true,
              child: Padding(
                padding: DS.sym(h: 8, v: 6),
                child: Text(SocialStringsC.seePlus, style: Ink3D.text(13, FontWeight.w700, BuddyLook.indigoText, letterSpacing: 0)),
              ),
            ),
        ],
      ),
    );
  }
}

abstract final class PlusSheets {
  static const Set<String> _types = {
    SocialErrorTypes.publicTripLimit,
    SocialErrorTypes.joinRequestLimit,
    SocialErrorTypes.newChatLimit,
    SocialErrorTypes.plusRequired,
    SocialErrorTypes.tripLimitReached,
  };

  static bool handles(String? errorType) => errorType != null && _types.contains(errorType);

  static String lineFor(String errorType, SocialLimits limits, Map<String, dynamic> data) {
    int limitOr(int fallback) => BuddyJson.integer(data['limit'], fallback);
    return switch (errorType) {
      SocialErrorTypes.publicTripLimit => SocialStringsC.publicLimitLine(limitOr(limits.publicTrips.limit)),
      SocialErrorTypes.joinRequestLimit => SocialStringsC.joinLimitLine(limitOr(limits.joinRequests.limit)),
      SocialErrorTypes.newChatLimit => SocialStringsC.chatLimitLine(limitOr(limits.newChats.limit)),
      SocialErrorTypes.tripLimitReached => SocialStringsC.tripLimitLine(limitOr(limits.activeTrips.limit)),
      _ => SocialStringsC.plusFeatureLine,
    };
  }

  static Future<void> limitReached(BuildContext context, {required String errorType, Map<String, dynamic> data = const {}, String from = 'limit'}) async {
    final me = SocialMeController.maybe;
    final quiet = me?.refreshQuiet();
    final limits = me?.limits ?? SocialLimits.free;
    final canUpgrade = BuddyJson.boolean(data['canUpgrade'], limits.canUpgrade);
    final resets = BuddyJson.time(data['resetsAt']) ?? (errorType == SocialErrorTypes.plusRequired ? null : limits.resetsAt);
    final line = lineFor(errorType, limits, data);
    final monthly = errorType == SocialErrorTypes.joinRequestLimit || errorType == SocialErrorTypes.newChatLimit;
    final body = monthly && resets != null ? '$line ${SocialStringsC.resetsOn(BuddyFormat.dayMonth(resets.toLocal()))}' : line;
    final title = errorType == SocialErrorTypes.plusRequired ? SocialStringsC.plusFeatureTitle : SocialStringsC.limitReachedTitle;
    if (!context.mounted) return;
    final tone = ListingTone.indigo;
    await Sheet3D.show<void>(
      context,
      builder: (c) => Sheet3D(
        tone: tone,
        art: ListingArt.star,
        title: title,
        subtitle: body,
        child: Column(
          key: const ValueKey('plus_limit_sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUpgrade)
              GradientPillButton(
                tone: tone,
                label: SocialStringsC.seePlus,
                onTap: () {
                  Navigator.of(c).pop();
                  SocialNav.openPlus(from: from);
                },
              ),
            Gap.v(10),
            Tap3D(
              onTap: () => Navigator.of(c).pop(),
              label: canUpgrade ? SocialStringsC.notNow : SocialStringsC.ok,
              exclude: true,
              child: Padding(
                padding: DS.sym(v: 10),
                child: Text(canUpgrade ? SocialStringsC.notNow : SocialStringsC.ok, style: Ink3D.text(14, FontWeight.w600, BuddyLook.subText, letterSpacing: 0)),
              ),
            ),
          ],
        ),
      ),
    );
    await quiet;
  }
}
