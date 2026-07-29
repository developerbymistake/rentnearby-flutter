import '../models/enquiry_detail_model.dart';
import '../models/enquiry_model.dart';
import '../services/api_service.dart';

/// Thin wrapper around the consumer enquiry endpoints (`/enquiries/...`) —
/// deliberately uncached (matches WalletRepository's transactions ledger,
/// not its balance/credit-pack caches): an enquiry's status is exactly the
/// kind of value that must never be served stale, and the list/detail reads
/// here are only ever hit once per screen visit anyway.
class EnquiryRepository {
  Future<EnquiryDetailModel> createEnquiry({
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
    final res = await ApiService.post('/enquiries', {
      'serviceId': serviceId,
      'servicePackageId': servicePackageId,
      'fullName': fullName,
      'mobile': mobile,
      'email': email,
      'preferredDateOrTripStart': preferredDateOrTripStart?.toIso8601String(),
      'numberOfPeople': numberOfPeople,
      'message': message,
      'agreedToTerms': agreedToTerms,
    });
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response from server');
    }
    return EnquiryDetailModel.fromJson(data);
  }

  /// GET /enquiries/mine returns a flat, un-paginated array (this consumer's
  /// own lead volume is always small) — no page/hasMore shape, unlike
  /// WalletRepository.getTransactions.
  Future<List<EnquiryModel>> getMyEnquiries() async {
    final res = await ApiService.get('/enquiries/mine');
    return (res['data'] as List? ?? [])
        .map((e) => EnquiryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Server-anchored counterpart to getMyEnquiries — mirrors NotificationRepository.getUnreadCount's
  /// shape, for refreshing the Explore tab's Enquiries badge without loading the full list.
  Future<int> getActiveCount() async {
    final res = await ApiService.get('/enquiries/active-count');
    return (res['data']?['count'] as num?)?.toInt() ?? 0;
  }

  Future<EnquiryDetailModel?> getEnquiryDetail(String id) async {
    final res = await ApiService.get('/enquiries/$id');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return EnquiryDetailModel.fromJson(data);
  }

  Future<void> markSeen(String id) async => ApiService.put('/enquiries/$id/seen', {});

  /// "Report an issue with my agent" — throws (via ApiService's own Dio interceptor) on failure,
  /// including a 409 when a Pending report already exists; the controller/screen surface that.
  Future<EnquiryDetailModel> submitEscalation(String id, String reason, {String? note}) async {
    final res = await ApiService.post('/enquiries/$id/escalate', {
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response from server');
    }
    return EnquiryDetailModel.fromJson(data);
  }
}
