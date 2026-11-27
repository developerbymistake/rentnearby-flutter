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

  test('Profile photo crop: uCrop activity is declared, not exported, with the AppCompat UCropTheme', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final start = manifest.indexOf('android:name="com.yalantis.ucrop.UCropActivity"');
    expect(start, greaterThan(-1));
    final block = manifest.substring(manifest.lastIndexOf('<activity', start), manifest.indexOf('/>', start));
    expect(block, contains('android:exported="false"'));
    expect(block, contains('android:theme="@style/UCropTheme"'));
    expect(block, contains('android:screenOrientation="portrait"'));
    for (final path in ['android/app/src/main/res/values/styles.xml', 'android/app/src/main/res/values-v35/styles.xml']) {
      expect(File(path).readAsStringSync(), contains('<style name="UCropTheme" parent="Theme.AppCompat.Light.NoActionBar"'), reason: path);
    }
    expect(File('android/app/src/main/res/values-v35/styles.xml').readAsStringSync(), contains('android:windowOptOutEdgeToEdgeEnforcement'));
    expect(File('android/app/proguard-rules.pro').readAsStringSync(), contains('-keep class com.yalantis.ucrop** { *; }'));
  });

  test('Quotation PDFs: storage permission only up to Android 9, channel registered, print helper kept in android.print', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>'));
    expect(manifest.contains('READ_EXTERNAL_STORAGE'), isFalse);
    expect(manifest.contains('MANAGE_EXTERNAL_STORAGE'), isFalse);
    final activity = File('android/app/src/main/kotlin/com/rentnearby/rentnearby/MainActivity.kt').readAsStringSync();
    expect(activity, contains('QuotePdfChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)'));
    final helper = File('android/app/src/main/kotlin/android/print/QuotePdfPrinter.kt').readAsStringSync();
    expect(helper, contains('package android.print'));
    expect(helper, contains('@Keep'));
    final channel = File('android/app/src/main/kotlin/com/rentnearby/rentnearby/QuotePdfChannel.kt').readAsStringSync();
    for (final rule in ['blockNetworkLoads = true', 'allowFileAccess = false', 'allowContentAccess = false', 'onRenderProcessGone', 'Base64.NO_WRAP', 'MIXED_CONTENT_NEVER_ALLOW']) {
      expect(channel, contains(rule), reason: rule);
    }
    expect(channel.contains('addJavascriptInterface'), isFalse);
    expect(channel.contains('enableSlowWholeDocumentDraw'), isFalse);
  });
}
