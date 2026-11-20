import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/note_banner.dart';
import '../expense_queue_service.dart';
import '../offline_strings.dart';

class LostChangesBanner extends StatefulWidget {
  const LostChangesBanner({super.key});

  @override
  State<LostChangesBanner> createState() => _LostChangesBannerState();
}

class _LostChangesBannerState extends State<LostChangesBanner> {
  Worker? _tabWorker;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AuthController>()) {
      _tabWorker = ever(Get.find<AuthController>().tabIndex, (int i) {
        if (i != AppTabs.trips) _clear();
      });
    }
  }

  void _clear() {
    if (!_shown) return;
    _shown = false;
    ExpenseQueueService.maybe?.clearLost();
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ExpenseQueueService.maybe;
    if (queue == null) return const SizedBox.shrink();
    return Obx(() {
      final n = queue.lost.value;
      if (n <= 0) return const SizedBox.shrink();
      _shown = true;
      return NoteBanner(art: BuddyArt.warning, text: OfflineStrings.goneBanner(n), tone: NoteTone.danger, margin: DS.insets(l: 18, t: 4, r: 18));
    });
  }
}
