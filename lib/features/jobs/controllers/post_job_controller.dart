import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/plan_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../data/jobs_repository.dart';
import '../../stay_owner/strings/stay_work_strings.dart';
import '../models/job_detail_model.dart';
import '../models/job_lookups_model.dart';

class PostJobController extends GetxController {
  static const titleMin = 3;
  static const titleMax = 100;
  static const descriptionMax = 2000;
  static const minSalaryLimit = 100;
  static const maxSalaryLimit = 9900000;
  static const maxExperienceYears = 20;
  static const phoneLength = 10;
  static final phoneRegex = RegExp(r'^[6-9]\d{9}$');
  static const stepCount = 3;
  static const _warnTypes = {'StayJobLimit', 'StayNotApproved'};

  static final experienceYearOptions = List<int>.generate(maxExperienceYears + 1, (i) => i);

  static String experienceOptionLabel(int y) => y == 0 ? 'Fresher' : (y == 1 ? '1 year' : '$y years');

  PostJobController({this.editId});

  final String? editId;

  bool get isEdit => editId != null;

  final _repo = const JobsRepository();
  final lookups = Rxn<JobLookups>();
  final isLoading = true.obs;
  final loadFailed = false.obs;
  final isSubmitting = false.obs;
  final step = 0.obs;
  final blockMessage = Rxn<String>();
  final limitReached = false.obs;
  int? limitFree;

  final departmentId = Rxn<String>();
  final roleId = Rxn<String>();
  final minExperienceYears = Rxn<int>();
  final jobTypeId = Rxn<String>();
  final shiftTypeId = Rxn<String>();
  final salaryTypeId = Rxn<String>();
  final sameAsPhone = true.obs;
  final foodAndStay = false.obs;
  final canUpgrade = false.obs;

  final titleCtrl = TextEditingController();
  final minSalaryCtrl = TextEditingController();
  final maxSalaryCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final whatsAppCtrl = TextEditingController();
  final loginPhoneCtrl = TextEditingController();
  final titleFocus = FocusNode();
  final descFocus = FocusNode();
  final minSalaryFocus = FocusNode();
  final maxSalaryFocus = FocusNode();
  final phoneFocus = FocusNode();
  final whatsAppFocus = FocusNode();

  String _prefillPhone = '';

  @override
  void onInit() {
    super.onInit();
    _prefillPhone = _tenDigits(Get.find<AuthController>().user.value?.phoneNumber ?? '');
    phoneCtrl.text = _prefillPhone;
    loginPhoneCtrl.text = _prefillPhone;
    sameAsPhone.value = hasLoginPhone;
    load();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    minSalaryCtrl.dispose();
    maxSalaryCtrl.dispose();
    descCtrl.dispose();
    phoneCtrl.dispose();
    whatsAppCtrl.dispose();
    loginPhoneCtrl.dispose();
    titleFocus.dispose();
    descFocus.dispose();
    minSalaryFocus.dispose();
    maxSalaryFocus.dispose();
    phoneFocus.dispose();
    whatsAppFocus.dispose();
    super.onClose();
  }

