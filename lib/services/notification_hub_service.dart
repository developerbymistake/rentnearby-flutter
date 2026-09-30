import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/notification_controller.dart';
import 'hub_connection_shared.dart';
import 'hub_session_manager.dart';
import 'storage_service.dart';

/// Session-lifetime, push-only connection (like WalletHubService) delivering the generic
/// NotificationReceived envelope that drives the Home bell.
class NotificationHubService extends GetxService with SingleFlightHubConnect {
  static NotificationHubService get to => Get.find();

  HubConnection? _connection;

  @override
  HubConnection? get currentConnection => _connection;

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
      } catch (_) {}
    });

    try {
      await _connection!.start();
    } catch (_) {
      _connection = null;
    }
  }

  /// Only called from logout/account-deletion — mirrors WalletHubService/ChatHubService.
  Future<void> disconnect() async {
    try {
      _connection?.off('NotificationReceived');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    resetConnecting();
  }
}
