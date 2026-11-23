import 'dart:io';

import 'package:bakhli/config/app_map_state.dart';
import 'package:bakhli/services/map_pause_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _labDir = 'lib/features/dev/map_lab/';
const _entry = 'lib/features/dev/map_lab/map_lab_entry.dart';
const _rows = 'lib/screens/profile/profile_rows.dart';

String _norm(String p) => p.replaceAll(r'\', '/');

List<File> _dart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

final _importLine = RegExp(r'^\s*(import|export)\b');

void main() {
  test('map_lab is imported only by its entry file and the profile rows file', () {
    final bad = <String>[];
    for (final f in _dart()) {
      final path = _norm(f.path);
      if (path.startsWith(_labDir)) continue;
      for (final line in f.readAsLinesSync()) {
        if (_importLine.hasMatch(line) && line.contains('map_lab') && path != _rows) bad.add(path);
      }
    }
    expect(bad, isEmpty);
    for (final f in _dart().where((f) => _norm(f.path).startsWith(_labDir) && _norm(f.path) != _entry)) {
      expect(f.readAsStringSync().contains('map_lab_entry'), isFalse, reason: f.path);
    }
    final rows = File(_rows).readAsStringSync();
    expect(rows.contains('map_lab_entry.dart'), isTrue);
    expect(rows.contains('map_lab_screen'), isFalse);
  });

  test('every use of MapLabEntry and MapLabScreen outside the lab sits inside a kDebugMode block', () {
    final use = RegExp(r'\b(MapLabEntry|MapLabScreen)\b');
    final offenders = <String>[];
    for (final f in _dart()) {
      final path = _norm(f.path);
      if (path.startsWith(_labDir) && path != _entry) continue;
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!use.hasMatch(l) || _importLine.hasMatch(l) || l.contains('class MapLabEntry')) continue;
        final from = i < 6 ? 0 : i - 6;
        if (!lines.sublist(from, i + 1).join('\n').contains('kDebugMode')) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join(', '));
  });

  test('no routes file or GetPage mentions the map lab', () {
    final offenders = <String>[];
    for (final f in _dart()) {
      final path = _norm(f.path);
      if (path.startsWith(_labDir)) continue;
      final text = f.readAsStringSync();
      final isRoutes = path.contains('routes') || text.contains('GetPage(');
      if (isRoutes && (text.contains('map_lab') || text.contains('MapLab'))) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: offenders.join(', '));
    final lab = _dart().where((f) => _norm(f.path).startsWith(_labDir)).map((f) => f.readAsStringSync()).join('\n');
    expect(lab.contains('GetPage('), isFalse);
    expect(lab.contains('Get.toNamed'), isFalse);
  });

  test('the entry body is guarded by kDebugMode', () {
    final text = File(_entry).readAsStringSync();
    final open = text.substring(text.indexOf('static void open'));
    expect(open.indexOf('kDebugMode'), lessThan(open.indexOf('MapLabScreen')));
  });

  test('APP-14: the lab opens under its own route name and that route pauses the list maps', () {
    final entry = File(_entry).readAsStringSync();
    expect(entry.contains("static const String routeName = '/map-lab';"), isTrue);
    expect(entry.contains('routeName: routeName'), isTrue);
    final observer = MapPauseObserver();
    mapShouldPause.value = false;
    final route = MaterialPageRoute<void>(settings: const RouteSettings(name: '/map-lab'), builder: (_) => const SizedBox());
    observer.didPush(route, null);
    expect(mapShouldPause.value, isTrue);
    observer.didPop(route, null);
    expect(mapShouldPause.value, isFalse);
  });
}
