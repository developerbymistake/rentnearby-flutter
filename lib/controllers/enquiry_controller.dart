import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/enquiry_detail_model.dart';
import '../models/enquiry_model.dart';
import '../repositories/enquiry_repository.dart';
import '../utils/app_toast.dart';
import '../utils/network_retry.dart';

/// Owns the consumer's own Enquiry state — the shared "My Enquiries" list
/// (both verticals together, no per-vertical split) and whichever single
/// Enquiry Detail screen is currently open. Nothing else in the app caches
/// enquiry status separately.
///
/// [applyStatusUpdate] is the single funnel every status-carrying event
/// flows through — mirrors WalletController.applyBalanceUpdate()'s pattern
/// exactly, learned from a real stale-cache bug in the wallet feature where
/// balance-changing events landed via inconsistent refresh paths. Three
/// call sites feed it: [submitEnquiry]'s create response (Submitted, the
/// enquiry's very first status), [loadEnquiryDetail]'s response-driven
/// refetch, and — once EnquiryHubService is wired in a later step —
/// SignalR's "EnquiryStatusChanged" push (a minimal {enquiryId, status}
/// payload for an admin-side change this device didn't itself initiate).
/// Never patch myEnquiries or currentDetail directly from a screen or a
/// hub callback — always go through this method.
class EnquiryController extends GetxController {
  final myEnquiries = <EnquiryModel>[].obs;
  final isLoadingMyEnquiries = false.obs;
  // Server-computed "not-Closed AND updated since I last saw it" count — drives the Explore tab
  // header's Enquiries badge. Always re-anchored via fetchActiveCount() (at the end of every
  // myEnquiries mutation, same as loadMyEnquiries + applyStatusUpdate), never derived locally from
  // myEnquiries — the client doesn't have the per-enquiry seen-timestamp needed to replicate this
  // formula, same "server-anchored, never locally recomputed" shape AgentController's
  // pendingLeadCount follows for the equivalent agent-side badge.
  final activeEnquiryCount = 0.obs;
  final Rxn<EnquiryDetailModel> currentDetail = Rxn<EnquiryDetailModel>();
  final isLoadingDetail = false.obs;
  final isSubmitting = false.obs;
  final isSubmittingEscalation = false.obs;

  // Bumped on every loadEnquiryDetail() call — lets a late, out-of-order response for an enquiry
  // the user has since navigated away from be detected and dropped, instead of clobbering
  // currentDetail with stale data for whichever enquiry screen is now actually open.
  int _detailRequestId = 0;

  // Same guard shape as _detailRequestId, for fetchActiveCount() — Enquiry has no live delta-push
  // for this count (unlike Chat's unread count), so a single sequence number is enough to drop a
  // stale in-flight response without needing Chat's fuller reconciliation machinery.
  int _activeCountRequestId = 0;

  EnquiryRepository get _repo => Get.find<EnquiryRepository>();

  @override
  void onInit() {
    super.onInit();
    fetchActiveCount();
  }

  /// Server-anchored refresh for the Explore tab's Enquiries badge — called at session start,
  /// on EnquiryHubService reconnect, and on app resume, so the badge stays correct even when
  /// My Enquiries has never been opened this session (loadMyEnquiries() and applyStatusUpdate()
  /// both also call this at the end of every myEnquiries mutation, so the badge never goes stale
  /// after a full list load or a live status patch either).
  Future<void> fetchActiveCount() async {
    final requestId = ++_activeCountRequestId;
    try {
      final count = await _repo.getActiveCount();
      if (requestId != _activeCountRequestId) return;
      activeEnquiryCount.value = count;
    } catch (_) {
      // Best-effort — badge just keeps its last known value on failure.
    }
  }

  Future<void> markSeen(String id) async {
    try {
      await _repo.markSeen(id);
      await fetchActiveCount();
    } catch (_) {}
  }

