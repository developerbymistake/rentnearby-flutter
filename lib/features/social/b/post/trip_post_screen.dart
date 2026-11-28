import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_confirm_box.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../trip/trip_navigation.dart';
import '../../../trip/widgets/trip_city_art.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_live.dart';
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
import 'own_post_menu.dart';
import 'trip_post_actions.dart';
import 'trip_post_controller.dart';

class TripPostScreen extends StatefulWidget {
  const TripPostScreen({super.key, required this.tripId});

  final String tripId;

  static const Key requestKey = ValueKey('trip_post_request');
  static const Key cancelKey = ValueKey('trip_post_cancel');
  static const Key menuKey = ValueKey('trip_post_menu');
  static const Key travelKey = ValueKey('trip_post_travel');
  static const Key joinRequestsKey = ValueKey('trip_post_join_requests');
  static const Key openTripKey = ValueKey('trip_post_open_trip');
  static const Key onlyForKey = ValueKey('trip_post_only_for');
  static const Key fullKey = ValueKey('trip_post_full');
  static const Key removedKey = ValueKey('trip_post_removed');
  static const Key ownerNoteKey = ValueKey('trip_post_owner_note');
  static const Key ownerLevelKey = ValueKey('trip_post_owner_level');
  static const Key coverKey = ValueKey('trip_post_cover');
  static const Key backKey = ValueKey('trip_post_back');
  static const Key ownerStatusKey = ValueKey('trip_post_owner_status');

  @override
  State<TripPostScreen> createState() => _TripPostScreenState();
}

class _TripPostScreenState extends State<TripPostScreen> {
  late final String _tag = 'trip-post-${widget.tripId}-${identityHashCode(this)}';
  late final TripPostController c = Get.put(TripPostController(tripId: widget.tripId), tag: _tag);

  bool _blocked = false;

  @override
  void dispose() {
    Get.delete<TripPostController>(tag: _tag);
    if (_blocked) scheduleMicrotask(() => SocialLive.posts.value++);
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
    final ok = await JoinRequestSheet.show(context, t, onStale: c.applyRefusal);
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
    if (t.isMine) {
      await OwnPostMenu.show(
        context,
        trip: t,
        onDeleted: () {
          Get.delete<TripPostController>(tag: _tag);
          if (mounted) Navigator.of(context).maybePop();
        },
      );
      return;
    }
    await TripPostActions.showMenu(
      context,
      trip: t,
      onBlocked: () async {
        _blocked = true;
        if (mounted && await Navigator.of(context).maybePop()) return;
        _blocked = false;
        SocialLive.posts.value++;
      },
    );
  }

  Future<void> _planTrip(PublicTrip t) async {
    final ok = await BuddyConfirmBox.ask(
      context,
      art: ListingArt.worldMap,
      title: SocialStringsB.planTripTitle,
      body: SocialStringsB.planTripBody,
      confirmLabel: SocialStringsB.planTrip,
    );
    if (!ok || !mounted) return;
    await TripNavigation.continueTrip(t.tripId);
  }

