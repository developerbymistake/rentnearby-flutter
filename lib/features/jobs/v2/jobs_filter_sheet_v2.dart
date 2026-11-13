import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import 'jobs_feed_controller.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import '../widgets/jobs_ui.dart';

class JobsFilterSheetV2 extends StatefulWidget {
  final JobsFeedController controller;

  const JobsFilterSheetV2({super.key, required this.controller});

  static const salaryOptions = <({int? value, String label})>[
    (value: null, label: 'Any'),
    (value: 10000, label: '10,000+'),
    (value: 15000, label: '15,000+'),
    (value: 20000, label: '20,000+'),
    (value: 30000, label: '30,000+'),
  ];

  static Future<void> show(BuildContext context, {required JobsFeedController controller}) {
    return Sheet3D.show<void>(context, builder: (_) => JobsFilterSheetV2(controller: controller));
  }

  @override
  State<JobsFilterSheetV2> createState() => _JobsFilterSheetV2State();
}

class _JobsFilterSheetV2State extends State<JobsFilterSheetV2> {
  late String? _departmentId = widget.controller.selectedDepartmentId.value;
  late JobExperienceBucket? _experience = widget.controller.selectedExperience.value;
  late int? _minSalary = widget.controller.minSalary.value;
  Worker? _externalResetWorker;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.loadLookups();
    _externalResetWorker = ever(widget.controller.resetGeneration, (_) {
      if (_closing || !mounted) return;
      _closing = true;
      Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _externalResetWorker?.dispose();
    super.dispose();
  }

  Widget _section(String label, Widget chips, {bool first = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!first) Container(height: 1, margin: const EdgeInsets.only(top: 12), color: Ink3D.line),
          JobsSheetLabel(label, first: first),
          chips,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final departmentSection = Obx(() {
      final departments = widget.controller.lookups.value?.departments ?? const <JobLookupItem>[];
      if (departments.isEmpty) return const SizedBox(width: double.infinity);
      return _section(
        'DEPARTMENT',
        JobsChoiceWrap(
          labels: ['All', for (final d in departments) d.name],
          isActive: (i) => _departmentId == (i == 0 ? null : departments[i - 1].id),
          onTap: (i) => setState(() => _departmentId = i == 0 ? null : departments[i - 1].id),
        ),
        first: true,
      );
    });
    final tone = JobsUi.look;
    return Sheet3D(
      tone: tone,
      art: ListingArt.luggage,
      title: 'Filter · Jobs',
      size: SheetSize.list,
      footer: PillButtonRow(
        children: [
          WhitePillButton(
            tone: tone,
            label: 'Reset',
            onTap: () => setState(() {
              _departmentId = null;
              _experience = null;
              _minSalary = null;
            }),
          ),
          GradientPillButton(
            tone: tone,
            label: 'Apply',
            onTap: () {
              _closing = true;
              Navigator.of(context).pop();
              widget.controller.applyFilters(
                departmentId: _departmentId,
                experience: _experience,
                minSalary: _minSalary,
              );
            },
          ),
        ],
      ),
      child: StaggerColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          departmentSection,
          _section(
            'EXPERIENCE',
            JobsChoiceWrap(
              labels: ['Any', for (final b in JobExperienceBucket.all) b.label],
              isActive: (i) => _experience == _experienceAt(i),
              onTap: (i) => setState(() => _experience = _experienceAt(i)),
            ),
          ),
          _section(
            'MIN SALARY',
            JobsChoiceWrap(
              labels: [for (final o in JobsFilterSheetV2.salaryOptions) o.label],
              isActive: (i) => _minSalary == JobsFilterSheetV2.salaryOptions[i].value,
              onTap: (i) => setState(() => _minSalary = JobsFilterSheetV2.salaryOptions[i].value),
            ),
          ),
        ],
      ),
    );
  }

  static JobExperienceBucket? _experienceAt(int i) => i == 0 ? null : JobExperienceBucket.all[i - 1];

}
