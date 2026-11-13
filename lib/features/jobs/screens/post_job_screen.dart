import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
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
  ListingTone get _look => JobsUi.look;
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
        backgroundColor: JobsLook.pageColor,
        body: Obx(() => AppLoadingOverlay(
              isLoading: _ctrl.isSubmitting.value,
              message: 'Posting...',
              indicatorColor: _look.g2,
              child: KitStatusBar(
                lightIcons: false,
                child: SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Expanded(child: _body()),
                    _bottomBar(),
                  ]),
                ),
              ),
            )),
      ),
    );
  }

  Widget _top() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          JobsHeader(
            tone: _look,
            art: ListingArt.luggage,
            title: 'Post a Job',
            onBack: _ctrl.isSubmitting.value ? null : _close,
          ),
          StepProgressHeader(
            tone: _look,
            labels: _steps,
            current: _ctrl.step.value,
            activeLabelColor: Ink3D.title,
            margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          ),
          _blockBanner(),
        ],
      );

  Widget _blockBanner() {
    final message = _ctrl.blockMessage.value;
    if (message == null) return const SizedBox.shrink();
    final upgrade = _ctrl.limitReached.value && Get.find<PlanController>().paymentEnabled;
    return EntranceOnce(
      child: JobsLimitBanner(
        tone: _look,
        message: message,
        linkLabel: upgrade ? 'Upgrade' : null,
        onLink: upgrade ? () => Get.toNamed(AppRoutes.plansBilling) : null,
      ),
    );
  }

  Widget _body() {
    if (_ctrl.isLoading.value) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [_top(), for (var i = 0; i < 3; i++) const SkeletonFormCard()],
      );
    }
    if (_ctrl.loadFailed.value || _ctrl.lookups.value == null) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _top(),
          JobsStateBlock(
            tone: _look,
            art: ListingArt.compass,
            title: "Couldn't load the form",
            actionLabel: 'Retry',
            onAction: _ctrl.load,
            padding: const EdgeInsets.fromLTRB(30, 60, 30, 24),
          ),
        ],
      );
    }
    final step = _ctrl.step.value;
    return switch (step) {
      0 => _basicsStep(),
      1 => _detailsStep(),
      _ => _extrasStep(),
    };
  }

  Widget _bottomBar() {
    final step = _ctrl.step.value;
    final last = step == _steps.length - 1;
    final off = _ctrl.isLoading.value || _ctrl.lookups.value == null || _ctrl.blockMessage.value != null;
    return FormFooter(
      tone: _look,
      top: const ToastDock(),
      primaryLabel: last ? 'Post Job' : 'Next: ${_steps[step + 1]}',
      onPrimary: off ? null : _next,
      primaryEnabled: !off,
      primaryLoading: _ctrl.isSubmitting.value,
      secondaryLabel: step > 0 ? 'Back' : null,
      onSecondary: step > 0 ? _back : null,
    );
  }

  Widget _sectionCard({required String title, required String art, required Widget child}) => FormSectionCard(
        tone: _look,
        art: art,
        title: title,
        requiredMark: true,
        child: child,
      );

  Future<void> _pick({
    required String title,
    required String art,
    required List<JobLookupItem> items,
    required String? selectedId,
    required void Function(String id) onPicked,
  }) async {
    final i = await _pickIndex(
      title: title,
      art: art,
      labels: [for (final e in items) e.name],
      selectedIndex: items.indexWhere((e) => e.id == selectedId),
    );
    if (i != null) onPicked(items[i].id);
  }

  Future<int?> _pickIndex({
    required String title,
    required String art,
    required List<String> labels,
    required int selectedIndex,
  }) {
    FocusScope.of(context).unfocus();
    return showJobsOptionSheet(context, title: title, labels: labels, selectedIndex: selectedIndex, art: art);
  }

  Widget _stepBody(int key, List<Widget> cards) => SingleChildScrollView(
        key: ValueKey(key),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _top(),
            StaggerColumn(key: ValueKey('stagger$key'), crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
          ],
        ),
      );

  Widget _basicsStep() {
    final l = _ctrl.lookups.value!;
    final deptId = _ctrl.departmentId.value;
    return _stepBody(0, [
      _sectionCard(
        title: 'Job Title',
        art: ListingArt.luggage,
        child: PillField(
          tone: _look,
          controller: _ctrl.titleCtrl,
          focusNode: _ctrl.titleFocus,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostJobController.titleMax)],
          textCapitalization: TextCapitalization.words,
          hint: 'e.g. Cook for homestay',
        ),
      ),
      _sectionCard(
        title: 'Description',
        art: ListingArt.pushpin,
        child: PillField(
          tone: _look,
          controller: _ctrl.descCtrl,
          focusNode: _ctrl.descFocus,
          maxLines: 5,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostJobController.descriptionMax)],
          textCapitalization: TextCapitalization.sentences,
          hint: 'Duties, timings, food or stay',
        ),
      ),
      _sectionCard(
        title: 'Department',
        art: ListingArt.clipboard,
        child: PillPickerField(
          tone: _look,
          leadingArt: ListingArt.clipboard,
          value: _ctrl.departmentName,
          hint: 'Select',
          onTap: () => _pick(
            title: 'Department',
            art: ListingArt.clipboard,
            items: l.departments,
            selectedId: deptId,
            onPicked: _ctrl.setDepartment,
          ),
        ),
      ),
      _sectionCard(
        title: 'Job Role',
        art: ListingArt.backpack,
        child: PillPickerField(
          tone: _look,
          leadingArt: ListingArt.backpack,
          value: _ctrl.roleName,
          hint: deptId == null ? 'Pick a department first' : 'Select',
          enabled: deptId != null,
          onTap: deptId == null
              ? null
              : () => _pick(
                    title: 'Job Role',
                    art: ListingArt.backpack,
                    items: _ctrl.roles,
                    selectedId: _ctrl.roleId.value,
                    onPicked: _ctrl.setRole,
                  ),
        ),
      ),
    ]);
  }

  Widget _detailsStep() {
    final l = _ctrl.lookups.value!;
    final salaryTypeId = _ctrl.salaryTypeId.value;
    final minYears = _ctrl.minExperienceYears.value;
    final years = PostJobController.experienceYearOptions;
    final salaryFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)];
    return _stepBody(1, [
      _sectionCard(
        title: 'Salary Type',
        art: ListingArt.calendar,
        child: JobsChoiceWrap(
          labels: l.salaryTypes.map((e) => e.name).toList(),
          isActive: (i) => salaryTypeId == l.salaryTypes[i].id,
          onTap: (i) => _ctrl.salaryTypeId.value = l.salaryTypes[i].id,
        ),
      ),
      _sectionCard(
        title: 'Salary Range (₹)',
        art: ListingArt.moneyBag,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: PillField(
              tone: _look,
              label: 'Min',
              controller: _ctrl.minSalaryCtrl,
              focusNode: _ctrl.minSalaryFocus,
              keyboardType: TextInputType.number,
              inputFormatters: salaryFormatters,
              hint: '15000',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillField(
              tone: _look,
              label: 'Max',
              controller: _ctrl.maxSalaryCtrl,
              focusNode: _ctrl.maxSalaryFocus,
              keyboardType: TextInputType.number,
              inputFormatters: salaryFormatters,
              hint: '20000',
            ),
          ),
        ]),
      ),
      _sectionCard(
        title: 'Min Experience',
        art: ListingArt.mountain,
        child: PillPickerField(
          tone: _look,
          leadingArt: ListingArt.mountain,
          value: minYears == null ? null : PostJobController.experienceOptionLabel(minYears),
          hint: 'Select',
          helperText: 'Fresher means no experience needed',
          onTap: () async {
            final i = await _pickIndex(
              title: 'Min Experience',
              art: ListingArt.mountain,
              labels: [for (final y in years) PostJobController.experienceOptionLabel(y)],
              selectedIndex: minYears == null ? -1 : years.indexOf(minYears),
            );
            if (i != null) _ctrl.minExperienceYears.value = years[i];
          },
        ),
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
        title: 'Job Type',
        art: ListingArt.hotel,
        child: JobsChoiceWrap(
          labels: l.jobTypes.map((e) => e.name).toList(),
          isActive: (i) => jobTypeId == l.jobTypes[i].id,
          onTap: (i) => _ctrl.jobTypeId.value = l.jobTypes[i].id,
        ),
      ),
      _sectionCard(
        title: 'Shift',
        art: ListingArt.sunrise,
        child: JobsChoiceWrap(
          labels: l.shiftTypes.map((e) => _shiftLabel(e.name)).toList(),
          isActive: (i) => shiftId == l.shiftTypes[i].id,
          onTap: (i) => _ctrl.shiftTypeId.value = l.shiftTypes[i].id,
        ),
      ),
      _sectionCard(
        title: 'Contact',
        art: ListingArt.speechBalloon,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PillField(
            tone: _look,
            label: 'Phone Number',
            controller: _ctrl.phoneCtrl,
            focusNode: _ctrl.phoneFocus,
            keyboardType: TextInputType.phone,
            inputFormatters: phoneFormatters,
            prefixText: '+91',
            hint: '10-digit mobile',
          ),
          PillField(
            key: ValueKey(same),
            tone: _look,
            label: 'WhatsApp Number',
            firstLabel: false,
            controller: same ? _ctrl.loginPhoneCtrl : _ctrl.whatsAppCtrl,
            focusNode: same ? null : _ctrl.whatsAppFocus,
            enabled: !same,
            keyboardType: TextInputType.phone,
            inputFormatters: phoneFormatters,
            prefixText: '+91',
            hint: '10-digit WhatsApp',
          ),
          const SizedBox(height: 8),
          ToggleRow(
            tone: _look,
            label: 'Same as my login number',
            value: same,
            onChanged: _ctrl.hasLoginPhone ? (v) => _ctrl.sameAsPhone.value = v : null,
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Text(
          'Your job goes live right after you post. Seekers call or WhatsApp you from the job.',
          style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0, height: 1.45),
        ),
      ),
    ]);
  }
}
