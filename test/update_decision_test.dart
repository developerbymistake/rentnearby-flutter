import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/models/app_version_config_model.dart';
import 'package:bakhli/utils/update_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12);

  AppVersionConfigModel cfg({
    bool enabled = true,
    int min = 52,
    int latest = 55,
    DateTime? fetchedAt,
    Duration maxAge = AppConstants.defaultForceCacheMaxAge,
  }) =>
      AppVersionConfigModel(
        platform: 'ANDROID',
        enabled: enabled,
        minBuild: min,
        minVersionName: '1.0.1',
        latestBuild: latest,
        latestVersionName: '1.0.3',
        storeUrl: AppConstants.playStoreUrl,
        message: null,
        forceCacheMaxAge: maxAge,
        fetchedAt: fetchedAt ?? now,
      );

  group('UpdateDecision.evaluate', () {
    test('null or disabled config is none', () {
      expect(UpdateDecision.evaluate(40, null, now: now), UpdateGateState.none);
      expect(UpdateDecision.evaluate(40, cfg(enabled: false), now: now), UpdateGateState.none);
    });

    test('unknown installed build never gates', () {
      expect(UpdateDecision.evaluate(0, cfg(), now: now), UpdateGateState.none);
      expect(UpdateDecision.evaluate(-1, cfg(), now: now), UpdateGateState.none);
    });

    test('zeroed config is none', () {
      expect(UpdateDecision.evaluate(10, cfg(min: 0), now: now), UpdateGateState.none);
      expect(UpdateDecision.evaluate(10, cfg(latest: 0), now: now), UpdateGateState.none);
    });

    test('force below min, soft below latest, none at or above latest', () {
      expect(UpdateDecision.evaluate(51, cfg(), now: now), UpdateGateState.force);
      expect(UpdateDecision.evaluate(52, cfg(), now: now), UpdateGateState.soft);
      expect(UpdateDecision.evaluate(54, cfg(), now: now), UpdateGateState.soft);
      expect(UpdateDecision.evaluate(55, cfg(), now: now), UpdateGateState.none);
      expect(UpdateDecision.evaluate(99, cfg(), now: now), UpdateGateState.none);
    });

    test('cached force expires after forceCacheMaxAge', () {
      final stale = cfg(fetchedAt: now.subtract(const Duration(hours: 169)));
      expect(UpdateDecision.evaluate(51, stale, now: now), UpdateGateState.none);
      final fresh = cfg(fetchedAt: now.subtract(const Duration(hours: 167)));
      expect(UpdateDecision.evaluate(51, fresh, now: now), UpdateGateState.force);
    });

    test('fetchedAt far in the future is treated as expired', () {
      final future = cfg(fetchedAt: now.add(const Duration(days: 2)));
      expect(UpdateDecision.evaluate(51, future, now: now), UpdateGateState.none);
    });
  });

  group('AppVersionConfigModel.fromJson', () {
    Map<String, dynamic> body() => {
          'platform': 'ANDROID',
          'enabled': true,
          'minBuildNumber': 52,
          'minVersionName': '1.0.1',
          'latestBuildNumber': 55,
          'latestVersionName': '1.0.3',
          'storeUrl': AppConstants.playStoreUrl,
          'message': '  ',
          'forceCacheMaxAgeHours': 48,
        };

    test('parses a valid enabled body', () {
      final m = AppVersionConfigModel.fromJson(body(), fetchedAt: now);
      expect(m.minBuild, 52);
      expect(m.latestBuild, 55);
      expect(m.message, isNull);
      expect(m.forceCacheMaxAge, const Duration(hours: 48));
      expect(m.fetchedAt, now);
    });

    test('rejects non-bool enabled', () {
      expect(() => AppVersionConfigModel.fromJson(body()..['enabled'] = 'true'), throwsFormatException);
      expect(() => AppVersionConfigModel.fromJson(body()..remove('enabled')), throwsFormatException);
    });

    test('rejects non-int builds when enabled', () {
      expect(() => AppVersionConfigModel.fromJson(body()..['minBuildNumber'] = '52'), throwsFormatException);
      expect(() => AppVersionConfigModel.fromJson(body()..['latestBuildNumber'] = null), throwsFormatException);
    });

    test('disabled body tolerates missing builds', () {
      final m = AppVersionConfigModel.fromJson({'enabled': false}, fetchedAt: now);
      expect(m.enabled, isFalse);
      expect(m.minBuild, 0);
      expect(m.latestBuild, 0);
    });

    test('missing or invalid max age falls back, oversized is clamped', () {
      expect(AppVersionConfigModel.fromJson(body()..remove('forceCacheMaxAgeHours')).forceCacheMaxAge,
          AppConstants.defaultForceCacheMaxAge);
      expect(AppVersionConfigModel.fromJson(body()..['forceCacheMaxAgeHours'] = 0).forceCacheMaxAge,
          AppConstants.defaultForceCacheMaxAge);
      expect(AppVersionConfigModel.fromJson(body()..['forceCacheMaxAgeHours'] = 100000).forceCacheMaxAge,
          AppConstants.maxForceCacheMaxAge);
    });

    test('round-trips through toJson', () {
      final m = AppVersionConfigModel.fromJson(body(), fetchedAt: now);
      final back = AppVersionConfigModel.fromJson(m.toJson());
      expect(back.minBuild, m.minBuild);
      expect(back.latestBuild, m.latestBuild);
      expect(back.storeUrl, m.storeUrl);
      expect(back.forceCacheMaxAge, m.forceCacheMaxAge);
      expect(back.fetchedAt, m.fetchedAt);
    });

    test('persisted body without fetchedAt is immediately stale for force', () {
      final m = AppVersionConfigModel.fromJson(body());
      expect(UpdateDecision.evaluate(51, m, now: now), UpdateGateState.none);
    });
  });

  group('SoftPromptPolicy', () {
    test('prompts with no snooze or a snooze for another build', () {
      expect(SoftPromptPolicy.shouldPrompt(null, 55, now), isTrue);
      final other = SoftPromptPolicy.nextSnooze(null, 54, now);
      expect(SoftPromptPolicy.shouldPrompt(other, 55, now), isTrue);
    });

    test('later ladder escalates 24h, 72h, 7d and caps', () {
      final first = SoftPromptPolicy.nextSnooze(null, 55, now);
      expect(first.count, 1);
      expect(first.until, now.add(const Duration(hours: 24)));
      final second = SoftPromptPolicy.nextSnooze(first, 55, now);
      expect(second.until, now.add(const Duration(hours: 72)));
      final third = SoftPromptPolicy.nextSnooze(second, 55, now);
      expect(third.until, now.add(const Duration(days: 7)));
      final fourth = SoftPromptPolicy.nextSnooze(third, 55, now);
      expect(fourth.count, 4);
      expect(fourth.until, now.add(const Duration(days: 7)));
    });

    test('new latest build resets the count', () {
      final snoozed = SoftPromptPolicy.nextSnooze(SoftPromptPolicy.nextSnooze(null, 55, now), 55, now);
      expect(SoftPromptPolicy.nextSnooze(snoozed, 56, now).count, 1);
    });

    test('snooze blocks until it elapses', () {
      final s = SoftPromptPolicy.nextSnooze(null, 55, now);
      expect(SoftPromptPolicy.shouldPrompt(s, 55, now.add(const Duration(hours: 23))), isFalse);
      expect(SoftPromptPolicy.shouldPrompt(s, 55, now.add(const Duration(hours: 24))), isTrue);
    });

    test('dismissedAt more than a day in the future is expired', () {
      final s = SoftPromptPolicy.nextSnooze(null, 55, now.add(const Duration(days: 3)));
      expect(SoftPromptPolicy.shouldPrompt(s, 55, now), isTrue);
    });

    test('store-opened snooze is 24h and does not escalate', () {
      final later = SoftPromptPolicy.nextSnooze(null, 55, now);
      final afterStore = SoftPromptPolicy.afterStoreOpened(later, 55, now);
      expect(afterStore.count, 1);
      expect(afterStore.until, now.add(AppConstants.softUpdateAfterStoreSnooze));
    });

    test('snooze json round-trips and rejects garbage', () {
      final s = SoftPromptPolicy.nextSnooze(null, 55, now);
      final back = SoftSnooze.tryParse(s.toJson());
      expect(back?.latestBuild, 55);
      expect(back?.until, s.until);
      expect(SoftSnooze.tryParse({'latestBuild': '55'}), isNull);
      expect(SoftSnooze.tryParse(null), isNull);
    });
  });
}
