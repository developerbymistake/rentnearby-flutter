// ignore_for_file: prefer_initializing_formals
import '../v2/jobs_feed_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../owner_core/data/single_flight.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/jobs_repository.dart';
import '../models/my_job_model.dart';
import 'jobs_list_controller.dart';

class MyJobsController extends GetxController with WidgetsBindingObserver {
  MyJobsController({this.refreshOnTab, JobsRepository repo = const JobsRepository(), DateTime Function()? clock})
      : _repo = repo,
        _clock = clock ?? DateTime.now;

  static const Duration staleAfter = Duration(seconds: 30);

  final int? refreshOnTab;
  final JobsRepository _repo;
  final DateTime Function() _clock;
  final page = Rxn<MyJobsPage>();
  final isLoading = false.obs;
  final hasLoaded = false.obs;
  final loadFailed = false.obs;
  final isSaving = false.obs;

  final _flight = SingleFlight<void>();
  DateTime? _loadedAt;
  Worker? _tabWorker;

  @override
  void onInit() {
    super.onInit();
    final tab = refreshOnTab;
    if (tab != null) {
      WidgetsBinding.instance.addObserver(this);
      if (Get.isRegistered<AuthController>()) {
        _tabWorker = ever<int>(Get.find<AuthController>().tabIndex, (i) {
          if (i == tab) refreshIfStale();
        });
      }
    }
    load();
  }

  @override
  void onClose() {
    if (refreshOnTab != null) WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshIfStale();
  }

  Future<void> refreshIfStale() async {
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < staleAfter) return;
    await load();
  }

  Future<void> load() => _flight.run(_load);

  Future<void> _load() async {
    try {
      isLoading.value = true;
      final p = await _repo.getMine();
      if (isClosed) return;
      page.value = p;
      _loadedAt = _clock();
      hasLoaded.value = true;
      loadFailed.value = false;
    } catch (e) {
      if (isClosed) return;
      loadFailed.value = !hasLoaded.value;
      _handleError(e, 'Could not load your jobs.');
    } finally {
      if (!isClosed) isLoading.value = false;
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
    JobsFeedController.invalidate();
    if (Get.isRegistered<JobsListController>(tag: JobsListController.tag)) {
      Get.find<JobsListController>(tag: JobsListController.tag).invalidate();
    }
  }

  void _handleError(dynamic e, String fallback) {
    if (e is DioException && e.response?.statusCode == 401) return;
    AppToast.error(DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {400, 404, 409}));
  }
}
