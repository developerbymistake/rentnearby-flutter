import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../repositories/inquiry_repository.dart';
import '../utils/app_toast.dart';
import '../utils/inquiry_status.dart';

/// Owns the consumer's own Inquiry state — the shared "My Inquiries" list
/// (both verticals together, no per-vertical split) and whichever single
/// Inquiry Detail screen is currently open. Nothing else in the app caches
/// inquiry status separately.
///
/// [applyStatusUpdate] is the single funnel every status-carrying event
/// flows through — mirrors WalletController.applyBalanceUpdate()'s pattern
/// exactly, learned from a real stale-cache bug in the wallet feature where
/// balance-changing events landed via inconsistent refresh paths. Three
/// call sites feed it: [submitInquiry]'s create response (Submitted, the
/// inquiry's very first status), [loadInquiryDetail]'s response-driven
/// refetch, and — once InquiryHubService is wired in a later step —
/// SignalR's "InquiryStatusChanged" push (a minimal {inquiryId, status}
/// payload for an admin-side change this device didn't itself initiate).
/// Never patch myInquiries or currentDetail directly from a screen or a
/// hub callback — always go through this method.
class InquiryController extends GetxController {
  final myInquiries = <InquiryModel>[].obs;
  final isLoadingMyInquiries = false.obs;
  // In-progress (Submitted/Contacted) count — drives the Explore tab header's Inquiries badge.
  // Recomputed at the end of every myInquiries mutation (loadMyInquiries + applyStatusUpdate),
  // same "derived, never set directly" shape as ChatController.unreadCount.
  final activeInquiryCount = 0.obs;
  final Rxn<InquiryDetailModel> currentDetail = Rxn<InquiryDetailModel>();
  final isLoadingDetail = false.obs;
  final isSubmitting = false.obs;
  final isSubmittingEscalation = false.obs;

  // Bumped on every loadInquiryDetail() call — lets a late, out-of-order response for an inquiry
  // the user has since navigated away from be detected and dropped, instead of clobbering
  // currentDetail with stale data for whichever inquiry screen is now actually open.
  int _detailRequestId = 0;

  // Same guard shape as _detailRequestId, for fetchActiveCount() — Inquiry has no live delta-push
  // for this count (unlike Chat's unread count), so a single sequence number is enough to drop a
  // stale in-flight response without needing Chat's fuller reconciliation machinery.
  int _activeCountRequestId = 0;

  InquiryRepository get _repo => Get.find<InquiryRepository>();

  @override
  void onInit() {
    super.onInit();
    fetchActiveCount();
  }

  /// Server-anchored refresh for the Explore tab's Inquiries badge — called at session start,
  /// on InquiryHubService reconnect, and on app resume, so the badge stays correct even when
  /// My Inquiries has never been opened this session (loadMyInquiries()/applyStatusUpdate's own
  /// _recomputeActiveCount() still runs whenever that full list is actually loaded/patched).
  Future<void> fetchActiveCount() async {
    final requestId = ++_activeCountRequestId;
    try {
      final count = await _repo.getActiveCount();
      if (requestId != _activeCountRequestId) return;
      activeInquiryCount.value = count;
    } catch (_) {
      // Best-effort — badge just keeps its last known value on failure.
    }
  }

