import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_args.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import '../support/owner_fakes.dart';

// JT-A-SEC-1 (shared part): backup off, no raw failure text in owner toasts, non-GUID ids are missing,
// the owner box is wiped by logout, and a revoked session says why (FX-16, FX-28, FX-18, FX-36).
void main() {
  setUpAll(() => initTestStorage('jt_sec1'));

  test('step 1: Android backup and device transfer copy nothing', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    expect('<exclude domain="sharedpref" />'.allMatches(rules).length, 2);
  });

  test('step 2: a push or route id that is not a GUID is treated as missing', () {
    for (final bad in ['', '../me', '1; DROP', '<script>', '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a610', 42]) {
      expect(OwnerArgs.id({'id': bad}, 'id'), isNull, reason: '$bad');
    }
    expect(OwnerArgs.id({'id': '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101'}, 'id'), isNotNull);
  });

  test('step 3: no owner screen hands an OwnerFailed message to a toast', () {
    final failedCase = RegExp(r'case OwnerFailed(<[^>]*>)?\(:final message\)');
    final offenders = <String>[];
    for (final root in const ['lib/features/owner_core', 'lib/features/stay_owner', 'lib/features/taxi_driver', 'lib/features/seeker_home']) {
      for (final f in Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!failedCase.hasMatch(lines[i])) continue;
          for (var j = i + 1; j < lines.length && j <= i + 6 && !lines[j].contains('case '); j++) {
            if (RegExp(r'AppToast\.\w+\([^)]*\bmessage\b').hasMatch(lines[j])) offenders.add('${f.path}:${j + 1}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('step 4: logout erases the owner box in one step and leaves nothing in the default box', () {
    OwnerCache.write('u1', OwnerCacheKeys.home, {'moneyNote': 'paid 2000 cash'});
    OwnerCache.setStatusSeen('u1', 'k');
    expect(GetStorage(OwnerCache.container).getKeys<Iterable<dynamic>>(), isNotEmpty);
    OwnerCache.clearAll();
    expect(GetStorage(OwnerCache.container).getKeys<Iterable<dynamic>>(), isEmpty);
    expect(GetStorage().getKeys<Iterable<dynamic>>().whereType<String>().where((k) => k.startsWith(OwnerCache.cachePrefix)), isEmpty);
  });

  test('step 5: a revoked session names the reason; anything else is an expired session', () {
    expect(ApiService.reasonFor401({'error': {'type': 'SessionRoleChanged'}}), LogoutReason.roleChanged);
    expect(ApiService.reasonFor401({'error': {'type': 'AccountSuspended'}}), LogoutReason.accountSuspended);
    expect(ApiService.reasonFor401({'error': {'type': 'Whatever'}}), LogoutReason.sessionExpired);
    expect(ApiService.reasonFor401('not json'), LogoutReason.sessionExpired);
  });
}
