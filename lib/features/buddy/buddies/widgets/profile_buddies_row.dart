import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_look.dart';
import '../buddies_strings.dart';
import '../controllers/buddy_summary_controller.dart';
import '../models/buddy_models.dart';

class ProfileBuddiesRow extends StatelessWidget {
  const ProfileBuddiesRow({super.key});

  static String subtitleOf(BuddySummary s) {
    if (s.receivedPending > 0) return BuddiesStrings.newRequests(s.receivedPending);
    if (s.buddies > 0) return BuddiesStrings.buddyCount(s.buddies);
    return BuddiesStrings.rowFallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = BuddySummaryController.maybe;
    if (c == null) return _row(BuddySummary.empty);
    return Obx(() => _row(c.summary.value));
  }

  Widget _row(BuddySummary s) {
    final pending = s.receivedPending;
    return IconRow3D(
      art: BuddyArt.panda,
      title: BuddiesStrings.title,
      subtitle: subtitleOf(s),
      divider: true,
      onTap: () => BuddyNavigation.openBuddies(tab: pending > 0 ? 'requests' : 'buddies'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending > 0) ...[
            Container(
              constraints: BoxConstraints(minWidth: DS.s(22), minHeight: DS.s(22)),
              padding: DS.sym(h: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(11)),
              child: Text('$pending', textScaler: TextScaler.noScaling, style: Ink3D.text(11.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
            ),
            Gap.h(8),
          ],
          Icon(Icons.chevron_right_rounded, size: DS.s(22), color: BuddyLook.chevron),
        ],
      ),
    );
  }
}
