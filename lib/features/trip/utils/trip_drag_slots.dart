import 'dart:ui';

// Mirrors the vertical forward branch of SliverReorderableListState._dragUpdateItems; a parity test guards it.
class TripDragSlots {
  static double gapShift(int i, int from, int insert, double extent) {
    if (insert < from && i < from && i >= insert) return extent;
    if (insert > from && i > from && i < insert) return -extent;
    return 0;
  }

  static int next({required List<Rect> rows, required int from, required int insert, required double proxyTop}) {
    final extent = rows[from].height;
    final proxyEnd = proxyTop + extent;
    var n = insert;
    for (var i = 0; i < rows.length; i++) {
      final start = rows[i].top + gapShift(i, from, insert, extent);
      final end = start + rows[i].height;
      final mid = start + rows[i].height / 2;
      if (i == from) {
        if (mid <= proxyEnd && proxyEnd <= end) n = from;
      } else if (start <= proxyTop && proxyTop <= mid) {
        n = i;
        break;
      } else if (mid <= proxyEnd && proxyEnd <= end) {
        n = i + 1;
        break;
      } else if (end < proxyTop && n < i + 1) {
        n = i + 1;
      } else if (proxyEnd < start && n > i) {
        n = i;
      }
    }
    return n;
  }

  static int position(int insert, int from) => insert > from ? insert - 1 : insert;

  static int displayIndex(int i, int from, int slot) {
    if (i == from) return slot;
    if (from < slot && i > from && i <= slot) return i - 1;
    if (slot < from && i >= slot && i < from) return i + 1;
    return i;
  }

  static int crossDayIndex(List<Rect> rows, double proxyMiddle) {
    var n = 0;
    for (final r in rows) {
      if (r.center.dy < proxyMiddle) n++;
    }
    return n;
  }
}
