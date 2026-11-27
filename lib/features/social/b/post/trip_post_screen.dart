import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../trip/trip_navigation.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/follow_button.dart';
import '../../shared/widgets/mutuals_line.dart';
import '../../shared/widgets/travel_level_widgets.dart';
import '../models/join_gender_rule.dart';
import '../social_strings_b.dart';
import '../../a/widgets/social_chips_a.dart';
import '../widgets/social_widgets_b.dart';
import 'join_request_sheet.dart';
import 'trip_post_actions.dart';
import 'trip_post_controller.dart';

class TripPostScreen extends StatefulWidget {
  const TripPostScreen({super.key, required this.tripId});

  final String tripId;

  static const Key requestKey = ValueKey('trip_post_request');
  static const Key cancelKey = ValueKey('trip_post_cancel');
  static const Key menuKey = ValueKey('trip_post_menu');
  static const Key joinRequestsKey = ValueKey('trip_post_join_requests');
  static const Key openTripKey = ValueKey('trip_post_open_trip');
  static const Key onlyForKey = ValueKey('trip_post_only_for');
  static const Key ownerLevelKey = ValueKey('trip_post_owner_level');

  @override
  State<TripPostScreen> createState() => _TripPostScreenState();
}

class _TripPostScreenState extends State<TripPostScreen> {
  late final String _tag = 'trip-post-${widget.tripId}-${identityHashCode(this)}';
  late final TripPostController c = Get.put(TripPostController(tripId: widget.tripId), tag: _tag);

  @override
  void dispose() {
    Get.delete<TripPostController>(tag: _tag);
    super.dispose();
  }

  void _fail(BuddyResult<void> r) {
    if (!mounted) return;
    final text = switch (r) {
      BuddyRefused(:final message) => message ?? SocialStrings.failed,
      BuddyOffline() => SocialStrings.offline,
      _ => SocialStrings.failed,
    };
    BuddySnack.show(context, text, danger: true, bottom: _snackBottom);
  }

  static const double _barSnack = 104;

  double get _snackBottom {
    final t = c.trip.value;
    return c.state.value == TripPostLoad.ready && t != null && !t.sample ? _barSnack : 24;
  }

  Future<void> _request(PublicTrip t) async {
    final ok = await JoinRequestSheet.show(context, t);
    if (!ok || !mounted) return;
    c.markRequested();
    BuddySnack.show(context, SocialStringsB.requestSent, bottom: _snackBottom);
  }

  Future<void> _cancel() async {
    final r = await c.cancelRequest();
    if (!mounted) return;
    if (r.isOk) {
      BuddySnack.show(context, SocialStringsB.requestCancelled, bottom: _snackBottom);
    } else if (!(r is BuddyFailed<void> && r.message.isEmpty)) {
      _fail(r);
    }
  }

  Future<void> _menu(PublicTrip t) async {
    await TripPostActions.showMenu(
      context,
      trip: t,
      onBlocked: () {
        if (mounted) Navigator.of(context).maybePop();
      },
      own: [
        TripPostMenuItem(
          art: ListingArt.locked,
          title: SocialStringsB.removePost,
          subtitle: SocialStringsB.removePostLine,
          danger: true,
          onSelected: () async {
            final r = await c.unpublish();
            if (!mounted) return;
            if (r.isOk) {
              BuddySnack.show(context, SocialStringsB.postRemoved);
              Navigator.of(context).maybePop();
            } else {
              _fail(r);
            }
          },
        ),
      ],
    );
  }

