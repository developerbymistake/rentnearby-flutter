import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Q6 (owner order 2026-11-27): the QR now opens a profile to follow; the app never sends a buddy request.
void main() {
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  String rel(File f) => f.path.replaceAll(r'\', '/');

  test('no app code calls the old buddy request or seen endpoints', () {
    final banned = RegExp(r"""['"]/buddies/(requests|seen)\b""");
    final hits = [for (final f in files) if (banned.hasMatch(f.readAsStringSync())) rel(f)];
    expect(hits, isEmpty);
  });

  test('the old Buddies screen and its find and request code are gone', () {
    for (final path in [
      'lib/features/buddy/buddies/screens/buddies_screen.dart',
      'lib/features/buddy/buddies/controllers/buddy_find_controller.dart',
      'lib/features/buddy/buddies/controllers/buddy_requests_controller.dart',
      'lib/features/buddy/buddies/widgets/find_tab.dart',
      'lib/features/buddy/buddies/widgets/requests_tab.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    final names = RegExp(r'\b(BuddyFindController|BuddyRequestsController|BuddiesScreen)\b');
    final hits = [for (final f in files) if (names.hasMatch(f.readAsStringSync())) rel(f)];
    expect(hits, isEmpty);
    expect(File('lib/features/buddy/buddies/data/buddies_api.dart').readAsStringSync(), isNot(contains('sendRequest')));
  });

  test('People carries Scan QR and My profile carries My QR', () {
    expect(File('lib/features/social/a/people/people_screen.dart').readAsStringSync(), contains('scanToFollow.start'));
    expect(File('lib/features/social/a/profile/seeker_profile_screen.dart').readAsStringSync(), contains('UsernameQrSheet.show'));
  });
}
