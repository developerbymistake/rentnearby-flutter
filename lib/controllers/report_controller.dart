import 'package:get/get.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';

class ReportController extends GetxController {
  final reportReasons = <ReportReasonModel>[].obs;
  final reportedListingIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadReportReasons();
  }

  Future<void> loadReportReasons() async {
    try {
      final res = await ApiService.get('/admin/report-reasons');
      reportReasons.value = (res['data'] as List).map((e) => ReportReasonModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<bool> submitReport({
    required String listingId,
    required String listingType, // 'Room' | 'Plot'
    required String reasonId,
    required String details,
  }) async {
    try {
      final path = listingType == 'Room' ? '/listings/$listingId/report' : '/plots/$listingId/report';
      await ApiService.post(path, {'reasonId': reasonId, 'details': details});
      reportedListingIds.add(listingId);
      return true;
    } catch (e) {
      AppToast.error('Could not submit report. Please try again.');
      return false;
    }
  }
}
