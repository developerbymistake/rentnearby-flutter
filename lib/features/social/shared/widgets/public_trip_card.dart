import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../a/widgets/social_chips_a.dart';
import '../../b/social_strings_b.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../social_formats.dart';
import '../social_models.dart';
import 'follow_button.dart';
import 'travel_level_widgets.dart';

enum PublicTripCardMode { rail, feed, profile }

class PublicTripCard extends StatelessWidget {
  const PublicTripCard({super.key, required this.trip, this.onTap, this.mode = PublicTripCardMode.feed, this.footer, this.onMenu});

  final PublicTrip trip;
  final VoidCallback? onTap;
  final PublicTripCardMode mode;
  final Widget? footer;
  final VoidCallback? onMenu;

  static const Key menuKey = ValueKey('public_trip_menu');
  static const Key fullKey = ValueKey('public_trip_full');
  static const Key travelKey = ValueKey('public_trip_travel');
  static const Key levelKey = ValueKey('public_trip_owner_level');

  int get _seed => SocialLookB.seedOf(trip.cityKey, trip.tripId);

  String get _seatsText {
    if (trip.requestsFull && !trip.isMine) return SocialStringsB.full;
    return mode == PublicTripCardMode.feed ? SocialStringsB.seatsOf(trip) : SocialFormats.seatsLeft(trip.seatsLeft, trip.seats);
  }

  String get _place => SocialFormats.cities(trip.cityNames);

  String get _semantics => [
        _place,
        SocialStringsB.whenDays(trip),
        SocialFormats.whoCanJoin(trip.joinGender),
        _seatsText,
        ?SocialStringsB.travelLabel(trip.travelMode),
        trip.owner.name,
      ].join(', ');

  @override
  Widget build(BuildContext context) => mode == PublicTripCardMode.feed ? _feed() : _compact();

  Widget _cover({required double height, required double art, BorderRadius? radius, double titleSize = 19}) {
    final tone = SocialLookB.toneOf(_seed);
    final white = DesignColors.onPrimary;
    return Container(
      height: DS.s(height),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: radius),
      padding: DS.insets(l: 16, t: 14, r: 12, b: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_place, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(titleSize, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                Gap.v(2),
                Text(SocialStringsB.whenDays(trip), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, white.withValues(alpha: Alpha.v93), letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(8),
          TripCoverArt(cityKey: trip.cityKey, seed: _seed, size: art),
        ],
      ),
    );
  }

  Widget _pills() => Wrap(
        spacing: DS.gh(6),
        runSpacing: DS.gv(6),
        children: [
          InfoPill(text: SocialFormats.whoCanJoin(trip.joinGender)),
          InfoPill(key: trip.requestsFull && !trip.isMine ? fullKey : null, text: _seatsText, teal: true),
          if (trip.travelMode case final code?) TravelModeChip(key: travelKey, code: code),
        ],
      );

  Widget? _level({bool showCount = true}) =>
      trip.sample ? null : TrophyBadge(key: levelKey, level: trip.owner.level, trips: trip.owner.completedTrips, showCount: showCount);

  Widget _avatar(BuddyAvatarSize size) =>
      BuddyAvatar(initial: trip.owner.initial, seed: trip.owner.userId.isEmpty ? trip.owner.name : trip.owner.userId, size: size, photoUrl: trip.owner.photoUrl);

  Widget _compact() {
    final card = Container(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.tileRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cover(height: 118, art: 80),
          Padding(
            padding: DS.insets(l: 16, t: 12, r: 16, b: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _pills(),
                Gap.v(10),
                Row(
                  children: [
                    _avatar(BuddyAvatarSize.sm),
                    Gap.h(8),
                    Expanded(
                      child: Text(trip.owner.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w500, Ink3D.body, letterSpacing: 0)),
                    ),
                    if (_level() case final level?) ...[Gap.h(6), level],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Tap3D(onTap: onTap, label: _semantics, exclude: true, child: card);
  }

  Widget _ownerRow() {
    final owner = trip.owner;
    final sub = owner.homeCity ?? '';
    return Padding(
      padding: DS.insets(l: 14, t: 12, r: 6, b: 12),
      child: Row(
        children: [
          _avatar(BuddyAvatarSize.md),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(owner.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                    if (owner.gender.isNotEmpty) ...[Gap.h(6), GenderGlyph(gender: owner.gender, color: GenderGlyph.inkOf(owner.gender), size: 12, badge: true)],
                    if (_level() case final level?) ...[Gap.h(6), level],
                  ],
                ),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(8),
          if (trip.isMine)
            Padding(
              padding: DS.insets(r: 8),
              child: Container(
                padding: DS.sym(h: 10, v: 4),
                decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(12)),
                child: Text(SocialStringsB.yourPost, maxLines: 1, style: Ink3D.text(12, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
              ),
            )
          else if (!trip.sample)
            FollowButton(userId: owner.userId, iFollow: trip.iFollowOwner, followRequested: false, followsMe: false, compact: true, light: true),
          if (onMenu != null)
            Tap3D(
              key: menuKey,
              onTap: onMenu,
              label: SocialStringsB.moreOptions,
              exclude: true,
              child: SizedBox(
                width: DS.s(KitMetrics.touch),
                height: DS.s(KitMetrics.touch),
                child: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Form3D.hint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feed() {
    final body = Container(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.cardRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ownerRow(),
          Padding(
            padding: DS.insets(l: 14, r: 14),
            child: Tap3D(onTap: onTap, label: _semantics, exclude: true, child: _cover(height: 132, art: 90, radius: SocialLookB.coverRadius, titleSize: 20)),
          ),
          Padding(
            padding: DS.insets(l: 14, t: 10, r: 14, b: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _pills(),
                if (trip.text.trim().isNotEmpty) ...[
                  Gap.v(8),
                  Tap3D(
                    onTap: onTap,
                    exclude: true,
                    child: Text(trip.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.body, height: 1.5, letterSpacing: 0)),
                  ),
                ],
                if (footer != null) ...[Gap.v(12), footer!],
              ],
            ),
          ),
        ],
      ),
    );
    return body;
  }
}
