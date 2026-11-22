import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Sites with no person object in scope (only an initial). Empty today: every site has its person.
const _noPersonInScope = <String>{};

Iterable<File> _dart(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll('\\', '/');

// Returns the text of each `name(` call up to its matching close paren.
List<String> _calls(String src, String name) {
  final out = <String>[];
  var i = src.indexOf('$name(');
  while (i >= 0) {
    final start = i + name.length;
    var depth = 0;
    var j = start;
    for (; j < src.length; j++) {
      final c = src[j];
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) break;
    }
    out.add(src.substring(i, j + 1));
    i = src.indexOf('$name(', j);
  }
  return out;
}

void main() {
  test('every BuddyAvatar call under lib/features/buddy passes photoUrl', () {
    final missing = <String>[];
    var count = 0;
    for (final f in _dart('lib/features/buddy')) {
      final path = _rel(f);
      if (path.endsWith('shared/widgets/buddy_avatar.dart')) continue;
      final src = f.readAsStringSync();
      for (final call in _calls(src, 'BuddyAvatar')) {
        if (RegExp(r'\bBuddyAvatar\(\s*\)').hasMatch(call)) continue;
        count++;
        if (!call.contains('photoUrl:') && !_noPersonInScope.contains(path)) missing.add('$path: ${call.split('\n').first}');
      }
    }
    expect(count, greaterThanOrEqualTo(27), reason: 'site count dropped: the scan is broken');
    expect(missing, isEmpty);
  });

  test('every avatar record list carries photoUrl', () {
    final bad = <String>[];
    for (final f in _dart('lib/features/buddy')) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'\(initial: [^()]*?, seed: [^()]*?\)').allMatches(src)) {
        if (!m.group(0)!.contains('photoUrl:')) bad.add('${_rel(f)}: ${m.group(0)}');
      }
      for (final m in RegExp(r'\(\{String initial, String seed[^}]*\}\)').allMatches(src)) {
        if (!m.group(0)!.contains('String? photoUrl')) bad.add('${_rel(f)}: ${m.group(0)}');
      }
    }
    expect(bad, isEmpty);
  });

  test('no profile picture in jobs, card kit, taxi cards or pushes', () {
    final files = [
      ..._dart('lib/features/jobs'),
      File('lib/design/extra/card_kit.dart'),
      File('lib/features/taxi/guest/taxi_card.dart'),
      File('lib/services/notification_service.dart'),
    ];
    final hits = <String>[];
    for (final f in files) {
      expect(f.existsSync(), isTrue, reason: f.path);
      final src = f.readAsStringSync();
      // The taxi card's own `photoUrl:` is the taxi display photo, not a person picture.
      final pattern = _rel(f).endsWith('taxi_card.dart') ? r'profilePhotoUrl|ProfileAvatar|BuddyAvatar|otherPartyPhotoUrl' : r'photoUrl|profilePhotoUrl|ProfileAvatar|BuddyAvatar';
      if (RegExp(pattern).hasMatch(src)) hits.add(_rel(f));
    }
    expect(hits, isEmpty);
  });

  test('chat list passes the photo to the card and to the conversation route; the screen reads it into the header', () {
    final list = File('lib/screens/chats_list_screen.dart').readAsStringSync();
    expect(list, contains("'otherPartyPhotoUrl': c.otherPartyPhotoUrl"));
    expect(list, contains('photoUrl: c.otherPartyPhotoUrl'));
    final conv = File('lib/screens/chat_conversation_screen.dart').readAsStringSync();
    expect(conv, contains("text('otherPartyPhotoUrl')"));
    expect(conv, contains('known?.otherPartyPhotoUrl'));
    expect(conv, contains('photoUrl: _otherPartyPhotoUrl'));
  });
}
