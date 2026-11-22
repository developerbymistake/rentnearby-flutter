import 'dart:async';

import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../config/notification_types.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/plan_controller.dart';
import '../features/buddy/buddy_live.dart';
import '../features/owner_core/session/owner_push_sync.dart';
import '../features/stay/stay_status_sync.dart';
import '../features/taxi/taxi_status_sync.dart';
import '../models/notification_model.dart';
import 'hub_connection_shared.dart';
import 'hub_session_manager.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'trip_push_sync.dart';

class TaxiRequestSignal {
  final String requestId;
  final int? version;
  final bool reconnected;

  const TaxiRequestSignal({required this.requestId, this.version, this.reconnected = false});
}

abstract interface class TaxiRequestRealtime {
  void subscribeTaxiRequest(String requestId, void Function(TaxiRequestSignal signal) onEvent);

  void unsubscribeTaxiRequest(String requestId);
}

class TaxiRequestSubscriptions implements TaxiRequestRealtime {
  TaxiRequestSubscriptions(this._send);

  static const String subscribeMethod = 'SubscribeTaxiRequest';
  static const String unsubscribeMethod = 'UnsubscribeTaxiRequest';
  static const String changedEvent = 'TaxiRequestChanged';
  static const int knownVersion = 1;

  final Future<void> Function(String method, String requestId) _send;
  final Map<String, void Function(TaxiRequestSignal)> _handlers = {};

  bool isSubscribed(String requestId) => _handlers.containsKey(requestId);

  @override
  void subscribeTaxiRequest(String requestId, void Function(TaxiRequestSignal signal) onEvent) {
    _handlers[requestId] = onEvent;
    unawaited(_send(subscribeMethod, requestId));
  }

  @override
  void unsubscribeTaxiRequest(String requestId) {
    if (_handlers.remove(requestId) != null) unawaited(_send(unsubscribeMethod, requestId));
  }

  // A new or reconnected connection lost every group, and events may have been missed meanwhile.
  void onConnected() {
    for (final e in [..._handlers.entries]) {
      unawaited(_send(subscribeMethod, e.key));
      e.value(TaxiRequestSignal(requestId: e.key, reconnected: true));
    }
  }

  void onEvent(Object? raw) {
    if (raw is! Map) return;
    final v = raw['v'];
    final id = raw['requestId'];
    if (v is! num || v.toInt() != knownVersion || id is! String) return;
    final version = raw['version'];
    _handlers[id]?.call(TaxiRequestSignal(requestId: id, version: version is num ? version.toInt() : null));
  }

  void clear() => _handlers.clear();
}

/// Session-lifetime, push-only connection (like ChatHubService) delivering the generic
/// NotificationReceived envelope that drives the Home bell.
class NotificationHubService extends GetxService with SingleFlightHubConnect implements TaxiRequestRealtime {
  static NotificationHubService get to => Get.find();

  HubConnection? _connection;

  late final TaxiRequestSubscriptions taxiRequests = TaxiRequestSubscriptions(_invoke);

  Future<void> _invoke(String method, String requestId) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) return;
    try {
      await c.invoke(method, args: [requestId]);
    } catch (_) {}
  }

  @override
  void subscribeTaxiRequest(String requestId, void Function(TaxiRequestSignal signal) onEvent) =>
      taxiRequests.subscribeTaxiRequest(requestId, onEvent);

  @override
  void unsubscribeTaxiRequest(String requestId) => taxiRequests.unsubscribeTaxiRequest(requestId);

  @override
  HubConnection? get currentConnection => _connection;

  // Put only by MainScreen.initState, so onReady is the first frame with main mounted.
  @override
  void onReady() {
    super.onReady();
    NotificationService.to.markMainReady();
  }

  @override
  Future<void> performConnect() async {
    if (StorageService.getToken() == null || isHubSessionLoggingOut) return;

    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
    }

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/notification',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: const HubReconnectPolicy())
        .build();

    _connection!.on('NotificationReceived', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        Get.find<NotificationController>().applyLiveNotification(data);
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().onPushNotification(data['type'] as String?);
        final hubArgs = NotificationModel.parseArguments(data['actionArguments']);
        TripPushSync.onPush(data['type'] as String?, data['actionRoute'] as String?, hubArgs);
        OwnerPushSync.onPush(NotificationTypeKeys.toWire(data['type'] as String?), data['actionRoute'] as String?, hubArgs);
        if (data['type'] == NotificationTypeKeys.roleRequestApproved) {
          Get.find<AuthController>().forceLogout(reason: LogoutReason.roleChanged);
        } else if (data['type'] == NotificationTypeKeys.roleRequestRejected) {
          Get.find<AuthController>().refreshProfile();
        } else if (data['type'] == NotificationTypeKeys.profilePhotoRemoved) {
          Get.find<AuthController>().refreshProfile();
        } else if (data['type'] == NotificationTypeKeys.stayApproved ||
            data['type'] == NotificationTypeKeys.stayRejected) {
          StayStatusSync.onReviewResult();
        } else if (data['type'] == NotificationTypeKeys.taxiApproved ||
            data['type'] == NotificationTypeKeys.taxiRejected) {
          TaxiStatusSync.onReviewResult();
        }
      } catch (_) {}
    });

    _connection!.on(TaxiRequestSubscriptions.changedEvent, (args) {
      if (args == null || args.isEmpty) return;
      taxiRequests.onEvent(args[0]);
    });

    for (final event in BuddyHubEvents.all) {
      _connection!.on(event, (args) {
        if (args == null || args.isEmpty || args[0] is! Map) return;
        BuddyPushSync.onHubEvent(event, Map<String, dynamic>.from(args[0] as Map));
      });
    }

    _connection!.onreconnected(({String? connectionId}) => taxiRequests.onConnected());

    try {
      await _connection!.start();
      taxiRequests.onConnected();
    } catch (_) {
      _connection = null;
    }
  }

  /// Only called from logout/account-deletion — mirrors ChatHubService.
  Future<void> disconnect() async {
    try {
      _connection?.off('NotificationReceived');
      _connection?.off(TaxiRequestSubscriptions.changedEvent);
      for (final event in BuddyHubEvents.all) {
        _connection?.off(event);
      }
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    taxiRequests.clear();
    resetConnecting();
  }
}
