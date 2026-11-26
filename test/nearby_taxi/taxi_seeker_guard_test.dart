import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _seekerDir = 'lib/features/taxi/guest/v2';

List<File> _files() => Directory(_seekerDir).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

void main() {
  test('no Ask or Enquiry on the taxi tab or the results page', () {
    final bad = <String>[];
    for (final f in _files()) {
      final s = f.readAsStringSync();
      for (final w in ["'Ask'", "'Ask driver'", "'Enquiry'", "'Ask drivers'"]) {
        if (s.contains(w)) bad.add('${f.path}: $w');
      }
    }
    expect(bad, isEmpty);
  });

  test('no payment words in the seeker taxi search', () {
    final bad = <String>[];
    for (final f in _files()) {
      final s = f.readAsStringSync().toLowerCase();
      for (final w in ['upi', 'advance', 'refund', 'pay now']) {
        if (s.contains(w)) bad.add('${f.path}: $w');
      }
    }
    expect(bad, isEmpty);
  });

  test('the old list and its repository send the journey day on browse and search (R11)', () {
    final repo = File('lib/features/taxi/guest/taxi_browse_repository.dart').readAsStringSync();
    expect("'date': TaxiJourneyDate.apiText(date)".allMatches(repo), hasLength(2));
    expect(RegExp(r"'/taxis/browse'[^;]*'date': TaxiJourneyDate\.apiText\(date\)").hasMatch(repo), isTrue);
    expect(RegExp(r"'/taxis/search'[^;]*'date': TaxiJourneyDate\.apiText\(date\)").hasMatch(repo), isTrue);
    final list = File('lib/features/taxi/guest/taxi_list_controller.dart').readAsStringSync();
    expect(RegExp(r'_repo\.search\([^;]*date: day,').hasMatch(list), isTrue);
    expect(RegExp(r'_repo\.browseLocal\([^;]*date: day,').hasMatch(list), isTrue);
  });

  test('the results page is not a map route and the tab has no route body', () {
    final screen = File('$_seekerDir/taxi_list_screen_v2.dart').readAsStringSync();
    expect(screen.contains('RouteCitiesStrip'), isFalse);
    expect(screen.contains('TaxiWaysEntryCard'), isFalse);
    final pause = File('lib/services/map_pause_observer.dart').readAsStringSync();
    expect(pause.contains('taxiRouteResults'), isFalse);
  });
}
