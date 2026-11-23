import 'dart:ui';

import 'package:bakhli/features/trip/utils/trip_drag_slots.dart';
import 'package:flutter_test/flutter_test.dart';

List<Rect> rows(List<double> heights) {
  var top = 0.0;
  return [
    for (final h in heights) Rect.fromLTWH(0, (top += h) - h, 300, h),
  ];
}

int drag(List<Rect> r, int from, List<double> moves) {
  var insert = from;
  var dy = 0.0;
  for (final m in moves) {
    dy += m;
    insert = TripDragSlots.next(rows: r, from: from, insert: insert, proxyTop: r[from].top + dy);
  }
  return TripDragSlots.position(insert, from);
}

void main() {
  group('next', () {
    final r = rows([60, 60, 60, 60, 40]);

    test('past half of the next row moves one slot, short of half stays', () {
      expect(drag(r, 0, [25]), 0);
      expect(drag(r, 0, [35]), 1);
      expect(drag(r, 2, [-35]), 1);
      expect(drag(r, 2, [-25]), 2);
    });

    test('moving back gives the old slot', () {
      expect(drag(r, 0, [35, -10]), 0);
      expect(drag(r, 1, [40, 40, -80]), 1);
    });

    test('top and bottom clamp', () {
      expect(drag(r, 2, [-60, -60, -60, -60]), 0);
      expect(drag(r, 1, [60, 60, 60, 60, 60]), 4);
    });

    test('unequal rows: the short last row needs half of its own height', () {
      expect(drag(r, 3, [15]), 3);
      expect(drag(r, 3, [25]), 4);
      expect(drag(r, 4, [-35]), 3);
    });
  });

  test('displayIndex', () {
    final shown = [for (var i = 0; i < 5; i++) TripDragSlots.displayIndex(i, 1, 3) + 1];
    expect(shown, [1, 4, 2, 3, 5]);
    expect([for (var i = 0; i < 5; i++) TripDragSlots.displayIndex(i, 3, 1) + 1], [1, 3, 4, 2, 5]);
    expect([for (var i = 0; i < 3; i++) TripDragSlots.displayIndex(i, 1, 1) + 1], [1, 2, 3]);
  });

  test('crossDayIndex', () {
    final r = rows([60, 60, 60]);
    expect(TripDragSlots.crossDayIndex(r, -10), 0);
    expect(TripDragSlots.crossDayIndex(r, 20), 0);
    expect(TripDragSlots.crossDayIndex(r, 31), 1);
    expect(TripDragSlots.crossDayIndex(r, 100), 2);
    expect(TripDragSlots.crossDayIndex(r, 500), 3);
    expect(TripDragSlots.crossDayIndex(const [], 50), 0);
  });
}
