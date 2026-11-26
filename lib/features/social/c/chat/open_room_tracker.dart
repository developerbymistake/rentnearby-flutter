import 'package:get/get.dart';

import '../../../../config/app_routes.dart';

abstract final class OpenRoomTracker {
  static final List<String> _open = [];
  static final RxnString top = RxnString();

  static String? get current => _open.isEmpty ? null : _open.last;

  static void open(String roomId) {
    _open.add(roomId);
    top.value = current;
  }

  static void close(String roomId) {
    final i = _open.lastIndexOf(roomId);
    if (i >= 0) _open.removeAt(i);
    top.value = current;
  }

  static void clear() {
    _open.clear();
    top.value = null;
  }

  static bool isOpen(String actionRoute, Map<String, dynamic>? args) {
    final open = current;
    if (open == null || actionRoute != AppRoutes.dmRoom) return false;
    return args?['roomId']?.toString() == open;
  }
}
