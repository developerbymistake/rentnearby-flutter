import '../models/inquiry_detail_model.dart';
import '../models/inquiry_model.dart';
import '../services/api_service.dart';

/// Thin wrapper around the consumer inquiry endpoints (`/inquiries/...`) —
/// deliberately uncached (matches WalletRepository's transactions ledger,
/// not its balance/coin-pack caches): an inquiry's status is exactly the
/// kind of value that must never be served stale, and the list/detail reads
/// here are only ever hit once per screen visit anyway.
class InquiryRepository {
  Future<InquiryDetailModel> createInquiry({
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
    final res = await ApiService.post('/inquiries', {
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
    return InquiryDetailModel.fromJson(data);
  }

  /// GET /inquiries/mine returns a flat, un-paginated array (this consumer's
  /// own lead volume is always small) — no page/hasMore shape, unlike
  /// WalletRepository.getTransactions.
  Future<List<InquiryModel>> getMyInquiries() async {
    final res = await ApiService.get('/inquiries/mine');
    return (res['data'] as List? ?? [])
        .map((e) => InquiryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InquiryDetailModel?> getInquiryDetail(String id) async {
    final res = await ApiService.get('/inquiries/$id');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return InquiryDetailModel.fromJson(data);
  }

  /// "Report an issue with my agent" — throws (via ApiService's own Dio interceptor) on failure,
  /// including a 409 when a Pending report already exists; the controller/screen surface that.
  Future<InquiryDetailModel> submitEscalation(String id, String reason, {String? note}) async {
    final res = await ApiService.post('/inquiries/$id/escalate', {
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response from server');
    }
    return InquiryDetailModel.fromJson(data);
  }
}
