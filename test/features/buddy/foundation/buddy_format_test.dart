import 'package:bakhli/features/buddy/shared/buddy_format.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyPerson _p(String name, String last4, {bool me = false, String status = 'Joined'}) =>
    MoneyPerson(userId: name, name: name, last4: last4, initial: name[0], isMe: me, status: status);

void main() {
  test('rupees use Indian grouping', () {
    expect(BuddyFormat.rupees(11816), '₹11,816');
    expect(BuddyFormat.rupees(500000), '₹5,00,000');
    expect(BuddyFormat.rupees(900), '₹900');
    expect(BuddyFormat.rupees(0), '₹0');
  });

  test('last4 and money names', () {
    expect(BuddyFormat.last4('Bakhli#48291736'), '1736');
    expect(BuddyFormat.last4(null), '');
    expect(BuddyFormat.moneyName(_p('Rahul', '1736')), 'Rahul 1736');
    expect(BuddyFormat.moneyName(_p('Gone', '', status: 'Deleted')), 'Deleted user');
    expect(BuddyFormat.moneyName(_p('Aman', '')), 'Aman');
  });

  test('dates', () {
    expect(BuddyFormat.dateRange(DateTime(2026, 5, 16), DateTime(2026, 5, 22)), '16 – 22 May');
    expect(BuddyFormat.dateRange(DateTime(2026, 5, 28), DateTime(2026, 6, 2)), '28 May – 2 Jun');
    expect(BuddyFormat.dateRange(null, null), '');
    expect(BuddyFormat.dayMonth(DateTime(2026, 5, 16)), '16 May');
    expect(BuddyFormat.dayHeader(4, DateTime(2026, 5, 19)), 'DAY 4 · 19 MAY');
    expect(BuddyFormat.weekdayDate(DateTime(2026, 5, 16)), 'Sat 16 May');
  });

  test('ago', () {
    final now = DateTime.utc(2026, 5, 16, 12);
    expect(BuddyFormat.ago(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(BuddyFormat.ago(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(BuddyFormat.ago(now.subtract(const Duration(hours: 2)), now: now), '2 h ago');
    expect(BuddyFormat.ago(now.subtract(const Duration(days: 3)), now: now), '3 days ago');
    expect(BuddyFormat.ago(now.subtract(const Duration(days: 14)), now: now), '2 weeks ago');
    expect(BuddyFormat.agoParts(now.subtract(const Duration(minutes: 5)), now: now), ('5', 'min ago'));
  });

  test('time, plural, expiry', () {
    expect(BuddyFormat.time12('09:00'), '9:00 am');
    expect(BuddyFormat.time12('16:30'), '4:30 pm');
    expect(BuddyFormat.time12('00:05'), '12:05 am');
    expect(BuddyFormat.plural(1, 'traveller', 'travellers'), '1 traveller');
    expect(BuddyFormat.plural(3, 'traveller', 'travellers'), '3 travellers');
    final now = DateTime(2026, 5, 16, 10);
    expect(BuddyFormat.expiresIn(DateTime(2026, 5, 30, 10), now: now), 'Expires in 14 days');
    expect(BuddyFormat.expiresIn(DateTime(2026, 5, 16, 23), now: now), 'Expires today');
  });

  test('avatar gradient is stable per user', () {
    final a = BuddyLook.avatarIndex('22222222-2222-4222-8222-222222222222');
    expect(BuddyLook.avatarIndex('22222222-2222-4222-8222-222222222222'), a);
    expect(a, inInclusiveRange(0, 5));
  });
}