  Future<void> loadMyInquiries() async {
    isLoadingMyInquiries.value = true;
    try {
      myInquiries.value = await _repo.getMyInquiries();
      _recomputeActiveCount();
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — this call fires unconditionally at app start (IndexedStack
      // builds every tab eagerly), so showing "Could not load your inquiries" on top would be a
      // second, contradictory toast flashing over the login screen for the same underlying event.
      if (e is DioException && e.response?.statusCode == 401) return;
      AppToast.error('Could not load your inquiries. Pull to refresh.');
    } finally {
      isLoadingMyInquiries.value = false;
    }
  }

  void _recomputeActiveCount() {
    activeInquiryCount.value = myInquiries
        .where((i) => i.status == InquiryStatus.submitted || i.status == InquiryStatus.contacted)
        .length;
  }

  Future<void> loadInquiryDetail(String inquiryId) async {
    final requestId = ++_detailRequestId;
    isLoadingDetail.value = true;
    try {
      final detail = await _repo.getInquiryDetail(inquiryId);
      // A newer loadInquiryDetail() call superseded this one while it was in flight — the user
      // has since opened a different inquiry, so this response is stale and must be discarded
      // rather than clobbering currentDetail out from under whichever screen is now open.
      if (requestId != _detailRequestId) return;
      if (detail != null) applyStatusUpdate(detail: detail);
    } catch (_) {
      if (requestId == _detailRequestId) AppToast.error('Could not load inquiry details.');
    } finally {
      if (requestId == _detailRequestId) isLoadingDetail.value = false;
    }
  }

  /// Submits the inquiry and, on success, seeds [currentDetail] with the
  /// authoritative created row (funneled through [applyStatusUpdate], same
  /// as every other status-carrying response) so Confirmation/Detail never
  /// need a redundant follow-up fetch. Returns the created detail, or null
  /// on failure (already toasted).
  Future<InquiryDetailModel?> submitInquiry({
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
      final detail = await _repo.createInquiry(
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

  /// "Report an issue with my agent" — mirrors [submitInquiry]'s exact shape (own loading flag,
  /// funnels the authoritative response through [applyStatusUpdate], toasts on failure via the same
  /// [_errorMessage] helper so a 409 "already reported" surfaces its real server message). Returns
  /// true on success so the calling sheet knows to close itself.
  Future<bool> submitEscalation(String inquiryId, String reason, {String? note}) async {
    isSubmittingEscalation.value = true;
    try {
      final detail = await _repo.submitEscalation(inquiryId, reason, note: note);
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
  ///     fresh getInquiryDetail() fetch) — patches both myInquiries and
  ///     currentDetail completely.
  ///   - [inquiryId] + [status] only: a minimal push-driven patch — updates
  ///     just the status (+ timestamp) on whichever of myInquiries/
  ///     currentDetail already hold this inquiry; agent/history fields are
  ///     left as last-fetched since the push payload never carries them.
  /// A no-op for an inquiry neither list currently holds (nothing to patch
  /// — the relevant screen will pick up the real value on its own next
  /// load), deliberately never triggering a bare network refetch itself.
  void applyStatusUpdate({InquiryDetailModel? detail, String? inquiryId, String? status}) {
    assert(detail != null || (inquiryId != null && status != null),
        'applyStatusUpdate needs either a full detail or an inquiryId+status pair');
    final id = detail?.id ?? inquiryId!;
    final newStatus = detail?.status ?? status!;
    final ts = detail?.updatedAt ?? DateTime.now();

    final idx = myInquiries.indexWhere((i) => i.id == id);
    if (idx != -1) {
      myInquiries[idx] = myInquiries[idx].copyWith(
        status: newStatus,
        assignedAgentCount: detail?.assignedAgents.length,
        hasPendingEscalation: detail?.hasPendingEscalation,
        updatedAt: ts,
      );
    } else if (detail != null) {
      // A full detail for an inquiry not yet in myInquiries — e.g. submitInquiry()'s own create
      // response — reflects it immediately instead of silently waiting for the next full
      // loadMyInquiries()/fetchActiveCount() anchor. InquiryDetailModel carries every field
      // InquiryModel needs; a minimal inquiryId+status push for an unknown id (never happens
      // today — this device always creates its own inquiries locally first) is still a no-op.
      myInquiries.insert(
        0,
        InquiryModel(
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
      // A full detail always designates which inquiry is "current" — from an explicit
      // loadInquiryDetail() fetch or a just-created inquiry's create response — regardless of
      // whichever (possibly different) inquiry currentDetail last held.
      currentDetail.value = detail;
    } else {
      // Minimal push-driven patch: only touch currentDetail if it's already showing this exact
      // inquiry — never let an unrelated background push clobber whatever the user has open.
      final open = currentDetail.value;
      if (open != null && open.id == id) {
        currentDetail.value = open.copyWith(status: newStatus, updatedAt: ts);
      }
    }
    _recomputeActiveCount();
  }

  /// Called when leaving the Inquiry Detail screen so a stale detail isn't
  /// silently reused if a different inquiry is opened next.
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
    return 'Could not submit inquiry. Please try again.';
  }
}