  Widget _ownerCard(PublicTrip t) {
    final o = t.owner;
    final sub = SocialStringsB.placeLine(o, t.ownerInterests);
    final open = t.sample || o.userId.isEmpty ? null : () => SocialNav.openTraveller(o.userId);
    return Container(
      margin: DS.gapInsets(l: 18, t: 8, r: 18),
      padding: DS.insets(l: 16, t: 12, r: 12, b: 12),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Row(
        children: [
          Expanded(
            child: Tap3D(
              onTap: open,
              label: o.name,
              exclude: true,
              child: Row(
                children: [
                  BuddyAvatar(initial: o.initial, seed: o.userId.isEmpty ? o.name : o.userId, photoUrl: o.photoUrl),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                            if (o.gender.isNotEmpty) ...[Gap.h(6), GenderGlyph(gender: o.gender, color: GenderGlyph.inkOf(o.gender), size: 12, badge: true)],
                            if (!t.sample) ...[Gap.h(6), TrophyBadge(key: TripPostScreen.ownerLevelKey, level: o.level, trips: o.completedTrips)],
                          ],
                        ),
                        if ((o.username ?? '').isNotEmpty) Text(o.username!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
                        if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                        MutualsLine(mutuals: t.mutuals),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!t.isMine && !t.sample) ...[
            Gap.h(8),
            FollowButton(userId: o.userId, iFollow: t.iFollowOwner, followRequested: false, followsMe: false, compact: true, light: true, onChanged: (f, _) => c.trip.value = c.trip.value?.copyWith(iFollowOwner: f)),
          ],
        ],
      ),
    );
  }

  Widget _cover(PublicTrip t) {
    final seed = SocialLookB.seedOf(t.cityKey, t.tripId);
    final white = DesignColors.onPrimary;
    return Container(
      margin: DS.gapInsets(l: 18, t: 18, r: 18),
      height: DS.s(150),
      padding: DS.insets(l: 16, t: 14, r: 16, b: 12),
      decoration: BoxDecoration(gradient: SocialLookB.toneOf(seed).gradient, borderRadius: SocialLookB.heroRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SocialFormats.cities(t.cityNames), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                if ((t.stateName ?? '').isNotEmpty) Text(t.stateName!, maxLines: 1, style: Ink3D.text(13, FontWeight.w400, white.withValues(alpha: Alpha.v93), letterSpacing: 0)),
              ],
            ),
          ),
          TripCoverArt(cityKey: t.cityKey, seed: seed, size: 110),
        ],
      ),
    );
  }

  Widget _facts(PublicTrip t) {
    final rows = [
      (SocialStringsB.factWhen, SocialFormats.when(t.when)),
      (SocialStringsB.factHowLong, SocialFormats.days(t.days)),
      (SocialStringsB.factWho, SocialFormats.whoCanJoin(t.joinGender)),
      (SocialStringsB.factSeats, SocialStringsB.seatsFact(t.seatsLeft)),
    ];
    return Container(
      margin: DS.gapInsets(l: 18, t: 18, r: 18),
      padding: DS.insets(l: 18, r: 18, t: 4, b: 4),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.coverRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              constraints: BoxConstraints(minHeight: DS.s(52)),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Ink3D.line))),
              child: Row(
                children: [
                  Expanded(child: Text(rows[i].$1, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0))),
                  Text(rows[i].$2, style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _text(PublicTrip t) => Container(
        margin: DS.gapInsets(l: 18, t: 18, r: 18),
        padding: DS.all(18),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.coverRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
        child: Text(t.text, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.body, height: 1.5, letterSpacing: 0)),
      );

  Widget? _bar(PublicTrip t) {
    if (t.sample) return null;
    final teal = BuddyLook.teal;
    final Widget child;
    if (t.isMine) {
      final n = t.waitingRequests ?? 0;
      child = Row(
        children: [
          Expanded(
            child: GradientPillButton(
              key: TripPostScreen.joinRequestsKey,
              tone: teal,
              label: n > 0 ? '${SocialStringsB.joinRequestsTitle} · $n' : SocialStringsB.joinRequestsTitle,
              onTap: () => SocialNav.openJoinRequests(t.tripId),
            ),
          ),
          Gap.h(12),
          Expanded(
            child: WhitePillButton(key: TripPostScreen.openTripKey, tone: ListingTone.indigo, label: SocialStringsB.openTrip, onTap: () => TripNavigation.continueTrip(t.tripId)),
          ),
        ],
      );
    } else {
      child = switch (t.myJoin) {
        'requested' => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientPillButton(
                tone: ListingTone.indigo,
                icon: Icons.check_rounded,
                label: SocialStringsB.requested,
                enabled: false,
                onTap: null,
                offColor: BuddyLook.checkOff,
                offLabelColor: BuddyLook.subText,
              ),
              Tap3D(
                tapKey: TripPostScreen.cancelKey,
                onTap: c.busy.value ? null : _cancel,
                label: SocialStringsB.cancelRequest,
                exclude: true,
                child: Padding(
                  padding: DS.gapInsets(t: 14, b: 2),
                  child: Text(SocialStringsB.cancelRequest, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0)),
                ),
              ),
            ],
          ),
        'member' => WhitePillButton(tone: teal, label: SocialStringsB.openTrip, onTap: () => Get.toNamed(AppRoutes.tripView, arguments: {'tripId': t.tripId})),
        'declined' => GradientPillButton(tone: teal, label: SocialStringsB.notThisTime, enabled: false, onTap: null),
        _ when JoinGenderRule.blocks(t) => GradientPillButton(
            key: TripPostScreen.onlyForKey,
            tone: teal,
            icon: Icons.lock_rounded,
            label: SocialStringsB.onlyFor(t.joinGender),
            enabled: false,
            onTap: null,
            offColor: Form3D.fillOff,
            offLabelColor: BuddyLook.subText,
          ),
        _ => t.seatsLeft <= 0
            ? GradientPillButton(tone: teal, label: SocialStringsB.full, enabled: false, onTap: null)
            : GradientPillButton(key: TripPostScreen.requestKey, tone: teal, label: SocialStringsB.requestToJoin, onTap: () => _request(t)),
      };
    }
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(12), DS.s(18), DS.s(16) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: DesignColors.surface, boxShadow: DS.shadows(Ink3D.topEdge)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = c.trip.value;
      final st = c.state.value;
      c.busy.value;
      return BuddyPage(
        title: SocialStringsB.tripPost,
        subtitle: t == null ? null : SocialStringsB.byOwner(t.owner.shortName),
        trailing: [
          if (t != null && !t.sample)
            Semantics(
              label: SocialStringsB.moreOptions,
              button: true,
              excludeSemantics: true,
              child: KitRoundButton(key: TripPostScreen.menuKey, icon: Icons.more_vert_rounded, onTap: () => _menu(t)),
            ),
        ],
        bottomBar: t == null || st != TripPostLoad.ready ? null : _bar(t),
        body: switch (st) {
          TripPostLoad.loading => Padding(
              padding: DS.gapInsets(l: 18, t: 8, r: 18),
              child: Column(children: [SkeletonBox(height: DS.s(72), borderRadius: DS.circular(18)), Gap.v(18), SkeletonBox(height: DS.s(150), borderRadius: SocialLookB.heroRadius)]),
            ),
          TripPostLoad.gone => Padding(padding: DS.gapInsets(t: 40), child: StateCard(title: SocialStringsB.postGone, asset: ListingArt.panda)),
          TripPostLoad.offline => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          TripPostLoad.failed => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          TripPostLoad.ready => t == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ownerCard(t),
                    _cover(t),
                    _facts(t),
                    if (t.text.trim().isNotEmpty) _text(t),
                    const SafetyLine(text: SocialStrings.safetyMeet),
                    Gap.v(12),
                  ],
                ),
        },
      );
    });
  }
}
