import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_hero_card.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../models/sharing_models.dart';
import '../sharing_strings.dart';

class OverviewTravellersCard extends StatelessWidget {
  const OverviewTravellersCard({super.key, required this.sharing, required this.onInvite, required this.onManage});

  final TripSharingBlock sharing;
  final VoidCallback onInvite;
  final VoidCallback onManage;

  bool get alone => sharing.travellerCount <= 1 && sharing.pendingInvites == 0;

  @override
  Widget build(BuildContext context) => TripHeroCard(
        key: const ValueKey('overview_travellers_card'),
        tone: BuddyLook.teal,
        asset: BuddyArt.panda,
        title: SharingStrings.travellersTitle,
        chipWidget: TravellerDots(people: sharing.firstTravellers),
        line: alone ? SharingStrings.onlyYou : SharingStrings.joinedLine(sharing.travellerCount, sharing.pendingInvites),
        button: alone ? SharingStrings.invite : SharingStrings.manage,
        buttonKey: const ValueKey('overview_travellers_button'),
        onTap: alone ? onInvite : onManage,
        compact: true,
      );
}

class TravellerDots extends StatelessWidget {
  const TravellerDots({super.key, required this.people, this.max = 3});

  final List<TravellerDot> people;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    return Row(
      key: const ValueKey('overview_traveller_dots'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Transform.translate(
            offset: Offset(-DS.s(8) * i, 0),
            child: BuddyAvatar(initial: shown[i].initial, seed: shown[i].userId, size: BuddyAvatarSize.sm, ring: true, photoUrl: shown[i].photoUrl),
          ),
      ],
    );
  }
}
