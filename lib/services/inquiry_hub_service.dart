import 'package:get/get.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/inquiry_controller.dart';
import 'hub_session_manager.dart';
import 'storage_service.dart';

/// Same infinite-backoff shape as WalletHubService's own _WalletReconnectPolicy (itself copied
/// from ChatHubService's) — copied rather than shared, matching this codebase's per-hub-file
/// convention. See WalletHubService's comment for why the package's own DefaultRetryPolicy isn't
/// used (it eventually gives up permanently).
class _InquiryReconnectPolicy implements IRetryPolicy {
  static const _delaysMs = [0, 2000, 5000, 10000, 15000, 30000];

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    final i = retryContext.previousRetryCount;
    return i < _delaysMs.length ? _delaysMs[i] : _delaysMs.last;
  }
}

/// One persistent connection for the whole session lifetime (like WalletHubService, not the
/// district-scoped reconnect-per-URL pattern BannerHubService uses — an inquiry status change is
/// a pure per-user event, never scoped to anything narrower). Push-only: the server never expects
/// this client to invoke any hub method, so there's no conversation-style join/leave surface.
///
/// Delivers live InquiryStatusChanged events for status/agent changes an admin made (this device
/// never initiates a status change itself — only admins do, via the admin app). This is the live,
/// app-open half of the dual push pattern; InquiryStatusPushWorkerService/FCM is the other half,
/// covering a backgrounded/killed app. If this never connects (network/firewall/old build), the
/// app is not left worse off than before this feature existed — status changes just fall back to
/// becoming visible on the next screen visit or pull-to-refresh, same as WalletHubService's own
/// fallback story.
class InquiryHubService extends GetxService {
  static InquiryHubService get to => Get.find();

  HubConnection? _connection;
  Future<void>? _connecting;

  Future<void> connect() {
    if (_connection?.state == HubConnectionState.Connected) return Future.value();
    return _connecting ??= _doConnect().whenComplete(() => _connecting = null);
  }

  Future<void> _doConnect() async {
    if (StorageService.getToken() == null || isHubSessionLoggingOut) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/inquiry',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: _InquiryReconnectPolicy())
        .build();

    _connection!.on('InquiryStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final inquiryId = data['inquiryId'] as String?;
        final status = data['status'] as String?;
        if (inquiryId == null || status == null) return;
        Get.find<InquiryController>().applyStatusUpdate(inquiryId: inquiryId, status: status);
      } catch (_) {}
    });

    _connection!.onreconnected(({String? connectionId}) async {
      // Resync in case any push was missed while disconnected — InquiryRepository is
      // deliberately uncached (see its own doc comment), so this is already a fresh fetch with
      // nothing further to bypass.
      Get.find<InquiryController>().loadMyInquiries();
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Connection failed — nothing further to fall back to here beyond the existing
      // pull-based refresh; locally-initiated inquiry submissions still update instantly via
      // the direct applyStatusUpdate() call from their own REST response.
      _connection = null;
    }
  }

  /// Only called from logout/account-deletion — mirrors WalletHubService/ChatHubService.
  Future<void> disconnect() async {
    try {
      _connection?.off('InquiryStatusChanged');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _connecting = null;
  }
}
