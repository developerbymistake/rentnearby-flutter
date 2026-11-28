import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../shared/social_models.dart';
import '../../shared/social_error_types.dart';
import '../../shared/widgets/trip_join_card.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import '../widgets/social_section_card.dart';

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.person,
    required this.gender,
    required this.trips,
    required this.followers,
    required this.following,
    this.displayName,
    this.about = '',
    this.photo,
    this.pill,
    this.after,
    this.trailing,
    this.onFollowers,
    this.onFollowing,
  });

  final SocialPerson person;
  final String gender;
  final int trips;
  final int followers;
  final int following;
  final String? displayName;
  final String about;
  final Widget? photo;
  final Widget? pill;
  final Widget? after;
  final Widget? trailing;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  static final ListingTone tone = ListingTone.indigo;
  static const Key aboutKey = ValueKey('profile_hero_about');

  @override
  Widget build(BuildContext context) {
    final city = person.homeCity;
    final white = DesignColors.onPrimary;
    return Container(
      margin: DS.insets(l: 18, t: 2, r: 18, b: 6),
      padding: DS.insets(l: 20, t: 22, r: 20, b: 20),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.br(CardRadius.hero),
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
              if (trailing != null) ...[Gap.h(10), trailing!],
            ],
          ),
          if (about.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(14)),
              child: Text(about.trim(), key: aboutKey, style: Ink3D.text(14.5, FontWeight.w400, white.withValues(alpha: Alpha.v92), height: 1.55, letterSpacing: 0)),
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
    Widget box(int n, String label, Color ink, VoidCallback? onTap) {
      final body = Container(
        padding: DS.sym(h: 4, v: 8),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(CardRadius.card),
          boxShadow: [BoxShadow(color: ProfileStatColors.tileShadow.withValues(alpha: Alpha.v22), offset: DS.shadowOffset(LevelSizes.statShadowOffset))],
        ),
        child: Column(
          children: [
            Text('$n', maxLines: 1, style: Ink3D.text(18, FontWeight.w700, ink, height: 1.2, letterSpacing: 0)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, ProfileStatColors.label, letterSpacing: 0)),
          ],
        ),
      );
      return Expanded(child: onTap == null ? body : Tap3D(onTap: onTap, label: '$n $label', exclude: true, child: body));
    }

    return Row(
      children: [
        box(trips, SocialStringsA.trips, ProfileStatColors.trips, null),
        Gap.h(8),
        box(followers, SocialStringsA.followers, ProfileStatColors.followers, onFollowers),
        Gap.h(8),
        box(following, SocialStringsA.followingTab, ProfileStatColors.following, onFollowing),
      ],
    );
  }
}

class ProfileChipsSection extends StatelessWidget {
  const ProfileChipsSection({super.key, required this.interests, required this.places, required this.skills});

  final List<String> interests;
  final List<String> places;
  final List<String> skills;

  static const Key interestsKey = ValueKey('profile_interests_card');
  static const Key placesKey = ValueKey('profile_places_card');
  static const Key skillsKey = ValueKey('profile_skills_card');

  static Widget wrap(List<String> items, TagKind kind, {String Function(String)? art}) => Wrap(
        spacing: DS.gh(8),
        runSpacing: DS.gv(8),
        children: [for (final t in items) TagChip(text: t, kind: kind, art: art?.call(t))],
      );

  static Widget count(int n) => Text('· $n', style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0));

  static String _pin(String _) => ListingArt.roundPushpin;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (interests.isNotEmpty)
        SocialSectionCard(key: interestsKey, art: ListingArt.mountain, title: SocialStringsA.interests, hint: count(interests.length), child: wrap(interests, TagKind.interest, art: SocialArtA.interest)),
      if (places.isNotEmpty)
        SocialSectionCard(key: placesKey, art: ListingArt.roundPushpin, title: SocialStringsA.placesVisited, hint: count(places.length), child: wrap(places, TagKind.place, art: _pin)),
      if (skills.isNotEmpty)
        SocialSectionCard(key: skillsKey, art: ListingArt.camera, title: SocialStringsA.skills, hint: count(skills.length), child: wrap(skills, TagKind.skill, art: SocialArtA.skill)),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
  }
}

class ProfileTripsSection extends StatefulWidget {
  const ProfileTripsSection({super.key, required this.title, required this.trips, this.onBack});

  final String title;
  final List<PublicTrip> trips;
  final VoidCallback? onBack;

  @override
  State<ProfileTripsSection> createState() => _ProfileTripsSectionState();
}

class _ProfileTripsSectionState extends State<ProfileTripsSection> {
  late List<PublicTrip> _trips = List.of(widget.trips);

  @override
  void didUpdateWidget(ProfileTripsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.trips, widget.trips)) _trips = List.of(widget.trips);
  }

  void _update(String tripId, PublicTrip Function(PublicTrip) change) {
    final i = _trips.indexWhere((t) => t.tripId == tripId);
    if (i == -1 || !mounted) return;
    setState(() => _trips[i] = change(_trips[i]));
  }

  void _stale(String tripId, String? type) {
    if (type == SocialErrorTypes.tripRequestsFull) _update(tripId, (t) => t.copyWith(requestsFull: true));
    if (type == SocialErrorTypes.cannotRejoin) _update(tripId, (t) => t.copyWith(myJoin: 'removed'));
  }

  @override
  Widget build(BuildContext context) {
    if (_trips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: DS.gapInsets(l: 22, t: 26, r: 22, b: 12),
          child: Text(widget.title, style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.3)),
        ),
        for (final t in _trips)
          Padding(
            padding: DS.gapInsets(l: 18, r: 18, b: 12),
            child: TripJoinCard(
              trip: t,
              showOwner: false,
              onRequested: (id) => _update(id, (p) => p.copyWith(myJoin: 'requested')),
              onStale: _stale,
              onBack: widget.onBack,
            ),
          ),
      ],
    );
  }
}
