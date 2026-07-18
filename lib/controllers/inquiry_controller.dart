import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../repositories/inquiry_repository.dart';
import '../utils/app_toast.dart';

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
  final Rxn<InquiryDetailModel> currentDetail = Rxn<InquiryDetailModel>();
  final isLoadingDetail = false.obs;
  final isSubmitting = false.obs;

  InquiryRepository get _repo => Get.find<InquiryRepository>();

  Future<void> loadMyInquiries() async {
    isLoadingMyInquiries.value = true;
    try {
      myInquiries.value = await _repo.getMyInquiries();
    } catch (_) {
      AppToast.error('Could not load your inquiries. Pull to refresh.');
    } finally {
      isLoadingMyInquiries.value = false;
    }
  }

  Future<void> loadInquiryDetail(String inquiryId) async {
    isLoadingDetail.value = true;
    try {
      final detail = await _repo.getInquiryDetail(inquiryId);
      if (detail != null) applyStatusUpdate(detail: detail);
    } catch (_) {
      AppToast.error('Could not load inquiry details.');
    } finally {
      isLoadingDetail.value = false;
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
        assignedAgentId: detail?.assignedAgentId,
        assignedAgentName: detail?.assignedAgent?.name,
        updatedAt: ts,
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
