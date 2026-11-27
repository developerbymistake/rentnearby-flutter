import 'dart:io';

import 'package:bakhli/features/stay_owner/quotation/data/quote_wipe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quote_setup_fakes.dart';

void main() {
  late FakeEngine engine;
  late MemBoxes boxes;
  late MemKeyValue secure;

  setUp(() {
    engine = FakeEngine();
    boxes = MemBoxes();
    secure = MemKeyValue();
    QuoteLocalWipe.engine = () => engine;
    QuoteLocalWipe.boxes = boxes;
    QuoteLocalWipe.secure = secure;
  });
  tearDown(QuoteLocalWipe.debugReset);

  test('wipe removes the folder, both boxes and the secure bank key of that user only', () async {
    boxes.boxes['quote_index_u1'] = {'k': {}};
    boxes.boxes['quote_cache_u1'] = {'hub': {}};
    boxes.boxes['quote_cache_u2'] = {'hub': {}};
    secure.values['quote_bank_u1'] = '{}';
    secure.values['quote_bank_u2'] = '{}';
    await QuoteLocalWipe.run('u1');
    expect(engine.calls, ['clearUser:u1']);
    expect(boxes.erased, ['quote_index_u1', 'quote_cache_u1']);
    expect(boxes.boxes.keys.toList(), ['quote_cache_u2']);
    expect(secure.values.keys.toList(), ['quote_bank_u2']);
  });

  test('no user: nothing happens', () async {
    await QuoteLocalWipe.run(null);
    await QuoteLocalWipe.run('');
    expect(engine.calls, isEmpty);
    expect(boxes.erased, isEmpty);
  });

  test('a failing step never stops the others', () async {
    QuoteLocalWipe.engine = () => throw StateError('no channel');
    await QuoteLocalWipe.run('u1');
    expect(boxes.erased, ['quote_index_u1', 'quote_cache_u1']);
    expect(secure.deleted, ['quote_bank_u1']);
  });

  test('every session end runs the wipe: the one cleanup path and the account switch call it', () {
    final src = File('lib/controllers/auth_controller.dart').readAsStringSync();
    final cleanup = src.substring(src.indexOf('Future<void> _cleanupSession('), src.indexOf('static Future<void> _clearImageCaches('));
    expect(cleanup, contains('QuoteLocalWipe.run(buddyUserId)'));
    final session = src.substring(src.indexOf('Future<void> _applySession('), src.indexOf('void markProfileCompleted('));
    expect(session, contains('QuoteLocalWipe.run(previousUserId)'));
    expect(src, contains('return ApiService.runExclusiveLogout(() => _performLogoutCleanup(reason));'));
  });
}
