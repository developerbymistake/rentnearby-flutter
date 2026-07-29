import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/agent_controller.dart';
import '../controllers/enquiry_controller.dart';
import '../controllers/notification_controller.dart';
import 'hub_connection_shared.dart';
import 'hub_session_manager.dart';
import 'storage_service.dart';

/// One persistent connection for the whole session lifetime (like WalletHubService, not the
/// district-scoped reconnect-per-URL pattern BannerHubService uses — an enquiry status change is
/// a pure per-user event, never scoped to anything narrower). Push-only: the server never expects
/// this client to invoke any hub method, so there's no conversation-style join/leave surface.
///
/// Delivers live EnquiryStatusChanged events for status/agent changes an admin made (this device
/// never initiates a status change itself — only admins do, via the admin app). This is the live,
/// app-open half of the dual push pattern; EnquiryStatusPushWorkerService/FCM is the other half,
/// covering a backgrounded/killed app. If this never connects (network/firewall/old build), the
/// app is not left worse off than before this feature existed — status changes just fall back to
/// becoming visible on the next screen visit or pull-to-refresh, same as WalletHubService's own
/// fallback story.
class EnquiryHubService extends GetxService with SingleFlightHubConnect {
  static EnquiryHubService get to => Get.find();

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
          '${AppConstants.serverUrl}/hubs/enquiry',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: const HubReconnectPolicy())
        .build();

    _connection!.on('EnquiryStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final enquiryId = data['enquiryId'] as String?;
        final status = data['status'] as String?;
        if (enquiryId == null || status == null) return;
        // Both funnels are safe to call unconditionally for every push: each is scoped to its own
        // controller's own lists (a consumer's myEnquiries vs an agent's myLeads) and is a no-op
        // when the id isn't present there — e.g. a plain consumer receiving this always no-ops in
        // AgentController since myLeads is empty for a non-agent. NotifyCoAssignedAgentsOfStatusChangeAsync
        // (backend) is what actually addresses this event to an agent's own user_{id} group in the
        // first place — this is the client-side half that was previously missing entirely.
        Get.find<EnquiryController>().applyStatusUpdate(enquiryId: enquiryId, status: status);
        Get.find<AgentController>().applyLeadStatusUpdate(enquiryId, status);
      } catch (_) {}
    });

    // Generic NotificationEvent delivery (see EnquiryHandlers.PushNotificationReceivedAsync) —
    // today's only producer is Agent lead-assignment, but the event name/shape is meant to be
    // reused by future NotificationEvent producers too. Every event unconditionally reaches the
    // Home-bell inbox (NotificationController.applyLiveNotification) since that's a generic
    // envelope-shaped feature by design; AgentController.applyLeadAssigned() stays gated to
    // type == 'LeadAssigned' specifically, since it patches Agent-only state that a future
    // non-lead-assignment producer's event has no business touching.
    _connection!.on('NotificationReceived', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        Get.find<NotificationController>().applyLiveNotification(data);
        if (data['type'] == 'LeadAssigned') {
          Get.find<AgentController>().applyLeadAssigned();
        }
      } catch (_) {}
    });

    _connection!.onreconnected(({String? connectionId}) async {
      // Resync in case any push was missed while disconnected — EnquiryRepository is
      // deliberately uncached (see its own doc comment), so this is already a fresh fetch with
      // nothing further to bypass. fetchActiveCount() covers the badge specifically (cheap,
      // server-anchored) alongside the full list reload.
      Get.find<EnquiryController>().loadMyEnquiries();
      Get.find<EnquiryController>().fetchActiveCount();
      Get.find<AgentController>().checkAgentStatus();
      if (Get.find<AgentController>().myLeads.isNotEmpty) Get.find<AgentController>().loadMyLeads();
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Connection failed — nothing further to fall back to here beyond the existing
      // pull-based refresh; locally-initiated enquiry submissions still update instantly via
      // the direct applyStatusUpdate() call from their own REST response.
      _connection = null;
    }
  }

  /// Only called from logout/account-deletion — mirrors WalletHubService/ChatHubService.
  Future<void> disconnect() async {
    try {
      _connection?.off('EnquiryStatusChanged');
      _connection?.off('NotificationReceived');
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    resetConnecting();
  }
}
