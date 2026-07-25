import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../repositories/agent_repository.dart';
import '../services/inquiry_hub_service.dart';
import '../utils/app_toast.dart';

/// Owns "is this account an Agent, and what do they need to see" — checked once per session
/// (mirrors WalletController's onInit()-fetches-once pattern, not a live push), read reactively
/// from Profile/MyLeads/LeadDetail. [isAgent] stays false, silently, for the ~all users who aren't
/// one — never toasted, never treated as an error.
class AgentController extends GetxController {
  final isAgent = false.obs;
  final agentId = Rxn<String>();
  // Server-computed count of this agent's assigned, not-Closed leads that have changed since the
  // agent last viewed them ("unseen") — the "something new landed" badge count, not every open
  // lead. Entirely server-anchored via checkAgentStatus()/markLeadSeen(); never derived or
  // decremented locally (mirrors InquiryController.activeInquiryCount's equivalent consumer-side
  // design for the same reason — the client doesn't have the per-lead seen-timestamp needed to
  // replicate the formula).
  final pendingLeadCount = 0.obs;

  final myLeads = <InquiryModel>[].obs;
  final isLoadingLeads = false.obs;
  final Rxn<InquiryDetailModel> currentLeadDetail = Rxn<InquiryDetailModel>();
  final isLoadingLeadDetail = false.obs;
  final isUpdatingStatus = false.obs;

  AgentRepository get _repo => Get.find<AgentRepository>();

  @override
  void onInit() {
    super.onInit();
    checkAgentStatus();
  }

  Future<void> checkAgentStatus() async {
    try {
      final profile = await _repo.getMyAgentProfile();
      if (profile == null) {
        isAgent.value = false;
        return;
      }
      isAgent.value = true;
      agentId.value = profile['agentId'] as String?;
      pendingLeadCount.value = (profile['pendingLeadCount'] as num?)?.toInt() ?? 0;
      // Connect the Inquiry hub only once we actually know this account is an agent — chained
      // off this call's own completion rather than a synchronous check at app-start, since
      // isAgent isn't resolved yet at the point MainScreen.initState() runs. Also re-called on
      // every resume (see main_screen.dart) as a no-op-if-already-connected reconnect, covering
      // a connection that quietly died while backgrounded.
      InquiryHubService.to.connect();
    } catch (_) {
      // Best-effort background check — a network hiccup here just means the My Leads row stays
      // hidden this session, not a user-facing error.
      isAgent.value = false;
    }
  }

  Future<void> markLeadSeen(String id) async {
    try {
      await _repo.markLeadSeen(id);
      await checkAgentStatus();
    } catch (_) {}
  }

  Future<void> loadMyLeads() async {
    isLoadingLeads.value = true;
    try {
      myLeads.value = await _repo.getMyLeads();
    } catch (_) {
      AppToast.error('Could not load your leads. Pull to refresh.');
    } finally {
      isLoadingLeads.value = false;
    }
  }

  Future<void> loadLeadDetail(String id) async {
    isLoadingLeadDetail.value = true;
    try {
      final detail = await _repo.getLeadDetail(id);
      if (detail != null) currentLeadDetail.value = detail;
    } catch (_) {
      AppToast.error('Could not load lead details.');
    } finally {
      isLoadingLeadDetail.value = false;
    }
  }

  Future<bool> updateLeadStatus(String id, String status, {String? note}) async {
    isUpdatingStatus.value = true;
    try {
      final detail = await _repo.updateLeadStatus(id, status, note: note);
      if (detail == null) return false;

      currentLeadDetail.value = detail;
      final idx = myLeads.indexWhere((l) => l.id == id);
      if (idx != -1) {
        myLeads[idx] = myLeads[idx].copyWith(status: detail.status, updatedAt: detail.updatedAt);
      }
      // pendingLeadCount is entirely server-anchored (see its own doc comment) — re-fetch the
      // authoritative value instead of guessing at a local delta.
      await checkAgentStatus();
      return true;
    } on DioException catch (e) {
      AppToast.error(_errorMessage(e));
      return false;
    } catch (_) {
      AppToast.error('Could not update status. Please try again.');
      return false;
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  // Mirrors InquiryController._errorMessage's shape — surfaces the server's own message for an
  // expected 4xx (an invalid status transition, or the CONCURRENT_UPDATE 409 a co-assigned agent/
  // admin race can now produce) instead of collapsing every failure into one generic string, same
  // as ListingController/PlotController already do for their own CONCURRENT_UPDATE case.
  String _errorMessage(DioException e) {
    final status = e.response?.statusCode;
    String? message;
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      message = responseData['error']?['message'] as String? ?? responseData['message'] as String?;
    }
    if ((status == 400 || status == 409) && message != null) return message;
    return 'Could not update status. Please try again.';
  }

  /// Called when leaving Lead Detail so a stale lead isn't silently reused if a different one is
  /// opened next — mirrors InquiryController.clearCurrentDetail().
  void clearCurrentLeadDetail() => currentLeadDetail.value = null;

  /// Driven by InquiryHubService's live "NotificationReceived" (type == LeadAssigned) push — a new
  /// auto/manual assignment landed for this agent. The push payload only carries
  /// id/type/title/body/actionRoute (no inquiry fields), so unlike InquiryController
  /// .applyStatusUpdate's in-place patch, this can't construct the new row locally.
  ///
  /// Deliberately does NOT locally increment pendingLeadCount: the count is entirely server-anchored
  /// (see its own doc comment above) and the client has no way to replicate the server's "unseen"
  /// formula for the newly-assigned lead — a blind increment here could easily drift the badge away
  /// from the server's own count. checkAgentStatus() re-fetches the authoritative value instead;
  /// loadMyLeads() (only if the list is already loaded) makes the new lead itself show up, not just
  /// any count.
  void applyLeadAssigned() {
    checkAgentStatus();
    if (myLeads.isNotEmpty) loadMyLeads();
  }

  /// Driven by InquiryHubService's live "InquiryStatusChanged" push when a co-assigned agent or
  /// Admin changes a lead's status (see InquiryHandlers.NotifyCoAssignedAgentsOfStatusChangeAsync)
  /// — mirrors InquiryController.applyStatusUpdate's minimal-patch branch exactly, just scoped to
  /// myLeads/currentLeadDetail instead of myInquiries/currentDetail. A no-op for a lead not
  /// currently held in either (nothing to patch — the next screen visit picks up the real value),
  /// same as the consumer-side method.
  void applyLeadStatusUpdate(String inquiryId, String status) {
    final ts = DateTime.now();
    final idx = myLeads.indexWhere((l) => l.id == inquiryId);
    if (idx != -1) {
      myLeads[idx] = myLeads[idx].copyWith(status: status, updatedAt: ts);
    }
    final open = currentLeadDetail.value;
    if (open != null && open.id == inquiryId) {
      currentLeadDetail.value = open.copyWith(status: status, updatedAt: ts);
    }
    if (idx != -1) checkAgentStatus();
  }
}
