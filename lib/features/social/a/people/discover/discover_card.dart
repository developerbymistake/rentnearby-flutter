import 'package:flutter/material.dart';

import '../../../../../design/design.dart';
import '../../../../buddy/shared/buddy_look.dart';
import '../../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../shared/data/follow_api.dart';
import '../../../shared/social_models.dart';
import '../../../shared/social_nav.dart';
import '../../../shared/widgets/follow_button.dart';
import '../../../shared/widgets/travel_level_widgets.dart';
import '../../social_strings_a.dart';

/// One suggested traveller (A1 grid card; [small] = rail card of B1/B2: no username, no X).
class DiscoverCard extends StatelessWidget {
  const DiscoverCard({
    super.key,
    required this.item,
    required this.reason,
    this.onHide,
    this.onFollowChanged,
    this.small = false,
    this.api = const FollowApi(),
  });

  final DiscoverPerson item;
  final String reason;
  final VoidCallback? onHide;
  final void Function(bool iFollow, bool requested)? onFollowChanged;
  final bool small;
  final FollowApi api;

  static Key keyOf(String userId) => ValueKey('discover_$userId');
  static Key hideKeyOf(String userId) => ValueKey('discover_hide_$userId');

  static String artOf(String kind) => switch (kind) {
        DiscoverReasonKinds.sameTrip => ListingArt.mountain,
        DiscoverReasonKinds.travelledWith => ListingArt.luggage,
        DiscoverReasonKinds.near => ListingArt.roundPushpin,
        DiscoverReasonKinds.interests || DiscoverReasonKinds.places => ListingArt.compass,
        _ => ListingArt.panda,
      };

  Widget _avatar() {
    final p = item.person;
    final size = small ? BuddyAvatarSize.md : BuddyAvatarSize.lg;
    final level = p.travelLevel;
    return SizedBox(
      width: DS.s(size.box),
      height: DS.s(size.box),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BuddyAvatar(initial: p.initial, seed: p.userId, size: size, photoUrl: p.photoUrl),
          Positioned(
            right: -DS.s(4),
            bottom: -DS.s(2),
            child: Semantics(label: level.name, excludeSemantics: true, child: TrophyTile(level: level, size: LevelSizes.badge, round: true)),
          ),
        ],
      ),
    );
  }

  // Two lines are always reserved so the cards of one row keep the same height.
  Widget _reason() {
    final style = Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0);
    final lines = small ? 1 : 2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Art3D(asset: artOf(item.reason.kind), size: 16, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
        Gap.h(5),
        Flexible(
          child: Stack(
            children: [
              if (lines > 1) Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: Text(' \n ', maxLines: 2, style: style)),
              Text(reason, maxLines: lines, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: style),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = item.person;
    final hide = onHide;
    final body = Padding(
      padding: small ? DS.insets(l: 8, t: 12, r: 8, b: 10) : DS.insets(l: 10, t: 14, r: 10, b: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(),
          Gap.v(8),
          Text(p.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
          if (!small)
            Text(p.username ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
          Gap.v(6),
          _reason(),
          Gap.v(10),
          FollowButton(
            userId: p.userId,
            iFollow: item.iFollow,
            followRequested: item.followRequested,
            followsMe: item.followsMe,
            compact: true,
            api: api,
            onChanged: onFollowChanged,
          ),
        ],
      ),
    );
    return Container(
      key: keyOf(p.userId),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Stack(
        children: [
          Tap3D(onTap: () => SocialNav.openTraveller(p.userId), label: p.name, child: body),
          if (hide != null && !small)
            Positioned(
              top: 0,
              right: 0,
              child: Tap3D(
                tapKey: hideKeyOf(p.userId),
                onTap: hide,
                label: SocialStringsA.hideLabel(p.shortName),
                exclude: true,
                child: SizedBox(
                  width: DS.s(KitMetrics.touch),
                  height: DS.s(KitMetrics.touch),
                  child: Icon(Icons.close_rounded, size: DS.s(16), color: Form3D.hint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