  Widget _ownerCard(PublicTrip t) {
    final o = t.owner;
    final sub = SocialStringsB.placeLine(o, t.ownerInterests);
    final open = t.sample || o.userId.isEmpty ? null : () => SocialNav.openTraveller(o.userId);
    final status = t.isMine && !t.sample ? SocialStringsB.ownerStatus(t.members ?? 0, t.waitingRequests ?? 0) : '';
    final row = Row(
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
    );
    return Container(
      margin: DS.gapInsets(l: 18, t: 16, r: 18),
      padding: DS.insets(l: 16, t: 12, r: 12, b: 12),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
      child: status.isEmpty
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                row,
                Padding(
                  key: TripPostScreen.ownerStatusKey,
                  padding: DS.gapInsets(t: 8),
                  child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
                ),
              ],
            ),
    );
  }

  static const String _seatsArt = 'assets/images/design/travel3d/automobile.png';
  static const double _coverHeight = 190;
  static const double _coverArt = 110;
  static const double _coverHalo = 164;

  Widget _coverHeader(PublicTrip t) => CityCover(cityKey: t.cityKey, builder: (photo) => _coverBox(t, photo));

  Widget _coverBox(PublicTrip t, String? photo) {
    final seed = SocialLookB.seedOf(t.cityKey, t.tripId);
    final white = DesignColors.onPrimary;
    final top = MediaQuery.paddingOf(context).top;
    final height = DS.s(_coverHeight) + top;
    final line = [if ((t.stateName ?? '').isNotEmpty) t.stateName!, SocialFormats.when(t.when)].join(' · ');
    final content = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(16), top + DS.s(10), DS.s(12), DS.s(12)),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (photo == null) ...[
            Positioned(
              right: -DS.s(24),
              bottom: -DS.s(34),
              child: Container(width: DS.s(_coverHalo), height: DS.s(_coverHalo), decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v16))),
            ),
            Positioned(right: 0, bottom: 0, child: TripCoverArt(cityKey: t.cityKey, seed: seed, size: _coverArt)),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Tap3D(
                    key: TripPostScreen.backKey,
                    onTap: () => Navigator.of(context).maybePop(),
                    label: SocialStringsB.back,
                    exclude: true,
                    child: Container(
                      width: DS.s(44),
                      height: DS.s(44),
                      decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), shape: BoxShape.circle),
                      child: Icon(Icons.chevron_left_rounded, size: DS.s(28), color: white),
                    ),
                  ),
                  const Spacer(),
                  if (!t.sample)
                    Semantics(
                      label: SocialStringsB.moreOptions,
                      button: true,
                      excludeSemantics: true,
                      child: KitRoundButton(key: TripPostScreen.menuKey, icon: Icons.more_vert_rounded, onTap: () => _menu(t)),
                    ),
                ],
              ),
              Gap.v(10),
              Padding(
                padding: EdgeInsets.only(right: photo == null ? DS.s(_coverArt - 14) : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(SocialFormats.cities(t.cityNames), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, white.withValues(alpha: Alpha.v93), letterSpacing: 0)),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              padding: DS.sym(h: 10, v: 4),
              decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(10)),
              child: Text(t.requestsFull && !t.isMine ? SocialStringsB.full : SocialStringsB.seatsOf(t), maxLines: 1, style: Ink3D.text(12, FontWeight.w600, white, letterSpacing: 0)),
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      key: TripPostScreen.coverKey,
      borderRadius: DS.br(CardRadius.header),
      child: SizedBox(
        height: height,
        child: photo == null
            ? DecoratedBox(decoration: BoxDecoration(gradient: SocialLookB.toneOf(seed).gradient), child: content)
            : Stack(
                fit: StackFit.expand,
                children: [
                  KitPhoto(url: photo, width: double.infinity, height: height, tone: TripCityArt.toneOf(t.cityKey), asset: TravelIcon.map, iconSize: 40),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: Alpha.v55), Colors.black.withValues(alpha: Alpha.v10)],
                      ),
                    ),
                  ),
                  content,
                ],
              ),
      ),
    );
  }

  Widget _fact(String art, String label, String value, {Key? key}) => Row(
        key: key,
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 26, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
          Gap.h(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              ],
            ),
          ),
        ],
      );

  Widget _facts(PublicTrip t) {
    final travelArt = SocialLookB.travelArtOf(t.travelMode);
    final travelLabel = SocialStringsB.travelLabel(t.travelMode);
    final facts = <Widget>[
      _fact(ListingArt.calendar, SocialStringsB.factWhen, SocialFormats.when(t.when)),
      _fact(ListingArt.luggage, SocialStringsB.factHowLong, SocialFormats.days(t.days)),
      _fact(ListingArt.shield, SocialStringsB.factWho, SocialFormats.whoCanJoin(t.joinGender)),
      _fact(_seatsArt, SocialStringsB.factSeats, t.requestsFull && !t.isMine ? SocialStringsB.full : SocialStringsB.seatsFact(t.seatsLeft)),
      if (travelArt != null && travelLabel != null) _fact(travelArt, SocialStringsB.factTravelBy, travelLabel, key: TripPostScreen.travelKey),
    ];
    return Container(
      margin: DS.gapInsets(l: 18, t: 14, r: 18),
      padding: DS.all(16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.coverRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i += 2) ...[
            if (i > 0) Gap.v(14),
            Row(
              children: [
                Expanded(child: facts[i]),
                Gap.h(12),
                Expanded(child: i + 1 < facts.length ? facts[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _ownerNote(PublicTrip t) {
    if (!t.isMine) return null;
    if (t.requestsFull) return SocialStringsB.requestsFullOwner(t.waitingRequests ?? PublicTrip.requestsCap);
    if (t.nearbyPending) return SocialStringsB.nearbyTomorrow;
    return null;
  }

  Widget _text(PublicTrip t) => Container(
        margin: DS.gapInsets(l: 18, t: 14, r: 18),
        padding: DS.all(16),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.coverRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SocialStringsB.aboutThisTrip, style: Ink3D.text(14.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
            Gap.v(6),
            Text(t.text, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.body, height: 1.5, letterSpacing: 0)),
          ],
        ),
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
            child: WhitePillButton(key: TripPostScreen.openTripKey, tone: ListingTone.indigo, label: SocialStringsB.planTrip, onTap: () => _planTrip(t)),
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
        'removed' => GradientPillButton(
            key: TripPostScreen.removedKey,
            tone: teal,
            label: SocialStringsB.cannotRejoin,
            enabled: false,
            onTap: null,
            offColor: Form3D.fillOff,
            offLabelColor: BuddyLook.subText,
          ),
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
        _ => t.fullForOthers
            ? GradientPillButton(key: TripPostScreen.fullKey, tone: teal, label: SocialStringsB.fullLabel(t.seatsLeft), enabled: false, onTap: null)
            : GradientPillButton(key: TripPostScreen.requestKey, tone: ListingTone.coral, label: SocialStringsB.requestToJoin, onTap: () => _request(t)),
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
        header: st == TripPostLoad.ready && t != null ? _coverHeader(t) : null,
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
                    _facts(t),
                    if (t.text.trim().isNotEmpty) _text(t),
                    if (_ownerNote(t) case final note?) Padding(key: TripPostScreen.ownerNoteKey, padding: DS.gapInsets(l: 22, t: 14, r: 22), child: Text(note, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, height: 1.45, letterSpacing: 0))),
                    const SafetyLine(text: SocialStrings.safetyMeet),
                    Gap.v(12),
                  ],
                ),
        },
      );
    });
  }
}
