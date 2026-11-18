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
}
