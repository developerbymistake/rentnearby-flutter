import '../../../config/notification_types.dart';

typedef OwnerPushHandler = void Function(String type, Map<String, dynamic> args);

abstract final class OwnerPushSync {
  static final Map<String, OwnerPushHandler> _handlers = {};

  static void register(String name, OwnerPushHandler handler) => _handlers[name] = handler;

  static void unregister(String name) => _handlers.remove(name);

  static void reset() => _handlers.clear();

  static void onPush(String? type, String? route, Map<String, dynamic>? args) {
    if (type == null || !NotificationTypeKeys.isOwnerWork(type)) return;
    final a = <String, dynamic>{...?args, 'route': ?route};
    for (final h in List.of(_handlers.values)) {
      try {
        h(type, a);
      } catch (_) {}
    }
  }
}
