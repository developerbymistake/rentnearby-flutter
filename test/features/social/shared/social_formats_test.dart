import 'package:bakhli/features/social/shared/social_formats.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/social_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('when', () {
    expect(SocialFormats.when(const TripWhen(kind: 'within', months: 2)), 'Within 2 months');
    expect(SocialFormats.when(const TripWhen(kind: 'within', months: 1)), 'Within a month');
    expect(SocialFormats.when(const TripWhen(kind: 'within', months: 0)), 'Within a month');
    expect(SocialFormats.when(const TripWhen(kind: 'month', month: 202612)), 'December');
  });

  test('days, who can join, seats', () {
    expect(SocialFormats.days(4), '4 days');
    expect(SocialFormats.days(1), '1 day');
    expect(SocialFormats.days(11), '10+ days');
    expect(SocialFormats.whoCanJoin('A'), 'Anyone');
    expect(SocialFormats.whoCanJoin('M'), 'Men only');
    expect(SocialFormats.whoCanJoin('F'), 'Women only');
    expect(SocialFormats.seatsLeft(3, 3), '3 seats left');
    expect(SocialFormats.seatsLeft(1, 2), '1 seat left');
    expect(SocialFormats.seatsLeft(9, 11), '4+ seats left');
    expect(SocialFormats.seatsLeft(0, 3), 'Full');
  });

  test('cities and short name', () {
    expect(SocialFormats.cities(['Manali']), 'Manali');
    expect(SocialFormats.cities(['Kasol', 'Tosh']), 'Kasol and Tosh');
    expect(SocialFormats.cities(['A', 'B', 'C']), 'A, B and C');
    expect(SocialFormats.cities([]), '');
    expect(SocialFormats.shortName('Kavya Sharma'), 'Kavya S.');
    expect(SocialFormats.shortName('Kavya'), 'Kavya');
    expect(SocialFormats.shortName('  '), '');
  });

  test('mutual lines hide at zero', () {
    expect(SocialStrings.mutualsLine(Mutuals.none), '');
    expect(SocialStrings.mutualsLine(const Mutuals(count: 1, names: ['Aman'])), 'Followed by Aman');
    expect(SocialStrings.mutualsLine(const Mutuals(count: 4, names: ['Aman'])), 'Followed by Aman and 3 others you know');
    expect(SocialStrings.mutualsLine(const Mutuals(count: 2, names: ['Aman'])), 'Followed by Aman and 1 other you know');
    expect(SocialStrings.mutualCount(2), '2 mutual');
  });

  test('maskPhone keeps the first two and last two digits', () {
    expect(SocialFormats.maskPhone('9897012345'), '98xxxxxx45');
    expect(SocialFormats.maskPhone('9876543210'), '98xxxxxx10');
    expect(SocialFormats.maskPhone('1234'), '1234');
    expect(SocialFormats.maskPhone(''), '');
  });

  test('dayMonth gives day and short month in local time', () {
    final d = DateTime(2026, 12, 11, 12);
    expect(SocialFormats.dayMonth(d), '11 Dec');
    expect(SocialFormats.dayMonth(DateTime(2026, 1, 3, 12)), '3 Jan');
  });
}
