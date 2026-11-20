import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/section_label.dart';
import '../buddies_strings.dart';
import '../buddy_me.dart';
import '../controllers/buddies_controller.dart';
import '../models/buddy_models.dart';
import 'buddy_empty_state.dart';
import 'username_card.dart';

class BuddyDots extends StatelessWidget {
  const BuddyDots({super.key, required this.onTap, required this.label});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: label,
        exclude: true,
        child: SizedBox(
          width: DS.s(40),
          height: DS.s(40),
          child: Center(child: TripMenuDots.glyph(BuddyLook.subText)),
        ),
      );
}

class BuddyListSkeleton extends StatelessWidget {
  const BuddyListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const PersonListCard(children: [SkeletonListRow(), SkeletonListRow(), SkeletonListRow()]);
}

class BuddyLoadFailed extends StatelessWidget {
  const BuddyLoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => BuddyEmptyState(
        art: BuddyArt.antenna,
        title: BuddySharedStrings.couldNotLoad,
        line: BuddySharedStrings.couldNotLoadLine,
        red: true,
        actionLabel: BuddySharedStrings.retry,
        onAction: onRetry,
      );
}

class MyBuddiesTab extends StatelessWidget {
  const MyBuddiesTab({super.key, required this.controller, required this.me, required this.onCopy, required this.onOpenBuddy});

  final BuddiesController controller;
  final BuddyMe me;
  final VoidCallback onCopy;
  final void Function(BuddyItem item) onOpenBuddy;

  @override
  Widget build(BuildContext context) => Obx(() {
        final c = controller;
        switch (c.state.value) {
          case BuddyListState.loading:
            return Padding(padding: EdgeInsets.only(top: DS.s(24)), child: const BuddyListSkeleton());
          case BuddyListState.failed:
            return BuddyLoadFailed(onRetry: c.load);
          case BuddyListState.ready:
            break;
        }
        if (c.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BuddyEmptyState(art: BuddyArt.panda, title: BuddiesStrings.emptyTitle, line: BuddiesStrings.emptyLine),
              UsernameCard(me: me, actionLabel: BuddiesStrings.copy, onAction: onCopy),
            ],
          );
        }
        final total = c.count.value > c.items.length ? c.count.value : c.items.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(BuddiesStrings.buddiesLabel(total), padding: DS.insets(l: 22, t: 24, r: 22, b: 10)),
            PersonListCard(
              children: [
                for (final b in c.items)
                  PersonRow(
                    key: ValueKey('buddy-${b.userId}'),
                    avatar: BuddyAvatar(initial: b.initial, seed: b.userId),
                    title: b.name,
                    titleBadge: b.isNew ? const BuddyBadge(BuddiesStrings.badgeNew, tone: BuddyBadgeTone.teal) : null,
                    subtitle: b.username,
                    trailing: BuddyDots(onTap: () => onOpenBuddy(b), label: BuddiesStrings.menuLabel),
                    onTap: () => onOpenBuddy(b),
                  ),
              ],
            ),
            if (c.loadingMore.value) Padding(padding: EdgeInsets.only(top: DS.s(12)), child: const BuddyListSkeleton()),
          ],
        );
      });
}
