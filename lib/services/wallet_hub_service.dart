import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/wallet_controller.dart';
import 'hub_connection_shared.dart';
import 'hub_session_manager.dart';
import 'storage_service.dart';

/// One persistent connection for the whole session lifetime (like ChatHubService, not the
/// district-scoped reconnect-per-URL pattern BannerHubService uses — a wallet balance is a pure
/// per-user value, never scoped to anything narrower). Push-only: the server never expects this
/// client to invoke any hub method, so there's no conversation-style join/leave surface.
///
/// Delivers live WalletBalanceChanged events for balance changes this device didn't itself
/// initiate (admin credit/debit, a Razorpay webhook fallback credit). Locally-initiated spends
/// (Go-Live, purchase, redeem) are already reflected instantly via WalletController
/// .applyBalanceUpdate() being called directly from their own REST response — this hub is a
/// second, independent path into that same funnel, not the only one. If it never connects
/// (network/firewall/old build), the app is not left worse off than before this feature existed:
/// locally-initiated spends are unaffected, and remote changes just fall back to becoming visible
/// on the next screen visit or pull-to-refresh.
class WalletHubService extends GetxService with SingleFlightHubConnect {
  static WalletHubService get to => Get.find();

  HubConnection? _connection;

  @override
  HubConnection? get currentConnection => _connection;

  @override
  Future<void> performConnect() async {
    if (StorageService.getToken() == null || isHubSessionLoggingOut) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/wallet',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: const HubReconnectPolicy())
        .build();

    _connection!.on('WalletBalanceChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final balance = (data['balance'] as num?)?.toInt();
        if (balance == null) return;
        Get.find<WalletController>().applyBalanceUpdate(balance, reason: data['reason'] as String?);
      } catch (_) {}
    });

    _connection!.onreconnected(({String? connectionId}) async {
      // Resync in case any push was missed while disconnected — force-bypasses the repository's
      // TTL cache since a stale value could otherwise survive right through the reconnect.
      Get.find<WalletController>().loadBalance(forceRefresh: true);
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Connection failed — locally-initiated balance updates still work via the direct
      // applyBalanceUpdate() call from each mutation's own response; nothing further to fall
      // back to here for remotely-initiated ones beyond the existing pull-based refresh.
      _connection = null;
    }
  }

  /// Only called from logout/account-deletion — mirrors ChatHubService/BannerHubService.
  Future<void> disconnect() async {
    try {
      _connection?.off('WalletBalanceChanged');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    resetConnecting();
  }
}
