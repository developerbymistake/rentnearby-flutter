import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/setup/stay_option_grid.dart';
import '../controllers/post_job_controller.dart';
import '../jobs_colors.dart';
import '../models/job_lookups_model.dart';

const _kAccent = JobColors.accent;
const _kAccentDark = JobColors.accentDark;
const _kGradient = JobColors.gradient;
const _kWarnBg = AppColors.warningSurface;
const _kWarnText = AppColors.warningText;

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});
  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  late final PostJobController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(PostJobController());
  }

  @override
  void dispose() {
    Get.delete<PostJobController>();
    super.dispose();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_ctrl.step.value > 0) _ctrl.step.value--;
  }

  void _close() {
    FocusScope.of(context).unfocus();
    if (_ctrl.hasChanges) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Job?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text(
          'You have unsaved changes. Going back will discard everything.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Editing',
                style: TextStyle(fontFamily: 'Poppins', color: _kAccentDark, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static const _steps = ['Basics', 'Details', 'Extras'];

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_ctrl.step.value < _steps.length - 1) {
      if (!_ctrl.validateStep(_ctrl.step.value)) return;
      _ctrl.step.value++;
      return;
    }
    final ok = await _ctrl.submit();
    if (ok) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _ctrl.isSubmitting.value) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Obx(() => AppLoadingOverlay(
              isLoading: _ctrl.isSubmitting.value,
              message: 'Posting...',
              indicatorColor: JobColors.accent,
              child: Column(children: [
                _header(),
                _progress(),
                _blockBanner(),
                Expanded(child: _body()),
                _bottomBar(),
              ]),
            )),
      ),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: _kGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Row(children: [
              IconButton(
                onPressed: _ctrl.isSubmitting.value ? null : _close,
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Text('Post a Job',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      );

  Widget _progress() {
    final step = _ctrl.step.value;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) Expanded(child: Container(height: 2, color: step >= i ? _kAccent : AppColors.divider)),
          _stepDot(i, _steps[i], step),
        ],
      ]),
    );
  }

  Widget _blockBanner() {
    final message = _ctrl.blockMessage.value;
    if (message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _kWarnBg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Iconsax.warning_2, size: 18, color: _kWarnText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: _kWarnText)),
        ),
        if (_ctrl.limitReached.value && Get.find<PlanController>().paymentEnabled) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.plansBilling),
            child: const Text('Upgrade',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentDark)),
          ),
        ],
      ]),
    );
  }

  Widget _stepDot(int index, String label, int step) {
    final active = step == index;
    final done = step > index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (active || done) ? _kAccent : AppColors.divider,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text('${index + 1}',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textLight)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: (active || done) ? _kAccentDark : AppColors.textLight)),
      ],
    );
  }

  Widget _body() {
    if (_ctrl.isLoading.value) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent));
    }
    if (_ctrl.loadFailed.value || _ctrl.lookups.value == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Couldn't load the form",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: GradientButton(
              label: 'Retry',
              height: 42,
              gradient: _kGradient,
              shadowColor: _kAccent,
              onPressed: _ctrl.load,
            ),
          ),
        ]),
      );
    }
    final step = _ctrl.step.value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: switch (step) {
        0 => _basicsStep(),
        1 => _detailsStep(),
        _ => _extrasStep(),
      },
    );
  }

  Widget _bottomBar() {
    final step = _ctrl.step.value;
    final last = step == _steps.length - 1;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
      child: Row(children: [
        if (step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                side: const BorderSide(color: _kAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back', style: TextStyle(fontFamily: 'Poppins', color: _kAccentDark, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: GradientButton(
            onPressed: _ctrl.isLoading.value || _ctrl.lookups.value == null || _ctrl.blockMessage.value != null
                ? null
                : _next,
            isLoading: _ctrl.isSubmitting.value,
            gradient: _kGradient,
            shadowColor: _kAccent,
            label: last ? 'Post Job' : 'Next: ${_steps[step + 1]}',
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  InputDecoration _inputDec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: JobColors.surface,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
      );

  Widget _pickerField({
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: JobColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: enabled ? _kAccent : AppColors.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w500,
                  color: value == null ? AppColors.textHint : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Iconsax.arrow_down_1, size: 18, color: enabled ? _kAccentDark : AppColors.textHint),
          ]),
        ),
      ),
    );
  }

  Future<void> _pick({
    required String title,
    required List<JobLookupItem> items,
    required String? selectedId,
    required void Function(String id) onPicked,
  }) async {
    final i = await _pickIndex(
      title: title,
      labels: [for (final e in items) e.name],
      selectedIndex: items.indexWhere((e) => e.id == selectedId),
    );
    if (i != null) onPicked(items[i].id);
  }

  Future<int?> _pickIndex({
    required String title,
    required List<String> labels,
    required int selectedIndex,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: AppInsets.bottomViewPadding(sheetCtx) + 12),
              itemCount: labels.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.divider),
              itemBuilder: (_, i) {
                final selected = i == selectedIndex;
                return InkWell(
                  onTap: () => Navigator.pop(sheetCtx, i),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(children: [
                      Expanded(
                        child: Text(labels[i],
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                color: selected ? _kAccent : AppColors.textDark)),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(Iconsax.tick_circle, size: 18, color: _kAccent),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _basicsStep() {
    final l = _ctrl.lookups.value!;
    final deptId = _ctrl.departmentId.value;
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionCard(
          title: 'Job Title *',
          child: TextField(
            controller: _ctrl.titleCtrl,
            focusNode: _ctrl.titleFocus,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostJobController.titleMax)],
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('e.g. Cook for homestay'),
          ),
        ),
        _sectionCard(
          title: 'Description *',
          child: TextField(
            controller: _ctrl.descCtrl,
            focusNode: _ctrl.descFocus,
            maxLines: 5,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostJobController.descriptionMax)],
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: _inputDec('Duties, timings, food or stay'),
          ),
        ),
        _sectionCard(
          title: 'Department *',
          child: _pickerField(
            icon: Iconsax.briefcase,
            value: _ctrl.departmentName,
            placeholder: 'Select',
            onTap: () => _pick(
              title: 'Department',
              items: l.departments,
              selectedId: deptId,
              onPicked: _ctrl.setDepartment,
            ),
          ),
        ),
        _sectionCard(
          title: 'Job Role *',
          child: _pickerField(
            icon: Iconsax.user,
            value: _ctrl.roleName,
            placeholder: deptId == null ? 'Pick a department first' : 'Select',
            onTap: deptId == null
                ? null
                : () => _pick(
                      title: 'Job Role',
                      items: _ctrl.roles,
                      selectedId: _ctrl.roleId.value,
                      onPicked: _ctrl.setRole,
                    ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textLight)),
      );

  Widget _detailsStep() {
    final l = _ctrl.lookups.value!;
    final salaryTypeId = _ctrl.salaryTypeId.value;
    final minYears = _ctrl.minExperienceYears.value;
    final years = PostJobController.experienceYearOptions;
    final salaryFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)];
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionCard(
          title: 'Salary Type *',
          child: StayOptionGrid(
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            accent: _kAccent,
            labels: l.salaryTypes.map((e) => e.name).toList(),
            isActive: (i) => salaryTypeId == l.salaryTypes[i].id,
            onTap: (i) => _ctrl.salaryTypeId.value = l.salaryTypes[i].id,
          ),
        ),
        _sectionCard(
          title: 'Salary Range (₹) *',
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Min'),
                TextField(
                  controller: _ctrl.minSalaryCtrl,
                  focusNode: _ctrl.minSalaryFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: salaryFormatters,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: _inputDec('15000'),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Max'),
                TextField(
                  controller: _ctrl.maxSalaryCtrl,
                  focusNode: _ctrl.maxSalaryFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: salaryFormatters,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: _inputDec('20000'),
                ),
              ]),
            ),
          ]),
        ),
        _sectionCard(
          title: 'Min Experience *',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pickerField(
              icon: Iconsax.timer_1,
              value: minYears == null ? null : PostJobController.experienceOptionLabel(minYears),
              placeholder: 'Select',
              onTap: () async {
                final i = await _pickIndex(
                  title: 'Min Experience',
                  labels: [for (final y in years) PostJobController.experienceOptionLabel(y)],
                  selectedIndex: minYears == null ? -1 : years.indexOf(minYears),
                );
                if (i != null) _ctrl.minExperienceYears.value = years[i];
              },
            ),
            const SizedBox(height: 8),
            const Text('Fresher means no experience needed',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
      ]),
    );
  }

  static String _shiftLabel(String name) =>
      name.endsWith(' Shift') ? name.substring(0, name.length - ' Shift'.length) : name;

  Widget _extrasStep() {
    final l = _ctrl.lookups.value!;
    final jobTypeId = _ctrl.jobTypeId.value;
    final shiftId = _ctrl.shiftTypeId.value;
    final same = _ctrl.sameAsPhone.value;
    final phoneFormatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(PostJobController.phoneLength),
    ];
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionCard(
          title: 'Job Type *',
          child: StayOptionGrid(
            crossAxisCount: 2,
            childAspectRatio: 3.9,
            accent: _kAccent,
            labels: l.jobTypes.map((e) => e.name).toList(),
            isActive: (i) => jobTypeId == l.jobTypes[i].id,
            onTap: (i) => _ctrl.jobTypeId.value = l.jobTypes[i].id,
          ),
        ),
        _sectionCard(
          title: 'Shift *',
          child: StayOptionGrid(
            crossAxisCount: 2,
            childAspectRatio: 3.9,
            accent: _kAccent,
            labels: l.shiftTypes.map((e) => _shiftLabel(e.name)).toList(),
            isActive: (i) => shiftId == l.shiftTypes[i].id,
            onTap: (i) => _ctrl.shiftTypeId.value = l.shiftTypes[i].id,
          ),
        ),
        _sectionCard(
          title: 'Contact *',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel('Phone Number'),
            TextField(
              controller: _ctrl.phoneCtrl,
              focusNode: _ctrl.phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: _inputDec('10-digit mobile', prefix: '+91 '),
            ),
            const SizedBox(height: 12),
            _fieldLabel('WhatsApp Number'),
            TextField(
              key: ValueKey(same),
              controller: same ? _ctrl.loginPhoneCtrl : _ctrl.whatsAppCtrl,
              focusNode: same ? null : _ctrl.whatsAppFocus,
              enabled: !same,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: same ? AppColors.textMedium : AppColors.textDark),
              decoration: _inputDec('10-digit WhatsApp', prefix: '+91 '),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(
                child: Text('Same as my login number',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
              const SizedBox(width: 8),
              Switch(
                value: same,
                onChanged: _ctrl.hasLoginPhone ? (v) => _ctrl.sameAsPhone.value = v : null,
                activeThumbColor: _kAccentDark,
                activeTrackColor: _kAccent.withValues(alpha: 0.45),
              ),
            ]),
          ]),
        ),
        const Text('Your job goes live right after you post. Seekers call or WhatsApp you from the job.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
      ]),
    );
  }
}
