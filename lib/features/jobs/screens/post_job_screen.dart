import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../controllers/post_job_controller.dart';
import '../models/job_lookups_model.dart';
import '../widgets/jobs_ui.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});
  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  static const KitTone _tone = JobsUi.tone;
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

  Future<void> _confirmDiscard() async {
    final discard = await showJobsConfirm(
      context,
      title: 'Discard Job?',
      content: 'You have unsaved changes. Going back will discard everything.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
    );
    if (discard) Get.back();
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
        backgroundColor: DesignColors.scaffold,
        body: Obx(() => AppLoadingOverlay(
              isLoading: _ctrl.isSubmitting.value,
              message: 'Posting...',
              indicatorColor: _tone.accentDark,
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

  Widget _header() => ModuleHeader(
        tone: _tone,
        title: 'Post a Job',
        onBack: _ctrl.isSubmitting.value ? null : _close,
      );

  Widget _progress() {
    final step = _ctrl.step.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.cardGap + 4, KitMetrics.gutter, 0),
      child: SectionTile(
        tone: _tone,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: const BoxDecoration(color: DesignColors.dividerSoft, borderRadius: CardRadius.pill),
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: step >= i ? 1 : 0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    builder: (_, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(gradient: _tone.gradient, borderRadius: CardRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
            _stepDot(i, _steps[i], step),
          ],
        ]),
      ),
    );
  }

  Widget _blockBanner() {
    final message = _ctrl.blockMessage.value;
    if (message == null) return const SizedBox.shrink();
    return EntranceOnce(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.cardGap, KitMetrics.gutter, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: DesignColors.warningSoft,
          borderRadius: CardRadius.tile,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: DesignColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.error)),
          ),
          if (_ctrl.limitReached.value && Get.find<PlanController>().paymentEnabled) ...[
            const SizedBox(width: 8),
            TextLink(label: 'Upgrade', tone: _tone, onTap: () => Get.toNamed(AppRoutes.plansBilling)),
          ],
        ]),
      ),
    );
  }

  Widget _stepDot(int index, String label, int step) {
    final active = step == index;
    final done = step > index;
    return AnimatedScale(
      scale: active ? 1 : 0.88,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: (active || done) ? _tone.gradient : null,
              color: (active || done) ? null : DesignColors.dividerSoft,
              shape: BoxShape.circle,
              boxShadow: (active || done) ? ShadowTokens.glow(_tone.glow) : const [],
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded, color: DesignColors.surface, size: 16)
                  : Text('${index + 1}',
                      style: TypeTokens.style(14, FontWeight.w700,
                          color: active ? DesignColors.surface : DesignColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TypeTokens.style(12, FontWeight.w600,
                  color: (active || done) ? DesignColors.textStrong : DesignColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_ctrl.isLoading.value) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 16),
        children: [
          for (var i = 0; i < 3; i++) SectionTile.skeleton(lines: 2, margin: const EdgeInsets.only(bottom: 16)),
        ],
      );
    }
    if (_ctrl.loadFailed.value || _ctrl.lookups.value == null) {
      return StateCard.error(
        kit: _tone,
        title: "Couldn't load the form",
        actionLabel: 'Retry',
        onAction: _ctrl.load,
      );
    }
    final step = _ctrl.step.value;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, c) => Transform(
            transform: Matrix4.translationValues(0.0, 30 * (1.0 - anim.value), 0.0),
            child: c,
          ),
          child: child,
        ),
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
      decoration: const BoxDecoration(color: DesignColors.surface, boxShadow: DesignShadows.top),
      padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, AppInsets.bottomViewPadding(context) + 12),
      child: Row(children: [
        if (step > 0) ...[
          Expanded(child: SecondaryButton(label: 'Back', tone: _tone, onPressed: _back)),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: PrimaryButton(
            tone: _tone,
            onPressed: _ctrl.isLoading.value || _ctrl.lookups.value == null || _ctrl.blockMessage.value != null
                ? null
                : _next,
            loading: _ctrl.isSubmitting.value,
            label: last ? 'Post Job' : 'Next: ${_steps[step + 1]}',
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) => SectionTile(
        tone: _tone,
        title: title,
        margin: const EdgeInsets.only(bottom: 16),
        child: SizedBox(width: double.infinity, child: child),
      );

  InputDecoration _inputDec(String hint, {String? prefix}) => JobsUi.input(hint, prefix: prefix);

  Widget _pickerField({
    required String iconAsset,
    required String? value,
    required String placeholder,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: DesignColors.scaffold,
      borderRadius: KitMetrics.tileSmall,
      child: InkWell(
        onTap: onTap,
        borderRadius: KitMetrics.tileSmall,
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: KitMetrics.tileSmall,
            border: Border.all(color: DesignColors.borderSoft),
          ),
          child: Row(children: [
            Image.asset(iconAsset,
                width: 24,
                height: 24,
                color: enabled ? null : DesignColors.textDisabled,
                colorBlendMode: enabled ? null : BlendMode.srcIn),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(14, value == null ? FontWeight.w400 : FontWeight.w500,
                    color: value == null ? DesignColors.textMuted : DesignColors.textStrong),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: enabled ? DesignColors.textStrong : DesignColors.textMuted),
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
    return showJobsOptionSheet(context, title: title, labels: labels, selectedIndex: selectedIndex);
  }

  Widget _stepBody(int key, List<Widget> cards) => SingleChildScrollView(
        key: ValueKey(key),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 16),
        child: StaggerColumn(key: ValueKey('stagger$key'), crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
      );

  Widget _basicsStep() {
    final l = _ctrl.lookups.value!;
    final deptId = _ctrl.departmentId.value;
    return _stepBody(0, [
      _sectionCard(
        title: 'Job Title *',
        child: TextField(
          controller: _ctrl.titleCtrl,
          focusNode: _ctrl.titleFocus,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostJobController.titleMax)],
          textCapitalization: TextCapitalization.words,
          style: TypeTokens.body,
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
          style: TypeTokens.body,
          decoration: _inputDec('Duties, timings, food or stay'),
        ),
      ),
      _sectionCard(
        title: 'Department *',
        child: _pickerField(
          iconAsset: TravelIcon.note,
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
          iconAsset: JobsUi.roleIcon,
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
    ]);
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.caption),
      );

  Widget _detailsStep() {
    final l = _ctrl.lookups.value!;
    final salaryTypeId = _ctrl.salaryTypeId.value;
    final minYears = _ctrl.minExperienceYears.value;
    final years = PostJobController.experienceYearOptions;
    final salaryFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)];
    return _stepBody(1, [
      _sectionCard(
        title: 'Salary Type *',
        child: JobsChoiceWrap(
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
                style: TypeTokens.body,
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
                style: TypeTokens.body,
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
            iconAsset: JobsUi.experienceIcon,
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
          Text('Fresher means no experience needed',
              style: TypeTokens.caption),
        ]),
      ),
    ]);
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
    return _stepBody(2, [
      _sectionCard(
        title: 'Job Type *',
        child: JobsChoiceWrap(
          labels: l.jobTypes.map((e) => e.name).toList(),
          isActive: (i) => jobTypeId == l.jobTypes[i].id,
          onTap: (i) => _ctrl.jobTypeId.value = l.jobTypes[i].id,
        ),
      ),
      _sectionCard(
        title: 'Shift *',
        child: JobsChoiceWrap(
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
            style: TypeTokens.body,
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
            style: TypeTokens.style(14, FontWeight.w400, color: same ? DesignColors.textSecondary : DesignColors.textStrong),
            decoration: _inputDec('10-digit WhatsApp', prefix: '+91 '),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Same as my login number', style: TypeTokens.body)),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: same,
              onChanged: _ctrl.hasLoginPhone ? (v) => _ctrl.sameAsPhone.value = v : null,
              activeTrackColor: _tone.accentDark,
              thumbColor: DesignColors.surface,
            ),
          ]),
        ]),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('Your job goes live right after you post. Seekers call or WhatsApp you from the job.',
            style: TypeTokens.caption),
      ),
    ]);
  }
}
