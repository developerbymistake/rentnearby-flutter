import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';
import '../models/app_version_config_model.dart';

enum UpdateGateState { none, soft, force }

class UpdateDecision {
  const UpdateDecision._();

  static const bool _disableGateDefine = bool.fromEnvironment('DISABLE_UPDATE_GATE');

  /// `--dart-define=DISABLE_UPDATE_GATE=true`, honoured in debug/profile builds only.
  static bool get disabledByDefine => !kReleaseMode && _disableGateDefine;

  static UpdateGateState evaluate(int installedBuild, AppVersionConfigModel? cfg, {required DateTime now}) {
    if (disabledByDefine) return UpdateGateState.none;
    if (cfg == null || !cfg.enabled) return UpdateGateState.none;
    if (installedBuild <= 0) return UpdateGateState.none;
    if (cfg.minBuild <= 0 || cfg.latestBuild <= 0) return UpdateGateState.none;
    if (installedBuild < cfg.minBuild) {
      return cfg.isForceEnforceableAt(now) ? UpdateGateState.force : UpdateGateState.none;
    }
    if (installedBuild < cfg.latestBuild) return UpdateGateState.soft;
    return UpdateGateState.none;
  }
}

class SoftSnooze {
  final int latestBuild;
  final DateTime dismissedAt;
  final DateTime until;
  final int count;

  const SoftSnooze({
    required this.latestBuild,
    required this.dismissedAt,
    required this.until,
    required this.count,
  });

  static SoftSnooze? tryParse(Map<String, dynamic>? j) {
    if (j == null) return null;
    final latestBuild = j['latestBuild'];
    final count = j['count'];
    final dismissedAt = j['dismissedAt'] is String ? DateTime.tryParse(j['dismissedAt'] as String) : null;
    final until = j['until'] is String ? DateTime.tryParse(j['until'] as String) : null;
    if (latestBuild is! int || count is! int || dismissedAt == null || until == null) return null;
    return SoftSnooze(latestBuild: latestBuild, dismissedAt: dismissedAt, until: until, count: count);
  }

  Map<String, dynamic> toJson() => {
        'latestBuild': latestBuild,
        'dismissedAt': dismissedAt.toIso8601String(),
        'until': until.toIso8601String(),
        'count': count,
      };
}

class SoftPromptPolicy {
  const SoftPromptPolicy._();

  static bool shouldPrompt(SoftSnooze? snooze, int latestBuild, DateTime now) {
    if (snooze == null || snooze.latestBuild != latestBuild) return true;
    if (snooze.dismissedAt.isAfter(now.add(const Duration(days: 1)))) return true;
    return !now.isBefore(snooze.until);
  }

  /// "Later" / barrier / back: escalates 24h -> 72h -> 7d per latest build.
  static SoftSnooze nextSnooze(SoftSnooze? prev, int latestBuild, DateTime now) {
    final count = _countFor(prev, latestBuild) + 1;
    const ladder = AppConstants.softUpdateSnoozeDurations;
    final step = ladder[math.min(count - 1, ladder.length - 1)];
    return SoftSnooze(latestBuild: latestBuild, dismissedAt: now, until: now.add(step), count: count);
  }

  /// "Update" tapped: fixed snooze that does not escalate the Later count.
  static SoftSnooze afterStoreOpened(SoftSnooze? prev, int latestBuild, DateTime now) {
    return SoftSnooze(
      latestBuild: latestBuild,
      dismissedAt: now,
      until: now.add(AppConstants.softUpdateAfterStoreSnooze),
      count: _countFor(prev, latestBuild),
    );
  }

  static int _countFor(SoftSnooze? prev, int latestBuild) =>
      prev != null && prev.latestBuild == latestBuild ? math.max(prev.count, 0) : 0;
}
