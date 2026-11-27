import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/person_row.dart';
import 'buddy_empty_state.dart';

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
