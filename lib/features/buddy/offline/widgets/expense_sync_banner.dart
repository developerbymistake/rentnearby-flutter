import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/note_banner.dart';
import '../expense_op.dart';
import '../expense_queue_service.dart';
import '../offline_strings.dart';
import '../queue_rules.dart';

class SyncBannerLook {
  const SyncBannerLook(this.text, this.art, this.tone);

  final String text;
  final String art;
  final NoteTone tone;

  static SyncBannerLook? of(List<ExpenseOp> tripOps, {required bool offline}) {
    final notSaved = tripOps.where((o) => o.notSaved).toList();
    if (notSaved.isNotEmpty) {
      return notSaved.any(QueueRules.isFrozen)
          ? SyncBannerLook(OfflineStrings.frozenBanner(notSaved.length), BuddyArt.locked, NoteTone.danger)
          : SyncBannerLook(OfflineStrings.notSavedBanner(notSaved.length), BuddyArt.warning, NoteTone.danger);
    }
    if (!offline) return null;
    final waiting = tripOps.where((o) => o.waiting).length;
    return SyncBannerLook(waiting == 0 ? OfflineStrings.offline : OfflineStrings.offlineWaiting(waiting), BuddyArt.antenna, NoteTone.amber);
  }
}

class ExpenseSyncBanner extends StatefulWidget {
  const ExpenseSyncBanner({super.key, required this.tripId});

  final String tripId;

  @override
  State<ExpenseSyncBanner> createState() => _ExpenseSyncBannerState();
}

class _ExpenseSyncBannerState extends State<ExpenseSyncBanner> {
  @override
  void initState() {
    super.initState();
    ExpenseQueueService.maybe?.sync();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ExpenseQueueService.maybe;
    if (queue == null) return const SizedBox.shrink();
    return Obx(() {
      queue.version.value;
      final look = SyncBannerLook.of(queue.opsOf(widget.tripId), offline: queue.offline.value);
      if (look == null) return const SizedBox.shrink();
      return NoteBanner(
        art: look.art,
        text: look.text,
        tone: look.tone,
        margin: DS.insets(l: 18, t: look.tone == NoteTone.amber ? 20 : 24, r: 18),
      );
    });
  }
}
