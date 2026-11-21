import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/owner_core/money/money_note_math.dart';
import 'package:bakhli/features/owner_core/money/money_wire.dart';
import 'package:bakhli/features/owner_core/money/phone_guard.dart';
import 'package:flutter_test/flutter_test.dart';

const _copy = 'test/features/owner_core/vectors/money_note_vectors.json';
const _source = r'F:\Dhasu\Buddy_resume\owner_build\vectors\money_note_vectors.json';

const _chips = {
  'None': MoneyChip.none,
  'ToCollect': MoneyChip.toCollect,
  'PaidInFull': MoneyChip.paidInFull,
  'Received': MoneyChip.received,
};

final _errors = {
  'amountRange': MoneyNoteError.amountRange,
  'finalNeeded': MoneyNoteError.finalNeeded,
  MoneyWire.receivedAboveFinalWire: MoneyNoteError.receivedAboveFinal,
};

void main() {
  final v = jsonDecode(File(_copy).readAsStringSync()) as Map<String, dynamic>;

  for (final c in (v['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final n = MoneyNote(
        finalAmount: (c['finalAmount'] as num?)?.toInt(),
        receivedSoFar: (c[MoneyWire.receivedKey] as num?)?.toInt(),
        paidInFull: c['paidInFull'] == true,
      );
      final e = c['expected'] as Map<String, dynamic>;
      expect(MoneyNoteMath.received(n), e['received']);
      expect(MoneyNoteMath.balance(n), e['balance']);
      expect(MoneyNoteMath.chip(n), _chips[e['chip']]);
      expect(MoneyNoteMath.chipAmount(n), e['chipAmount']);
      expect(MoneyNoteMath.validate(n), e['error'] == null ? isNull : _errors[e['error']]);
    });
  }

  test('the source vector file equals the app copy', () {
    final src = File(_source);
    if (!src.existsSync()) return;
    expect(File(_copy).readAsBytesSync(), src.readAsBytesSync());
  });

  group('PhoneGuard', () {
    test('10 digits in a row is a phone', () => expect(PhoneGuard.hasPhone('Call 9876543210'), isTrue));
    test('spaces, dashes, dots and brackets are removed first', () {
      expect(PhoneGuard.hasPhone('98765 43210'), isTrue);
      expect(PhoneGuard.hasPhone('(987) 654-32.10'), isTrue);
    });
    test('9 digits is not a phone', () => expect(PhoneGuard.hasPhone('Room 123456789'), isFalse));
    test('empty and null are not a phone', () {
      expect(PhoneGuard.hasPhone(''), isFalse);
      expect(PhoneGuard.hasPhone(null), isFalse);
    });
    test('words keep digit runs apart', () => expect(PhoneGuard.hasPhone('12345 rooms 67890'), isFalse));
  });
}
