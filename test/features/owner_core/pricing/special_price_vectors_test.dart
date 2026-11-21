import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/owner_core/json/owner_dates.dart';
import 'package:bakhli/features/owner_core/pricing/special_price_math.dart';
import 'package:flutter_test/flutter_test.dart';

const _copy = 'test/features/owner_core/vectors/special_price_vectors.json';
const _source =
    r'F:\Dhasu\Buddy_resume\owner_build\vectors\special_price_vectors.json';

Map<String, dynamic> _load() =>
    jsonDecode(File(_copy).readAsStringSync()) as Map<String, dynamic>;

List<PriceRule> _rules(Object? raw) => [
  for (final r in (raw as List? ?? const []).cast<Map<String, dynamic>>())
    if (r['paused'] != true && r['pausedByPlan'] != true)
      PriceRule(
        from: OwnerDates.day(r['from'])!,
        to: OwnerDates.day(r['to'])!,
        lower: r['direction'] == 'Lower',
        percent: (r['percent'] as num).toInt(),
      ),
];

void main() {
  final v = _load();

  group('adjust', () {
    for (final c in (v['adjust'] as List).cast<Map<String, dynamic>>()) {
      test(
        '${c['base']} ${c['direction']} ${c['percent']}% = ${c['expected']}',
        () {
          expect(
            SpecialPriceMath.adjust(
              (c['base'] as num).toInt(),
              c['direction'] == 'Lower',
              (c['percent'] as num).toInt(),
            ),
            c['expected'],
          );
        },
      );
    }
  });

  group('totals', () {
    for (final c in (v['totals'] as List).cast<Map<String, dynamic>>()) {
      test('${c['name']}', () {
        final base = (c['base'] as num).toInt();
        final checkIn = OwnerDates.day(c['checkIn'])!;
        final checkOut = OwnerDates.day(c['checkOut'])!;
        final nights = checkOut.difference(checkIn).inDays;
        final rules = _rules(c['rules']);
        for (final n in (c['nights'] as List).cast<Map<String, dynamic>>()) {
          expect(
            SpecialPriceMath.priceOn(base, OwnerDates.day(n['date'])!, rules),
            n['price'],
            reason: '${n['date']}',
          );
        }
        expect(
          SpecialPriceMath.total(base, checkIn, nights, rules),
          c['total'],
        );
      });
    }
  });

  group('optional groups (present from vector version 2)', () {
    for (final c
        in ((v['perNight'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
      test('perNight ${c['total']} / ${c['nights']}', () {
        expect(
          SpecialPriceMath.perNight(
            (c['total'] as num).toInt(),
            (c['nights'] as num).toInt(),
          ),
          c['expected'],
        );
      });
    }
    for (final c
        in ((v['fullOnDates'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
      test('fullOnDates ${c['checkIn']} x ${c['nights']}', () {
        final blocks = [
          for (final b in (c['blocks'] as List).cast<Map<String, dynamic>>())
            DateRange(OwnerDates.day(b['from'])!, OwnerDates.day(b['to'])!),
        ];
        expect(
          SpecialPriceMath.touchesBlock(
            OwnerDates.day(c['checkIn'])!,
            (c['nights'] as num).toInt(),
            blocks,
          ),
          c['expected'],
        );
      });
    }
  });

  test('perNight rounds to the nearest 10, a tie rounds up', () {
    expect(SpecialPriceMath.perNight(9600, 3), 3200);
    expect(SpecialPriceMath.perNight(10000, 3), 3330);
    expect(SpecialPriceMath.perNight(25, 1), 30);
    expect(SpecialPriceMath.perNight(1000, 0), 0);
  });

  test('lower chip only for a Lower rule touching the nights', () {
    final r = [
      PriceRule(
        from: DateTime(2026, 11, 6),
        to: DateTime(2026, 11, 6),
        lower: true,
        percent: 15,
      ),
    ];
    expect(
      SpecialPriceMath.lowerPercentFor(3000, DateTime(2026, 11, 5), 3, r),
      15,
    );
    expect(
      SpecialPriceMath.lowerPercentFor(3000, DateTime(2026, 11, 7), 2, r),
      isNull,
    );
    final h = [
      PriceRule(
        from: DateTime(2026, 11, 6),
        to: DateTime(2026, 11, 6),
        lower: false,
        percent: 15,
      ),
    ];
    expect(
      SpecialPriceMath.lowerPercentFor(3000, DateTime(2026, 11, 5), 3, h),
      isNull,
    );
  });

  test('check-out day is not a night for blocks', () {
    final b = [DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 12))];
    expect(SpecialPriceMath.touchesBlock(DateTime(2026, 11, 8), 2, b), isFalse);
    expect(SpecialPriceMath.touchesBlock(DateTime(2026, 11, 12), 1, b), isTrue);
    expect(SpecialPriceMath.touchesBlock(DateTime(2026, 11, 9), 2, b), isTrue);
  });

  test('the app copy equals the source vector file', () {
    final src = File(_source);
    if (!src.existsSync()) return;
    expect(File(_copy).readAsBytesSync(), src.readAsBytesSync());
  });
}