  Future<void> loadMyEnquiries() async {
    isLoadingMyEnquiries.value = true;
    try {
      final results = await Future.wait([
        withRetry(() => _repo.getMyEnquiries()),
        fetchActiveCount(),
      ]);
      myEnquiries.value = results[0] as List<EnquiryModel>;
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — this call fires unconditionally at app start (IndexedStack
      // builds every tab eagerly), so showing "Could not load your enquiries" on top would be a
      // second, contradictory toast flashing over the login screen for the same underlying event.
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error('Could not load your enquiries. Pull to refresh.');
    } finally {
      isLoadingMyEnquiries.value = false;
    }
  }

  Future<void> loadEnquiryDetail(String enquiryId) async {
    final requestId = ++_detailRequestId;
    isLoadingDetail.value = true;
    try {
      final detail = await _repo.getEnquiryDetail(enquiryId);
      // A newer loadEnquiryDetail() call superseded this one while it was in flight — the user
      // has since opened a different enquiry, so this response is stale and must be discarded
      // rather than clobbering currentDetail out from under whichever screen is now open.
      if (requestId != _detailRequestId) return;
      if (detail != null) applyStatusUpdate(detail: detail);
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — see loadMyEnquiries for the same guard.
      if (e is DioException && e.response?.statusCode == 401) return;
      if (requestId == _detailRequestId) AppToast.error('Could not load enquiry details.');
    } finally {
      if (requestId == _detailRequestId) isLoadingDetail.value = false;
    }
  }

  /// Submits the enquiry and, on success, seeds [currentDetail] with the
  /// authoritative created row (funneled through [applyStatusUpdate], same
  /// as every other status-carrying response) so Confirmation/Detail never
  /// need a redundant follow-up fetch. Returns the created detail, or null
  /// on failure (already toasted).
  Future<EnquiryDetailModel?> submitEnquiry({
    required String serviceId,
    required String servicePackageId,
    required String fullName,
    required String mobile,
    String? email,
    DateTime? preferredDateOrTripStart,
    int? numberOfPeople,
    String? message,
    required bool agreedToTerms,
  }) async {
    isSubmitting.value = true;
    try {
      final detail = await _repo.createEnquiry(
        serviceId: serviceId,
        servicePackageId: servicePackageId,
        fullName: fullName,
        mobile: mobile,
        email: email,
        preferredDateOrTripStart: preferredDateOrTripStart,
        numberOfPeople: numberOfPeople,
        message: message,
        agreedToTerms: agreedToTerms,
      );
      applyStatusUpdate(detail: detail);
      return detail;
    } catch (e) {
      AppToast.error(_errorMessage(e));
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// "Report an issue with my agent" — mirrors [submitEnquiry]'s exact shape (own loading flag,
  /// funnels the authoritative response through [applyStatusUpdate], toasts on failure via the same
  /// [_errorMessage] helper so a 409 "already reported" surfaces its real server message). Returns
  /// true on success so the calling sheet knows to close itself.
  Future<bool> submitEscalation(String enquiryId, String reason, {String? note}) async {
    isSubmittingEscalation.value = true;
    try {
      final detail = await _repo.submitEscalation(enquiryId, reason, note: note);
      applyStatusUpdate(detail: detail);
      return true;
    } catch (e) {
      AppToast.error(_errorMessage(e));
      return false;
    } finally {
      isSubmittingEscalation.value = false;
    }
  }

  /// The single local-state-patch funnel — see the class doc comment.
  /// Call with either:
  ///   - [detail]: the full authoritative shape (create response, or a
  ///     fresh getEnquiryDetail() fetch) — patches both myEnquiries and
  ///     currentDetail completely.
  ///   - [enquiryId] + [status] only: a minimal push-driven patch — updates
  ///     just the status (+ timestamp) on whichever of myEnquiries/
  ///     currentDetail already hold this enquiry; agent/history fields are
  ///     left as last-fetched since the push payload never carries them.
  /// A no-op for an enquiry neither list currently holds (nothing to patch
  /// — the relevant screen will pick up the real value on its own next
  /// load), deliberately never triggering a bare network refetch itself.
  void applyStatusUpdate({EnquiryDetailModel? detail, String? enquiryId, String? status}) {
    assert(detail != null || (enquiryId != null && status != null),
        'applyStatusUpdate needs either a full detail or an enquiryId+status pair');
    final id = detail?.id ?? enquiryId!;
    final newStatus = detail?.status ?? status!;
    final ts = detail?.updatedAt ?? DateTime.now();

    final idx = myEnquiries.indexWhere((i) => i.id == id);
    if (idx != -1) {
      myEnquiries[idx] = myEnquiries[idx].copyWith(
        status: newStatus,
        assignedAgentCount: detail?.assignedAgents.length,
        hasPendingEscalation: detail?.hasPendingEscalation,
        updatedAt: ts,
      );
    } else if (detail != null) {
      // A full detail for an enquiry not yet in myEnquiries — e.g. submitEnquiry()'s own create
      // response — reflects it immediately instead of silently waiting for the next full
      // loadMyEnquiries()/fetchActiveCount() anchor. EnquiryDetailModel carries every field
      // EnquiryModel needs; a minimal enquiryId+status push for an unknown id (never happens
      // today — this device always creates its own enquiries locally first) is still a no-op.
      myEnquiries.insert(
        0,
        EnquiryModel(
          id: detail.id,
          serviceId: detail.serviceId,
          serviceName: detail.serviceName,
          serviceCategoryId: detail.serviceCategoryId,
          serviceCategoryName: detail.serviceCategoryName,
          agentRoleLabel: detail.agentRoleLabel,
          servicePackageId: detail.servicePackageId,
          servicePackageName: detail.servicePackageName,
          fullName: detail.fullName,
          mobile: detail.mobile,
          status: detail.status,
          assignedAgentCount: detail.assignedAgents.length,
          hasPendingEscalation: detail.hasPendingEscalation,
          createdAt: detail.createdAt,
          updatedAt: detail.updatedAt,
        ),
      );
    }

    if (detail != null) {
      // A full detail always designates which enquiry is "current" — from an explicit
      // loadEnquiryDetail() fetch or a just-created enquiry's create response — regardless of
      // whichever (possibly different) enquiry currentDetail last held.
      currentDetail.value = detail;
    } else {
      // Minimal push-driven patch: only touch currentDetail if it's already showing this exact
      // enquiry — never let an unrelated background push clobber whatever the user has open.
      final open = currentDetail.value;
      if (open != null && open.id == id) {
        currentDetail.value = open.copyWith(status: newStatus, updatedAt: ts);
      }
    }
    fetchActiveCount();
  }

  /// Called when leaving the Enquiry Detail screen so a stale detail isn't
  /// silently reused if a different enquiry is opened next.
  void clearCurrentDetail() => currentDetail.value = null;

  // Mirrors WalletController._errorMessage's DioException-to-user-facing-string shape.
  String _errorMessage(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      String? message;
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        message = responseData['error']?['message'] as String? ?? responseData['message'] as String?;
      } else if (responseData is String) {
        message = responseData;
      }
      if ((status == 400 || status == 404 || status == 409) && message != null) return message;
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return 'Could not submit enquiry. Please try again.';
  }
}