  static String _tenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > phoneLength ? digits.substring(digits.length - phoneLength) : digits;
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      loadFailed.value = false;
      blockMessage.value = null;
      limitReached.value = false;
      lookups.value = await _repo.getLookups();
      final id = editId;
      if (id != null) {
        final job = await _repo.getMineById(id);
        if (isClosed) return;
        _prefill(job);
        return;
      }
      final mine = await _repo.getMine();
      if (isClosed) return;
      blockMessage.value = mine.blockMessage;
      limitReached.value = mine.limitReached;
      canUpgrade.value = mine.canUpgrade;
    } catch (e) {
      loadFailed.value = true;
      _handleError(e, 'Could not load the form.');
    } finally {
      isLoading.value = false;
    }
  }

  String _editSnapshot = '';

  void _prefill(JobDetailModel job) {
    titleCtrl.text = job.title;
    descCtrl.text = job.description;
    departmentId.value = job.jobDepartmentId.isEmpty ? null : job.jobDepartmentId;
    roleId.value = job.jobRoleId.isEmpty ? null : job.jobRoleId;
    jobTypeId.value = job.jobTypeId.isEmpty ? null : job.jobTypeId;
    shiftTypeId.value = job.jobShiftTypeId.isEmpty ? null : job.jobShiftTypeId;
    salaryTypeId.value = job.jobSalaryTypeId.isEmpty ? null : job.jobSalaryTypeId;
    minExperienceYears.value = job.minimumExperienceYears;
    minSalaryCtrl.text = job.minSalary > 0 ? '${job.minSalary}' : '';
    maxSalaryCtrl.text = job.maxSalary > 0 ? '${job.maxSalary}' : '';
    phoneCtrl.text = _tenDigits(job.contactPhone ?? '');
    final wa = _tenDigits(job.whatsAppNumber ?? '');
    sameAsPhone.value = wa.isEmpty || wa == _prefillPhone;
    whatsAppCtrl.text = sameAsPhone.value ? '' : wa;
    foodAndStay.value = job.foodAndStay;
    _editSnapshot = jsonEncode(_body());
  }

  bool get hasChanges => isEdit ? jsonEncode(_body()) != _editSnapshot : _hasNewChanges;

  bool get _hasNewChanges =>
      titleCtrl.text.isNotEmpty ||
      descCtrl.text.isNotEmpty ||
      minSalaryCtrl.text.isNotEmpty ||
      maxSalaryCtrl.text.isNotEmpty ||
      phoneCtrl.text.trim() != _prefillPhone ||
      whatsAppCtrl.text.isNotEmpty ||
      sameAsPhone.value != hasLoginPhone ||
      departmentId.value != null ||
      roleId.value != null ||
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

  int? get minSalary => int.tryParse(minSalaryCtrl.text.trim());
  int? get maxSalary => int.tryParse(maxSalaryCtrl.text.trim());

  String get contactPhone => phoneCtrl.text.trim();
  bool get hasLoginPhone => phoneRegex.hasMatch(_prefillPhone);
  String get whatsAppNumber => sameAsPhone.value ? _prefillPhone : whatsAppCtrl.text.trim();

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
        if (departmentId.value == null) return _fail('Please select a department');
        if (roleId.value == null) return _fail('Please select a job role');
      case 1:
        if (salaryTypeId.value == null) return _fail('Please select a salary type');
        final min = minSalary;
        final max = maxSalary;
        if (minSalaryCtrl.text.trim().isEmpty) return _fail('Please enter the min salary', minSalaryFocus);
        if (min == null || min < minSalaryLimit) return _fail('Min salary must be at least ₹100', minSalaryFocus);
        if (min > maxSalaryLimit) return _fail('Min salary cannot exceed ₹99,00,000', minSalaryFocus);
        if (maxSalaryCtrl.text.trim().isEmpty) return _fail('Please enter the max salary', maxSalaryFocus);
        if (max == null || max > maxSalaryLimit) return _fail('Max salary cannot exceed ₹99,00,000', maxSalaryFocus);
        if (max < min) return _fail('Max salary must be at least the min salary', maxSalaryFocus);
        if (minExperienceYears.value == null) return _fail('Please select min experience');
      case 2:
        if (jobTypeId.value == null) return _fail('Please select a job type');
        if (shiftTypeId.value == null) return _fail('Please select a shift');
        if (contactPhone.isEmpty) return _fail('Please enter the phone number', phoneFocus);
        if (!phoneRegex.hasMatch(contactPhone)) return _fail('Enter a valid 10-digit mobile number', phoneFocus);
        if (!sameAsPhone.value) {
          final w = whatsAppCtrl.text.trim();
          if (w.isEmpty) return _fail('Please enter the WhatsApp number', whatsAppFocus);
          if (!phoneRegex.hasMatch(w)) return _fail('Enter a valid 10-digit WhatsApp number', whatsAppFocus);
        }
    }
    return true;
  }

  Map<String, dynamic> _body() => {
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'jobDepartmentId': departmentId.value,
        'jobRoleId': roleId.value,
        'jobTypeId': jobTypeId.value,
        'jobShiftTypeId': shiftTypeId.value,
        'jobSalaryTypeId': salaryTypeId.value,
        'minimumExperienceYears': minExperienceYears.value,
        'minSalary': minSalary,
        'maxSalary': maxSalary,
        'contactPhone': contactPhone,
        'whatsAppNumber': whatsAppNumber,
        'foodAndStay': foodAndStay.value,
      };

  Future<bool> submit() async {
    if (isSubmitting.value || blockMessage.value != null) return false;
    for (var s = 0; s < stepCount; s++) {
      if (!validateStep(s)) {
        step.value = s;
        return false;
      }
    }
    try {
      isSubmitting.value = true;
      final id = editId;
      if (id != null) {
        await _repo.update(id, _body());
        AppToast.success(StayWorkStrings.jobSaved);
        return true;
      }
      await _repo.create(_body());
      AppToast.success('Job posted.');
      return true;
    } catch (e) {
      const fallback = 'Could not post the job.';
      final type = DioErrorMapper.errorType(e);
      if (type == OwnerErrorTypes.planRowInactive) {
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().invalidate().ignore();
        final msg = DioErrorMapper.serverMessage(e);
        AppToast.info(msg != null && msg.isNotEmpty ? msg : OwnerSharedStrings.inactiveToast);
        return false;
      }
      if (e is DioException && _warnTypes.contains(type)) {
        blockMessage.value = DioErrorMapper.toMessage(e, fallback, showRawMessageForStatusCodes: const {409});
        limitReached.value = type == 'StayJobLimit';
        if (limitReached.value) {
          final data = e.response?.data;
          final d = data is Map<String, dynamic> ? data['data'] : null;
          if (d is Map<String, dynamic>) {
            canUpgrade.value = d['canUpgrade'] == true;
            final limit = d['limit'];
            if (limit is int) limitFree = limit;
          }
          if (canUpgrade.value && PlanGate.paymentOn) return false;
        }
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
