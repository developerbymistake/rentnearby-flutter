import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/widgets/public_trip_card.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.person,
    required this.gender,
    required this.trips,
    required this.followers,
    required this.following,
    this.displayName,
    this.photo,
    this.pill,
    this.after,
    this.onFollowers,
    this.onFollowing,
  });

  final SocialPerson person;
  final String gender;
  final int trips;
  final int followers;
  final int following;
  final String? displayName;
  final Widget? photo;
  final Widget? pill;
  final Widget? after;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  static final ListingTone tone = ListingTone.indigo;

  @override
  Widget build(BuildContext context) {
    final city = person.homeCity;
    final white = DesignColors.onPrimary;
    return Container(
      margin: DS.insets(l: 18, t: 2, r: 18, b: 6),
      padding: DS.insets(l: 20, t: 22, r: 20, b: 20),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.circular(32),
        boxShadow: [BoxShadow(color: tone.haloBase.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(0, 8)), blurRadius: DS.shadowBlur(20))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              photo ?? BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.lg, ring: true, photoUrl: person.photoUrl),
              Gap.h(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(displayName ?? person.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
                        ),
                        Gap.h(6),
                        GenderGlyph(gender: gender, badge: true, size: 14),
                      ],
                    ),
                    if ((person.username ?? '').isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: DS.s(2)),
                        child: Text(person.username!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, white.withValues(alpha: Alpha.v80), letterSpacing: 0.3)),
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: DS.s(6)),
                      child: Row(
                        children: [
                          if (city != null) ...[ExcludeSemantics(child: Art3D(asset: ListingArt.roundPushpin, size: 18, shadowBlur: 2, shadowOffset: const Offset(1, 2))), Gap.h(5)],
                          Flexible(
                            child: Text(city ?? SocialStringsA.traveller,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, white.withValues(alpha: Alpha.v90), letterSpacing: 0)),
                          ),
                        ],
                      ),
                    ),
                    ?pill,
                  ],
                ),
              ),
            ],
          ),
          Gap.v(16),
          ProfileCounters(trips: trips, followers: followers, following: following, onFollowers: onFollowers, onFollowing: onFollowing),
          ?after,
        ],
      ),
    );
  }
}

class ProfileCounters extends StatelessWidget {
  const ProfileCounters({super.key, required this.trips, required this.followers, required this.following, this.onFollowers, this.onFollowing});

  final int trips;
  final int followers;
  final int following;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  @override
  Widget build(BuildContext context) {
    Widget box(int n, String label, VoidCallback? onTap) {
      final body = Container(
        padding: DS.sym(h: 4, v: 8),
        decoration: BoxDecoration(
          color: DesignColors.onPrimary.withValues(alpha: Alpha.v18),
          borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(16), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
        ),
        child: Column(
          children: [
            Text('$n', maxLines: 1, style: Ink3D.text(18, FontWeight.w700, DesignColors.onPrimary, height: 1.2, letterSpacing: 0)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, DesignColors.onPrimary, letterSpacing: 0)),
          ],
        ),
      );
      return Expanded(child: onTap == null ? body : Tap3D(onTap: onTap, label: '$n $label', exclude: true, child: body));
    }

    return Row(
      children: [
        box(trips, SocialStringsA.trips, null),
        Gap.h(8),
        box(followers, SocialStringsA.followers, onFollowers),
        Gap.h(8),
        box(following, SocialStringsA.followingTab, onFollowing),
      ],
    );
  }
}

class ProfileChipsSection extends StatelessWidget {
  const ProfileChipsSection({super.key, required this.about, required this.interests, required this.places, required this.skills});

  final String about;
  final List<String> interests;
  final List<String> places;
  final List<String> skills;

  static Widget label(String text, {double top = 20}) => Padding(
        padding: EdgeInsets.only(top: DS.gv(top), bottom: DS.gv(10)),
        child: Text(text.toUpperCase(), style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
      );

  static Widget wrap(List<String> items, TagKind kind) => Wrap(
        spacing: DS.gh(8),
        runSpacing: DS.gv(8),
        children: [for (final t in items) TagChip(text: t, kind: kind)],
      );

  @override
  Widget build(BuildContext context) {
    if (about.trim().isEmpty && interests.isEmpty && places.isEmpty && skills.isEmpty) return const SizedBox.shrink();
    return WhiteCard3D(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: DS.insets(l: 20, t: 20, r: 20, b: 22),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (about.trim().isNotEmpty) ...[
            label(SocialStringsA.about, top: 0),
            Text(about, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.body, height: 1.55, letterSpacing: 0)),
          ],
          if (interests.isNotEmpty) ...[label(SocialStringsA.interests, top: about.trim().isEmpty ? 0 : 20), wrap(interests, TagKind.interest)],
          if (places.isNotEmpty) ...[label(SocialStringsA.placesVisited), wrap(places, TagKind.place)],
          if (skills.isNotEmpty) ...[label(SocialStringsA.skills), wrap(skills, TagKind.skill)],
        ],
        ),
      ),
    );
  }
}

class ProfileTripsSection extends StatelessWidget {
  const ProfileTripsSection({super.key, required this.title, required this.trips});

  final String title;
  final List<PublicTrip> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: DS.gapInsets(l: 22, t: 26, r: 22, b: 12),
          child: Text(title, style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.3)),
        ),
        for (final t in trips)
          Padding(
            padding: DS.gapInsets(l: 18, r: 18, b: 12),
            child: PublicTripCard(trip: t, mode: PublicTripCardMode.profile, onTap: () => SocialNav.openTripPost(t.tripId)),
          ),
      ],
    );
  }
}
