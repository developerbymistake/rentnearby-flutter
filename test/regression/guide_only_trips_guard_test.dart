import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _deleted = [
  'lib/features/seeker_home/seeker_tour_steps.dart',
  'lib/features/stay/guest/stay_tour_steps.dart',
  'lib/features/stay_owner/home/stay_owner_tour_steps.dart',
  'lib/features/taxi_driver/home/taxi_driver_tour_steps.dart',
  'lib/widgets/tour_info_dialog.dart',
];

const _allowed = {
  'lib/config/tour_registry.dart',
  'lib/controllers/tour_controller.dart',
  'lib/config/app_tour_state.dart',
  'lib/widgets/tour_host.dart',
  'lib/widgets/tour_overlay.dart',
  'lib/navigation/tour_keys.dart',
  'lib/utils/tour_target_ready.dart',
  'lib/services/tour_dismiss_observer.dart',
  'lib/main.dart',
  'lib/screens/main_screen.dart',
  'lib/controllers/app_version_controller.dart',
  'lib/services/storage_service.dart',
  'lib/features/trip/screens/trips_discovery_screen.dart',
  'lib/features/trip/trips_tour_steps.dart',
  'lib/screens/intro/intro_scaffold.dart',
  'lib/screens/splash_screen.dart',
};

Map<String, String> _lib() => {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        f.path.replaceAll('\\', '/'): f.readAsStringSync(),
    };

void main() {
  final lib = _lib();

  test('the removed tour files are gone', () {
    for (final p in _deleted) {
      expect(File(p).existsSync(), isFalse, reason: p);
    }
  });

  test('only the allowed files touch the tour engine', () {
    final pattern = RegExp(r'\b(TourKeys|tourRegistry|TourController|tourInProgress)\b');
    final offenders = [
      for (final e in lib.entries)
        if (!_allowed.contains(e.key) && pattern.hasMatch(e.value)) e.key,
    ];
    expect(offenders, isEmpty);
  });

  test('tour_keys holds exactly the two Trips keys', () {
    final src = lib['lib/navigation/tour_keys.dart']!;
    final keys = RegExp(r'static final (\w+) = GlobalKey').allMatches(src).map((m) => m.group(1)).toList();
    expect(keys, ['tripsWhereTile', 'tripsBuddyTile']);
  });

  test('old seen keys appear only in the storage removal', () {
    final offenders = [
      for (final e in lib.entries)
        if (e.key != 'lib/services/storage_service.dart' && (e.value.contains('tour_home_seen') || e.value.contains('tour_stays_seen'))) e.key,
    ];
    expect(offenders, isEmpty);
  });

  test('no dialog tour or old tour labels anywhere in lib', () {
    for (final word in ['TourInfoDialog', 'TourDialogContent', 'Start Tour', 'Home Tour', 'Stays Tour']) {
      final offenders = [for (final e in lib.entries) if (e.value.contains(word)) e.key];
      expect(offenders, isEmpty, reason: word);
    }
  });
}
