import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../trip/widgets/trip_city_art.dart';
import '../../b/social_strings_b.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../social_formats.dart';
import '../social_models.dart';
import 'travel_level_widgets.dart';

class PublicTripCard extends StatelessWidget {
  const PublicTripCard({super.key, required this.trip, this.onTap});

  final PublicTrip trip;
  final VoidCallback? onTap;

  static const Key fullKey = ValueKey('public_trip_full');
  static const Key travelKey = ValueKey('public_trip_travel');
  static const Key levelKey = ValueKey('public_trip_owner_level');
  static const Key photoKey = ValueKey('public_trip_city_photo');

  int get _seed => SocialLookB.seedOf(trip.cityKey, trip.tripId);

  String get _seatsText => trip.requestsFull && !trip.isMine ? SocialStringsB.full : SocialFormats.seatsLeft(trip.seatsLeft, trip.seats);

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
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.tileRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CityCover(cityKey: trip.cityKey, builder: _cover),
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
                    BuddyAvatar(initial: trip.owner.initial, seed: trip.owner.userId.isEmpty ? trip.owner.name : trip.owner.userId, size: BuddyAvatarSize.sm, photoUrl: trip.owner.photoUrl),
                    Gap.h(8),
                    Expanded(
                      child: Text(trip.owner.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w500, Ink3D.body, letterSpacing: 0)),
                    ),
                    if (!trip.sample) ...[Gap.h(6), TrophyBadge(key: levelKey, level: trip.owner.level, trips: trip.owner.completedTrips)],
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

  static const double _height = 118;
  static const double _art = 80;

  Widget _cover(String? photo) {
    final tone = SocialLookB.toneOf(_seed);
    final white = DesignColors.onPrimary;
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_place, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
        Gap.v(2),
        Text(SocialStringsB.whenDays(trip), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, white.withValues(alpha: Alpha.v93), letterSpacing: 0)),
      ],
    );
    final pad = DS.insets(l: 16, t: 14, r: 12, b: 10);
    if (photo != null) {
      return SizedBox(
        key: photoKey,
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
            Padding(padding: pad, child: titles),
          ],
        ),
      );
    }
    return Container(
      height: DS.s(_height),
      decoration: BoxDecoration(gradient: tone.gradient),
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titles),
          Gap.h(8),
          TripCoverArt(cityKey: trip.cityKey, seed: _seed, size: _art),
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
}
