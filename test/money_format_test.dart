import 'package:bakhli/features/jobs/models/job_summary_model.dart';
import 'package:bakhli/models/browse_item.dart';
import 'package:bakhli/models/listing_model.dart';
import 'package:bakhli/utils/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact uses Indian grouping', () {
    expect(Money.exact(0), '₹0');
    expect(Money.exact(999), '₹999');
    expect(Money.exact(1000), '₹1,000');
    expect(Money.exact(4950), '₹4,950');
    expect(Money.exact(9999), '₹9,999');
    expect(Money.exact(99999), '₹99,999');
    expect(Money.exact(100000), '₹1,00,000');
    expect(Money.exact(199999), '₹1,99,999');
    expect(Money.exact(12345678), '₹1,23,45,678');
    expect(Money.exact(-4950), '-₹4,950');
  });

  test('short never rounds: a unit only when it is exact', () {
    expect(Money.short(0), '₹0');
    expect(Money.short(999), '₹999');
    expect(Money.short(1000), '₹1k');
    expect(Money.short(4950), '₹4,950');
    expect(Money.short(8500), '₹8.5k');
    expect(Money.short(9999), '₹9,999');
    expect(Money.short(99999), '₹99,999');
    expect(Money.short(100000), '₹1L');
    expect(Money.short(125000), '₹1.25L');
    expect(Money.short(150000), '₹1.5L');
    expect(Money.short(199999), '₹1,99,999');
    expect(Money.short(10000000), '₹1Cr');
    expect(Money.short(12345000), '₹123.45L');
    expect(Money.short(-1500), '-₹1.5k');
  });

  test('ranges share the unit when both sides have it', () {
    expect(Money.shortRange(8000, 12000), '₹8-12k');
    expect(Money.shortRange(500, 1500), '₹500 - 1.5k');
    expect(Money.shortRange(8000, 150000), '₹8k - 1.5L');
    expect(Money.shortRange(9999, 12000), '₹9,999 - 12k');
  });

  test('every screen shows the same exact rent', () {
    final nearby = NearbyListingModel.fromJson({
      'id': 'a',
      'priceMonthly': 9999,
      'latitude': 29.2,
      'longitude': 79.5,
      'distanceKm': 1.2,
    });
    expect(nearby.shortPrice, '₹9,999');
    expect(BrowseItem.inr(4950), '₹4,950');
    expect(BrowseItem.inr(150000), '₹1,50,000');
  });

  test('job salary chip', () {
    expect(jobSalaryCompact(0, 0), 'Negotiable');
    expect(jobSalaryCompact(9999, 9999), '₹9,999');
    expect(jobSalaryCompact(8000, 12000), '₹8-12k');
    expect(jobSalaryCompact(0, 9500), '₹9.5k');
  });
}
