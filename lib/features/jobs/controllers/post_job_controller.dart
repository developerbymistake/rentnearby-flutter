import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/jobs_repository.dart';
import '../models/job_lookups_model.dart';

class PostJobController extends GetxController {
  static const titleMin = 3;
  static const titleMax = 100;
  static const descriptionMax = 2000;
  static const minSalaryLimit = 100;
  static const maxSalaryLimit = 9900000;
  static const experienceYearOptions = <int?>[null, 2, 5, 10];
  static const _warnTypes = {'StayJobLimit', 'StayNotApproved'};

  final _repo = const JobsRepository();
  final lookups = Rxn<JobLookups>();
  final isLoading = true.obs;
  final loadFailed = false.obs;
  final isSubmitting = false.obs;
  final step = 0.obs;
  final blockMessage = Rxn<String>();

  final departmentId = Rxn<String>();
  final roleId = Rxn<String>();
  final experienceLevelId = Rxn<String>();
  final minExperienceYears = Rxn<int>();
  final jobTypeId = Rxn<String>();
  final shiftTypeId = Rxn<String>();
  final salaryTypeId = Rxn<String>();

  final titleCtrl = TextEditingController();
  final minSalaryCtrl = TextEditingController();
  final maxSalaryCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final titleFocus = FocusNode();
  final descFocus = FocusNode();
  final minSalaryFocus = FocusNode();
  final maxSalaryFocus = FocusNode();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    minSalaryCtrl.dispose();
    maxSalaryCtrl.dispose();
    descCtrl.dispose();
    titleFocus.dispose();
    descFocus.dispose();
    minSalaryFocus.dispose();
    maxSalaryFocus.dispose();
    super.onClose();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      loadFailed.value = false;
      blockMessage.value = null;
      lookups.value = await _repo.getLookups();
      blockMessage.value = (await _repo.getMine()).blockMessage;
    } catch (e) {
      loadFailed.value = true;
      _handleError(e, 'Could not load the form.');
    } finally {
      isLoading.value = false;
    }
  }

  bool get hasChanges =>
      titleCtrl.text.isNotEmpty ||
      descCtrl.text.isNotEmpty ||
      minSalaryCtrl.text.isNotEmpty ||
      maxSalaryCtrl.text.isNotEmpty ||
      departmentId.value != null ||
      roleId.value != null ||
      experienceLevelId.value != null ||
      minExperienceYears.value != null ||
      jobTypeId.value != null ||
      shiftTypeId.value != null ||
      salaryTypeId.value != null;

  List<JobLookupItem> get roles => lookups.value?.rolesFor(departmentId.value) ?? const [];

  String? get departmentName => JobLookups.nameOf(lookups.value?.departments ?? const [], departmentId.value);
  String? get roleName => JobLookups.nameOf(lookups.value?.roles ?? const [], roleId.value);

  void setDepartment(String id) {
    if (departmentId.value == id) return;
    departmentId.value = id;
    roleId.value = null;
  }

  void setRole(String id) => roleId.value = id;

  void toggle(Rxn<String> field, String id) => field.value = field.value == id ? null : id;

  int? get minSalary => int.tryParse(minSalaryCtrl.text.trim());
  int? get maxSalary => int.tryParse(maxSalaryCtrl.text.trim());

  bool _fail(String message, [FocusNode? focus]) {
    AppToast.error(message);
    focus?.requestFocus();
    return false;
  }

  bool validateStep(int s) {
    switch (s) {
      case 0:
        final t = titleCtrl.text.trim().length;
        final d = descCtrl.text.trim().length;
        if (t == 0) return _fail('Please enter the job title', titleFocus);
        if (t < titleMin) return _fail('Job title must be at least $titleMin characters', titleFocus);
        if (t > titleMax) return _fail('Job title is too long', titleFocus);
        if (d == 0) return _fail('Please enter the job description', descFocus);
        if (d > descriptionMax) return _fail('Description is too long', descFocus);
      case 1:
        if (departmentId.value == null) return _fail('Please select a department');
        if (roleId.value == null) return _fail('Please select a job role');
        if (experienceLevelId.value == null) return _fail('Please select an experience level');
      case 2:
        final min = minSalary;
        final max = maxSalary;
        if (minSalaryCtrl.text.trim().isEmpty) return _fail('Please enter the min salary', minSalaryFocus);
        if (min == null || min < minSalaryLimit) return _fail('Min salary must be at least ₹100', minSalaryFocus);
        if (min > maxSalaryLimit) return _fail('Min salary cannot exceed ₹99,00,000', minSalaryFocus);
        if (maxSalaryCtrl.text.trim().isEmpty) return _fail('Please enter the max salary', maxSalaryFocus);
        if (max == null || max > maxSalaryLimit) return _fail('Max salary cannot exceed ₹99,00,000', maxSalaryFocus);
        if (max < min) return _fail('Max salary must be at least the min salary', maxSalaryFocus);
    }
    return true;
  }

  Map<String, dynamic> _body() => {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'jobDepartmentId': departmentId.value,
        'jobRoleId': roleId.value,
        'jobExperienceLevelId': experienceLevelId.value,
        'jobTypeId': jobTypeId.value,
        'jobShiftTypeId': shiftTypeId.value,
        'jobSalaryTypeId': salaryTypeId.value,
        'minimumExperienceYears': minExperienceYears.value,
        'minSalary': minSalary,
        'maxSalary': maxSalary,
      };

  Future<bool> submit() async {
    if (isSubmitting.value || blockMessage.value != null) return false;
    for (var s = 0; s < 3; s++) {
      if (!validateStep(s)) {
        step.value = s;
        return false;
      }
    }
    try {
      isSubmitting.value = true;
      await _repo.create(_body());
      AppToast.success('Job posted.');
      return true;
    } catch (e) {
      const fallback = 'Could not post the job.';
      if (e is DioException && _warnTypes.contains(DioErrorMapper.errorType(e))) {
        blockMessage.value = DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {409});
      }
      _handleError(e, fallback);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  void _handleError(dynamic e, String fallback) {
    if (e is DioException && e.response?.statusCode == 401) return;
    final message = DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {400, 404, 409});
    if (e is DioException && e.response?.statusCode == 409 && _warnTypes.contains(DioErrorMapper.errorType(e))) {
      AppToast.warning(message);
      return;
    }
    AppToast.error(message);
  }
}
