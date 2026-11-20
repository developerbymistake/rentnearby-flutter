import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_format.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../models/viewer_models.dart' as vm;
import '../viewer_look.dart';
import '../viewer_rules.dart';
import '../viewer_strings.dart';
import 'viewer_card_parts.dart';

class FormerTripCard extends StatelessWidget {
  const FormerTripCard({super.key, required this.trip, this.onOpen});

  final vm.FormerTripCard trip;
  final VoidCallback? onOpen;

  void _open() => onOpen != null ? onOpen!() : BuddyNavigation.openMyShare(trip.tripId);

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final dates = BuddyFormat.dateRange(t.startDate, t.endDate);
    final money = ViewerRules.moneyLine(t.myNet, t.owesToName ?? t.ownerName);
    return ViewerHubCard(
      key: ValueKey('former_card_${t.tripId}'),
      onTap: _open,
      children: [
        ViewerCardTitle(t.title),
        ViewerMetaRow(
          badge: t.endedHow == 'Removed' ? ViewerStrings.removed : ViewerStrings.left,
          tone: BuddyBadgeTone.grey,
          line: ViewerStrings.byLine(t.ownerName, dates),
          bottom: 0,
        ),
        if (money.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.s(10)),
            child: Text(money, key: const ValueKey('former_money'), style: Ink3D.text(15, FontWeight.w700, ViewerLook.roseText, letterSpacing: 0)),
          ),
        ViewerFootStrip(
          key: ValueKey('former_open_${t.tripId}'),
          small: ViewerStrings.expensesYouShare(t.sharedCount),
          title: ViewerStrings.seeMyShare,
          rose: true,
          onTap: _open,
        ),
      ],
    );
  }
}
