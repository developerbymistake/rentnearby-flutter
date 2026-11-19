import 'package:bakhli/features/trip/utils/trip_name_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clean trims, collapses inner spaces and drops control characters', () {
    expect(TripNameRules.clean('  Goa   with\tfriends \n'), 'Goa with friends');
    expect(TripNameRules.clean('a\u0000b'), 'ab');
    expect(TripNameRules.clean('   '), '');
  });

  test('valid range is 1 to 60 after clean', () {
    expect(TripNameRules.isValid(''), isFalse);
    expect(TripNameRules.isValid('   '), isFalse);
    expect(TripNameRules.isValid('a'), isTrue);
    expect(TripNameRules.isValid('a' * 60), isTrue);
    expect(TripNameRules.isValid('a' * 61), isFalse);
    expect(TripNameRules.isValid('  ${'a' * 60}  '), isTrue);
  });

  test('suggestion_matches_the_mock_for_an_uttarakhand_city', () {
    final s = TripNameRules.suggest('Uttarakhand', 'Nainital');
    expect(s, 'Uttarakhand Hills Trip');
    expect(s.length, 22);
    expect(TripNameRules.suggest('Himachal Pradesh', 'Manali'), 'Himachal Pradesh Hills Trip');
  });

  test('suggestion_for_another_state_and_for_no_state', () {
    expect(TripNameRules.suggest('Rajasthan', 'Jaipur'), 'Rajasthan Trip');
    expect(TripNameRules.suggest('', 'Jaipur'), 'Jaipur Trip');
    expect(TripNameRules.suggest('  ', 'Jaipur'), 'Jaipur Trip');
  });

  test('suggestion_is_cut_to_60', () {
    final s = TripNameRules.suggest('A' * 80, 'x');
    expect(s.length, lessThanOrEqualTo(60));
    expect(TripNameRules.isValid(s), isTrue);
    expect(TripNameRules.suggest('', 'B' * 90).length, 60);
  });

  group('same cases as the server TripNameTests', () {
    for (final name in [
      '\u200B',
      '\u200B\u200B\u200B',
      'Trip\u200BName',
      'Trip \u202Eeman',
      'Trip\uE000',
      'Trip\u200D',
      'a\u200Db',
      '!!!',
      '- - -',
      '\u{1F3D4}\uFE0F',
      'https://spam.example',
      'Book at http://spam.example now',
      'www.spam.example trip',
      'Trip WWW.SPAM.EXAMPLE',
    ]) {
      test('rejects ${name.runes.map((r) => r.toRadixString(16)).join(' ')}', () {
        expect(TripNameRules.isValid(name), isFalse);
        expect(TripNameRules.problem(name), 'Use letters or numbers. No links.');
      });
    }

    for (final name in [
      'Family \u{1F468}\u200D\u{1F469}\u200D\u{1F467} trip',
      'Manali \u{1F3D4}\uFE0F 2026',
      '\u092E\u0928\u093E\u0932\u0940 \u092F\u093E\u0924\u094D\u0930\u093E',
      'Day 2',
      '7',
    ]) {
      test('keeps ${name.runes.map((r) => r.toRadixString(16)).join(' ')}', () {
        expect(TripNameRules.isValid(name), isTrue);
        expect(TripNameRules.clean(name), name);
      });
    }

    test('breaks and other spaces are cleaned before sending, so the server gets a valid name', () {
      expect(TripNameRules.clean('Trip\nName'), 'Trip Name');
      expect(TripNameRules.clean('Trip \u0085'), 'Trip');
      expect(TripNameRules.clean('Trip\uFEFF'), 'Trip');
      expect(TripNameRules.clean('Trip\u2028Name'), 'Trip Name');
      expect(TripNameRules.clean('\u00A0Hills\u3000\u2003Trip '), 'Hills Trip');
    });

    test('empty asks for a name', () {
      expect(TripNameRules.problem('  '), 'Add a name to continue');
    });
  });
}
