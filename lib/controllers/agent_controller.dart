import 'package:get/get.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../repositories/agent_repository.dart';
import '../utils/app_toast.dart';

/// Owns "is this account an Agent, and what do they need to see" — checked once per session
/// (mirrors WalletController's onInit()-fetches-once pattern, not a live push), read reactively
/// from Profile/MyLeads/LeadDetail. [isAgent] stays false, silently, for the ~all users who aren't
/// one — never toasted, never treated as an error.
class AgentController extends GetxController {
  final isAgent = false.obs;
  final agentId = Rxn<String>();
  // Leads still at Status == Submitted — the "something new landed" badge count, not every open lead.
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
    } catch (_) {
      // Best-effort background check — a network hiccup here just means the My Leads row stays
      // hidden this session, not a user-facing error.
      isAgent.value = false;
    }
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

  InquiryModel? _findLead(String id) {
    for (final l in myLeads) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<bool> updateLeadStatus(String id, String status, {String? note}) async {
    // Captured before the call — only a lead that WAS Submitted should decrement the badge; an
    // already-Contacted lead moving to Confirmed shouldn't touch a count it was never part of.
    final wasSubmitted = (currentLeadDetail.value?.id == id ? currentLeadDetail.value?.status : _findLead(id)?.status) == 'Submitted';

    isUpdatingStatus.value = true;
    try {
      final detail = await _repo.updateLeadStatus(id, status, note: note);
      if (detail == null) return false;

      currentLeadDetail.value = detail;
      final idx = myLeads.indexWhere((l) => l.id == id);
      if (idx != -1) {
        myLeads[idx] = myLeads[idx].copyWith(status: detail.status, updatedAt: detail.updatedAt);
      }
      if (wasSubmitted && status != 'Submitted' && pendingLeadCount.value > 0) {
        pendingLeadCount.value--;
      }
      return true;
    } catch (_) {
      AppToast.error('Could not update status. Please try again.');
      return false;
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  /// Called when leaving Lead Detail so a stale lead isn't silently reused if a different one is
  /// opened next — mirrors InquiryController.clearCurrentDetail().
  void clearCurrentLeadDetail() => currentLeadDetail.value = null;
}
