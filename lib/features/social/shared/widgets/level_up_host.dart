import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../services/storage_service.dart';
import '../social_me_controller.dart';
import '../social_models.dart';
import 'travel_level_widgets.dart';

abstract final class LevelSeen {
  // First run only records; afterwards a higher level than the last seen one is returned once (a lower one is ignored).
  static int? pending(String userId, int level) {
    if (userId.isEmpty) return null;
    final seen = StorageService.getSeenTravelLevel(userId);
    if (seen != null && level <= seen) return null;
    StorageService.saveSeenTravelLevel(userId, level);
    return seen == null ? null : level;
  }
}

// Sits in the main shell; shows the level-up sheet once when /social/me reports a new level.
class LevelUpHost extends StatefulWidget {
  const LevelUpHost({super.key});

  @override
  State<LevelUpHost> createState() => _LevelUpHostState();
}

class _LevelUpHostState extends State<LevelUpHost> {
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    final c = SocialMeController.maybe;
    if (c == null) return;
    _worker = ever<SocialMe?>(c.me, _check);
    _check(c.me.value);
  }

  void _check(SocialMe? me) {
    final p = me?.profile;
    if (p == null) return;
    final level = LevelSeen.pending(p.userId, p.level);
    if (level == null) return;
    final trips = p.completedTrips;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Already on the Travel levels page (opened from the level-up push): the level counts as seen.
      if (mounted && Get.currentRoute != AppRoutes.travelLevels) LevelUpSheet.show(context, level: level, trips: trips);
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
