import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../trip/widgets/trip_city_art.dart';
import '../../a/widgets/social_chips_a.dart';
import '../../b/models/join_gender_rule.dart';
import '../../b/post/join_request_sheet.dart';
import '../../b/post/own_post_menu.dart';
import '../../b/social_strings_b.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../social_formats.dart';
import '../social_models.dart';
import '../social_nav.dart';
import '../travel_levels.dart';
import 'follow_button.dart';
import 'travel_level_widgets.dart';

enum TripCardAction { join, requested, requests, noRequests, openTrip, declined, removed, onlyFor, full, none }

class TripJoinCard extends StatelessWidget {
  const TripJoinCard({super.key, required this.trip, this.showOwner = true, this.onRequested, this.onStale, this.onFollowChanged, this.onBack});

  final PublicTrip trip;
  final bool showOwner;
  final ValueChanged<String>? onRequested;
  final void Function(String tripId, String? type)? onStale;
  final void Function(String ownerId, bool iFollow)? onFollowChanged;
  final VoidCallback? onBack;

  static Key cardKey(String tripId) => ValueKey('trip_card_$tripId');
  static Key actionKey(String tripId) => ValueKey('trip_card_action_$tripId');
  static const Key fullKey = ValueKey('trip_card_full');
  static const Key levelKey = ValueKey('trip_card_level');
  static const Key followKey = ValueKey('trip_card_follow');
  static const Key photoKey = ValueKey('trip_card_city_photo');
  static const Key menuKey = ValueKey('trip_card_menu');

  static TripCardAction actionOf(PublicTrip t) {
    if (t.sample) return TripCardAction.none;
    if (t.isMine) return (t.waitingRequests ?? 0) > 0 ? TripCardAction.requests : TripCardAction.noRequests;
    switch (t.myJoin) {
      case 'requested':
        return TripCardAction.requested;
      case 'member':
        return TripCardAction.openTrip;
      case 'declined':
        return TripCardAction.declined;
      case 'removed':
        return TripCardAction.removed;
    }
    if (JoinGenderRule.blocks(t)) return TripCardAction.onlyFor;
    if (t.fullForOthers) return TripCardAction.full;
    return TripCardAction.join;
  }

  String get _id => trip.tripId;

  String get _seatsText => trip.requestsFull && !trip.isMine ? SocialStringsB.full : SocialStringsB.seatsOf(trip);

  String get _semantics => [
        SocialFormats.cities(trip.cityNames),
        SocialStringsB.whenDays(trip),
        SocialFormats.whoCanJoin(trip.joinGender),
        _seatsText,
        if (showOwner) trip.isMine ? SocialStringsB.you : trip.owner.name,
      ].join(', ');

  Future<void> _back(Future<dynamic>? route) async {
    await route;
    onBack?.call();
  }

  Future<void> _join(BuildContext context) async {
    final ok = await JoinRequestSheet.show(context, trip, onStale: (type) => onStale?.call(_id, type));
    if (!ok) return;
    onRequested?.call(_id);
    if (context.mounted) BuddySnack.show(context, SocialStringsB.requestSent);
  }

  Widget _off(String label, {IconData? icon}) => GradientPillButton(
        key: actionKey(_id),
        tone: BuddyLook.teal,
        icon: icon,
        label: label,
        enabled: false,
        onTap: null,
        expand: false,
        offColor: Form3D.fillOff,
        offLabelColor: BuddyLook.subText,
        height: SocialButtonsA.midHeight,
        fontSize: SocialButtonsA.midFont,
      );

  Widget? _action(BuildContext context) {
    const h = SocialButtonsA.midHeight;
    const f = SocialButtonsA.midFont;
    return switch (actionOf(trip)) {
      TripCardAction.join => GradientPillButton(
          key: actionKey(_id),
          tone: ListingTone.coral,
          label: SocialStringsB.join,
          expand: false,
          height: h,
          fontSize: f,
          onTap: () => _join(context),
        ),
      TripCardAction.requested => WhitePillButton(
          key: actionKey(_id),
          tone: ListingTone.indigo,
          neutral: true,
          icon: Icons.check_rounded,
          label: SocialStringsB.requested,
          expand: false,
          height: h,
          fontSize: f,
          onTap: () => SocialNav.openTripPost(_id),
        ),
      TripCardAction.requests => GradientPillButton(
          key: actionKey(_id),
          tone: BuddyLook.teal,
          label: SocialStringsB.requests(trip.waitingRequests ?? 0),
          expand: false,
          height: h,
          fontSize: f,
          onTap: () => _back(SocialNav.openJoinRequests(_id)),
        ),
      TripCardAction.noRequests => _off(SocialStringsB.noRequests),
      TripCardAction.openTrip => WhitePillButton(
          key: actionKey(_id),
          tone: BuddyLook.teal,
          label: SocialStringsB.openTrip,
          expand: false,
          height: h,
          fontSize: f,
          onTap: () => Get.toNamed(AppRoutes.tripView, arguments: {'tripId': _id}),
        ),
      TripCardAction.declined => _off(SocialStringsB.notThisTime),
      TripCardAction.removed => _off(SocialStringsB.cannotJoin),
      TripCardAction.onlyFor => _off(SocialFormats.whoCanJoin(trip.joinGender), icon: Icons.lock_rounded),
      TripCardAction.full => _off(SocialStringsB.full),
      TripCardAction.none => null,
    };
  }

