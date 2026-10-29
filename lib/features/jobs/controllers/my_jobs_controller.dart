import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/jobs_repository.dart';
import '../models/my_job_model.dart';
import 'jobs_list_controller.dart';

class MyJobsController extends GetxController {
  final _repo = const JobsRepository();
  final page = Rxn<MyJobsPage>();
  final isLoading = false.obs;
  final hasLoaded = false.obs;
  final loadFailed = false.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      page.value = await _repo.getMine();
      hasLoaded.value = true;
      loadFailed.value = false;
    } catch (e) {
      loadFailed.value = !hasLoaded.value;
      _handleError(e, 'Could not load your jobs.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> close(String id) async {
    try {
      isSaving.value = true;
      await _repo.close(id);
      AppToast.success('Job closed.');
      await load();
      invalidateList();
      return true;
    } catch (e) {
      _handleError(e, 'Could not close the job.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  static void invalidateList() {
    if (Get.isRegistered<JobsListController>(tag: JobsListController.tag)) {
      Get.find<JobsListController>(tag: JobsListController.tag).invalidate();
    }
  }

  void _handleError(dynamic e, String fallback) {
    if (e is DioException && e.response?.statusCode == 401) return;
    AppToast.error(DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {400, 404, 409}));
  }
}
