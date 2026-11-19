import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pace_and_leg_menu_are_gone', () {
    final gone = [
      'setPace',
      'TripPaceSheet',
      'Pace: ',
      'paceTitle',
      'TripLegMenuSheet',
      'leg-menu',
      'canMoveLeg',
      RegExp(r'\bmoveLeg\('),
    ];
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      for (final g in gone) {
        if (text.contains(g)) hits.add('${f.path}: $g');
      }
    }
    expect(hits, isEmpty);
    expect(File('lib/features/trip/widgets/trip_pace_sheet.dart').existsSync(), isFalse);
    expect(File('lib/features/trip/widgets/trip_leg_menu_sheet.dart').existsSync(), isFalse);
  });
}