  Widget _owner() {
    final o = trip.owner;
    final name = trip.isMine ? SocialStringsB.you : o.shortName;
    final follow = _follow();
    return Row(
      children: [
        BuddyAvatar(initial: o.initial, seed: o.userId.isEmpty ? o.name : o.userId, size: BuddyAvatarSize.sm, photoUrl: o.photoUrl),
        Gap.h(8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w500, Ink3D.body, letterSpacing: 0)),
              if (!trip.sample)
                Row(
                  key: levelKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TrophyTile(level: TravelLevels.at(o.level), size: LevelSizes.badge, round: true),
                    Gap.h(4),
                    Flexible(child: Text(SocialStringsB.levelN(o.level), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Ink3D.grey, letterSpacing: 0))),
                  ],
                ),
            ],
          ),
        ),
        if (follow != null) ...[Gap.h(8), follow],
      ],
    );
  }

  Widget? _follow() {
    if (!showOwner || trip.isMine || trip.sample) return null;
    final id = trip.owner.userId;
    return FollowButton(
      key: followKey,
      userId: id,
      iFollow: trip.iFollowOwner,
      followRequested: false,
      followsMe: false,
      compact: true,
      light: true,
      onChanged: (f, _) => onFollowChanged?.call(id, f),
    );
  }

  Widget? _menu(BuildContext context) {
    if (!trip.isMine || trip.sample) return null;
    return Semantics(
      label: SocialStringsB.moreOptions,
      button: true,
      excludeSemantics: true,
      child: KitRoundButton(key: menuKey, icon: Icons.more_vert_rounded, onTap: () => OwnPostMenu.show(context, trip: trip, onChanged: onBack, onDeleted: onBack)),
    );
  }

  Widget _fact(String art, String text, {bool shrink = true}) {
    final label = Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Ink3D.sub, letterSpacing: 0));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Art3D(asset: art, size: 18, shadowBlur: 1, shadowOffset: const Offset(0.5, 1))),
        Gap.h(4),
        shrink ? Flexible(child: label) : label,
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final action = _action(context);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _fact(ListingArt.luggage, SocialFormats.days(trip.days), shrink: false),
              Gap.h(10),
              Flexible(child: _fact(ListingArt.shield, SocialFormats.whoCanJoin(trip.joinGender))),
            ],
          ),
        ),
        if (action != null) ...[Gap.h(8), action],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = trip.text.trim();
    final card = Container(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.tileRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _JoinCardCover(trip: trip, seats: _seatsText, trailing: _menu(context)),
          Padding(
            padding: DS.insets(l: 14, t: 10, r: 14, b: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showOwner) ...[_owner(), Gap.v(12)],
                if (text.isNotEmpty) ...[
                  Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.body, height: 1.5, letterSpacing: 0)),
                  Gap.v(10),
                ],
                _footer(context),
              ],
            ),
          ),
        ],
      ),
    );
    return Tap3D(key: cardKey(_id), onTap: () => _back(SocialNav.openTripPost(_id)), label: _semantics, child: card);
  }
}

class _JoinCardCover extends StatelessWidget {
  const _JoinCardCover({required this.trip, required this.seats, this.trailing});

  final PublicTrip trip;
  final String seats;
  final Widget? trailing;

  static const double _height = 118;
  static const double _art = 84;
  static const double _halo = 124;

  @override
  Widget build(BuildContext context) => CityCover(cityKey: trip.cityKey, builder: _box);

  Widget _box(String? photo) {
    final seed = SocialLookB.seedOf(trip.cityKey, trip.tripId);
    final white = DesignColors.onPrimary;
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(SocialFormats.cities(trip.cityNames), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
        Gap.v(2),
        Text(SocialFormats.when(trip.when), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, white.withValues(alpha: Alpha.v93), letterSpacing: 0)),
      ],
    );
    final pill = Container(
      key: trip.requestsFull && !trip.isMine ? TripJoinCard.fullKey : null,
      padding: DS.sym(h: 9, v: 3),
      decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), borderRadius: DS.circular(10)),
      child: Text(seats, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, white, letterSpacing: 0)),
    );
    final content = Padding(
      padding: DS.insets(l: 14, t: 12, r: 12, b: 10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: trailing == null && photo == null ? DS.s(_art / 2) : 0),
                  child: titles,
                ),
              ),
              if (trailing != null) ...[Gap.h(12), trailing!],
            ],
          ),
          Positioned(left: 0, bottom: 0, child: pill),
        ],
      ),
    );
    if (photo != null) {
      return SizedBox(
        key: TripJoinCard.photoKey,
        height: DS.s(_height),
        child: Stack(
          fit: StackFit.expand,
          children: [
            KitPhoto(url: photo, width: double.infinity, height: DS.s(_height), tone: TripCityArt.toneOf(trip.cityKey), asset: TravelIcon.map, iconSize: 40),
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
      );
    }
    return Container(
      height: DS.s(_height),
      decoration: BoxDecoration(gradient: SocialLookB.toneOf(seed).gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -DS.s(12),
            bottom: -DS.s(44),
            child: Container(width: DS.s(_halo), height: DS.s(_halo), decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v16))),
          ),
          Positioned(right: DS.s(10), bottom: -DS.s(16), child: TripCoverArt(cityKey: trip.cityKey, seed: seed, size: _art)),
          content,
        ],
      ),
    );
  }
}
