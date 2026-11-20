import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/hub/hub_tokens.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_format.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../models/viewer_models.dart';
import '../viewer_strings.dart';
import 'viewer_card_parts.dart';

class InviteWaitingCard extends StatelessWidget {
  const InviteWaitingCard({super.key, required this.invite, this.onOpen});

  final SharedInvite invite;
  final VoidCallback? onOpen;

  void _open() => onOpen != null ? onOpen!() : BuddyNavigation.openTripInvite(invite.memberId);

  @override
  Widget build(BuildContext context) {
    final dates = BuddyFormat.dateRange(invite.startDate, invite.endDate);
    return ViewerHubCard(
      key: ValueKey('invite_card_${invite.memberId}'),
      onTap: _open,
      children: [
        const ViewerCardTitle(ViewerStrings.inviteTitle),
        ViewerMetaRow(badge: ViewerStrings.inviteWaiting, tone: BuddyBadgeTone.pending, line: ViewerStrings.fromLine(invite.ownerName, dates), bottom: 0),
        Padding(
          padding: EdgeInsets.only(top: DS.s(10)),
          child: Text(
            ViewerStrings.invitedYou(invite.ownerName, invite.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Ink3D.text(13.5, FontWeight.w400, HubTokens.sub, height: 1.5, letterSpacing: 0),
          ),
        ),
        ViewerFootStrip(
          key: ValueKey('invite_view_${invite.memberId}'),
          small: ViewerStrings.daysCities(invite.dayCount, invite.cityCount),
          title: ViewerStrings.view,
          onTap: _open,
        ),
      ],
    );
  }
}
