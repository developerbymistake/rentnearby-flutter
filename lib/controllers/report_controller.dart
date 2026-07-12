import 'package:get/get.dart';
import '../models/city_model.dart';
import '../models/listing_report_model.dart';
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

  Future<List<ListingReportModel>> fetchListingReports(String listingId, String listingType) async {
    try {
      final path = listingType == 'Room' ? '/listings/$listingId/reports' : '/plots/$listingId/reports';
      final res = await ApiService.get(path);
      return (res['data']['items'] as List).map((e) => ListingReportModel.fromJson(e)).toList();
    } catch (e) {
      AppToast.error('Could not load reports. Please try again.');
      return [];
    }
  }

  Future<List<ListingReportModel>> fetchMyFiledReports() async {
    try {
      final res = await ApiService.get('/users/reports');
      return (res['data']['items'] as List).map((e) => ListingReportModel.fromJson(e)).toList();
    } catch (e) {
      AppToast.error('Could not load your reports. Please try again.');
      return [];
    }
  }
}
