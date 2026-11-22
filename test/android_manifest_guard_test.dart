import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FX-16: Android backup is off and every domain is excluded from cloud backup and device transfer', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final start = rules.indexOf('<$section>');
      final end = rules.indexOf('</$section>');
      expect(start, greaterThan(-1), reason: section);
      final body = rules.substring(start, end);
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(body, contains('<exclude domain="$domain" />'), reason: '$section $domain');
      }
    }
  });
}
