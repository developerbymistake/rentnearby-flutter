import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/widgets/note_banner.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/follow_button.dart';
import '../../shared/widgets/mutuals_line.dart';
import '../../shared/widgets/person_actions.dart';
import '../social_strings_a.dart';
import 'profile_sections.dart';
import 'traveller_profile_controller.dart';

class TravellerProfileScreen extends StatefulWidget {
  const TravellerProfileScreen({super.key, required this.userId});

  final String userId;

  static const Key messageKey = ValueKey('traveller_message');
  static const Key buddyKey = ValueKey('traveller_buddy');
  static const Key menuKey = ValueKey('traveller_menu');

  @override
  State<TravellerProfileScreen> createState() => _TravellerProfileScreenState();
}

class _TravellerProfileScreenState extends State<TravellerProfileScreen> {
  late final String _tag = 'traveller-${widget.userId}-${identityHashCode(this)}';
  late final TravellerProfileController c = Get.put(TravellerProfileController(userId: widget.userId), tag: _tag);

  @override
  void dispose() {
    Get.delete<TravellerProfileController>(tag: _tag);
    super.dispose();
  }

  Future<void> _menu() async {
    final p = c.profile.value;
    if (p == null) return;
    await PersonActions.showMenu(context, person: p.person, contextName: BuddyContext.profile, onBlocked: () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _buddy() async {
    final msg = await c.toggleBuddy();
    if (msg != null && mounted) BuddySnack.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = c.profile.value;
      final st = c.state.value;
      return BuddyPage(
        title: p?.person.shortName ?? '',
        trailing: [
          if (p != null)
            Semantics(
              label: '${SocialStrings.report} / ${SocialStrings.block}',
              button: true,
              excludeSemantics: true,
              child: KitRoundButton(key: TravellerProfileScreen.menuKey, icon: Icons.more_vert_rounded, onTap: _menu),
            ),
        ],
        body: switch (st) {
          TravellerLoad.loading => Padding(
              padding: DS.gapInsets(l: 18, t: 8, r: 18),
              child: Column(children: [SkeletonBox(height: DS.s(200), borderRadius: DS.circular(32)), Gap.v(22), SkeletonBox(height: DS.s(50), borderRadius: DS.circular(25))]),
            ),
          TravellerLoad.gone => Padding(padding: DS.gapInsets(t: 40), child: StateCard(title: SocialStringsA.travellerGone, asset: ListingArt.panda)),
          TravellerLoad.offline => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          TravellerLoad.failed => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          TravellerLoad.ready => p == null ? const SizedBox.shrink() : _content(p),
        },
      );
    });
  }

  Widget _pill(TravellerProfile p) {
    final String? text;
    var gold = false;
    if (p.isBuddy) {
      text = SocialStrings.buddy;
      gold = true;
    } else if (p.followsMe && p.iFollow) {
      text = SocialStrings.followEachOther;
    } else if (p.followsMe) {
      text = SocialStrings.followsYou;
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    final ink = gold ? BuddyLook.amberText : DesignColors.onPrimary;
    final label = Text(text, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, ink, letterSpacing: 0));
    return Padding(
      padding: EdgeInsets.only(top: DS.s(8)),
      child: Container(
        padding: DS.sym(h: 11, v: 3),
        decoration: BoxDecoration(
          color: gold ? BuddyLook.snackAction : DesignColors.onPrimary.withValues(alpha: Alpha.v22),
          borderRadius: DS.circular(12),
        ),
        child: gold
            ? Row(mainAxisSize: MainAxisSize.min, children: [ExcludeSemantics(child: Icon(Icons.star_rounded, size: DS.s(13), color: ink)), Gap.h(4), Flexible(child: label)])
            : label,
      ),
    );
  }

  Widget _actions(TravellerProfile p) {
    final message = WhitePillButton(
      key: TravellerProfileScreen.messageKey,
      tone: ListingTone.indigo,
      label: SocialStrings.message,
      onTap: () => SocialNav.openDirectChat(userId: p.person.userId, name: p.person.name, photoUrl: p.person.photoUrl),
    );
    final follow = FollowButton(
      userId: p.person.userId,
      iFollow: p.iFollow,
      followRequested: p.followRequested,
      followsMe: p.followsMe,
      onChanged: c.onFollowChanged,
    );
    final rows = <Widget>[];
    if (p.followsMe) {
      final star = p.isBuddy
          ? WhitePillButton(key: TravellerProfileScreen.buddyKey, tone: ListingTone.sunrise, icon: Icons.star_rounded, label: SocialStrings.buddy, onTap: _buddy)
          : GradientPillButton(key: TravellerProfileScreen.buddyKey, tone: BuddyLook.teal, icon: Icons.star_rounded, label: SocialStrings.addToBuddies, onTap: _buddy);
      rows.add(Row(children: [Expanded(flex: p.isBuddy ? 1 : 3, child: message), Gap.h(12), Expanded(flex: p.isBuddy ? 1 : 5, child: star)]));
      if (!p.iFollow) rows.addAll([Gap.v(12), follow]);
    } else {
      rows.add(Row(children: [Expanded(flex: 13, child: follow), Gap.h(12), Expanded(flex: 10, child: message)]));
    }
    return Padding(padding: DS.gapInsets(l: 18, t: 22, r: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows));
  }

  Widget _content(TravellerProfile p) {
    final mutuals = p.mutuals.isEmpty
        ? null
        : Padding(padding: EdgeInsets.only(top: DS.gv(14)), child: MutualsLine(mutuals: p.mutuals, avatars: true, color: DesignColors.onPrimary));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeroCard(
            person: p.person,
            displayName: p.person.shortName,
            gender: p.gender,
            trips: p.trips,
            followers: p.followers,
            following: p.following,
            pill: _pill(p),
            after: mutuals,
          ),
          _actions(p),
          if (p.privateLocked)
            NoteBanner(art: BuddyArt.locked, text: '${SocialStringsA.privateTitle}. ${SocialStringsA.privateLine}')
          else ...[
            Gap.v(24),
            ProfileChipsSection(about: p.about, interests: p.interests, places: p.places, skills: p.skills),
            ProfileTripsSection(title: SocialStringsA.publicTrips(p.publicTrips.length), trips: p.publicTrips),
          ],
          Gap.v(24),
        ],
    );
  }
}
