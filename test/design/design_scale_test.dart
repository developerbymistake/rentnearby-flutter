import 'package:bakhli/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DS.debugReset);

  group('identity', () {
    test('every helper returns the raw value', () {
      DS.debugReset();
      expect(DS.s(10), 10);
      expect(DS.f(7), 7);
      expect(DS.gv(16), 16);
      expect(DS.gh(16), 16);
      expect(DS.radius(8), 8);
      expect(DS.shadowBlur(10), 10);
    });

    test('scaled:false never scales', () {
      DS.applyApproved();
      expect(DS.s(10, scaled: false), 10);
      expect(DS.f(14, scaled: false), 14);
      expect(DS.gv(16, scaled: false), 16);
    });
  });

  group('approved values', () {
    setUp(DS.applyApproved);

    test('size and font are 0.80', () {
      expect(DS.s(100), closeTo(80, 1e-9));
      expect(DS.f(20), closeTo(16, 1e-9));
      expect(DS.radius(10), closeTo(8, 1e-9));
    });

    test('gap is size x gapRel = 0.72', () {
      expect(DS.gapV, closeTo(0.72, 1e-9));
      expect(DS.gapH, closeTo(0.72, 1e-9));
      expect(DS.gv(100), closeTo(72, 1e-9));
      expect(DS.gh(100), closeTo(72, 1e-9));
    });

    test('font never goes below the floor and never grows past its original size', () {
      expect(DS.fontFloor, 10);
      expect(DS.f(12), 10);
      expect(DS.f(9), 9);
      expect(DS.f(13), closeTo(10.4, 1e-9));
    });

    test('font stays <= size so text cannot clip', () {
      expect(DS.font <= DS.size, isTrue);
    });
  });

  test('debugReset restores identity', () {
    DS.applyApproved();
    DS.debugReset();
    expect(DS.size, 1.0);
    expect(DS.font, 1.0);
    expect(DS.gapV, 1.0);
  });
}
