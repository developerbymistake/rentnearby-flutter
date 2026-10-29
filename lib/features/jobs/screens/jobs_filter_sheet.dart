import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/setup/stay_option_grid.dart';
import '../controllers/jobs_list_controller.dart';
import '../jobs_colors.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';

const _kGradient = JobColors.gradient;
const _kActive = JobColors.accent;

class JobsFilterSheet extends StatefulWidget {
  final JobsListController controller;

  const JobsFilterSheet({super.key, required this.controller});

  static const salaryOptions = <({int? value, String label})>[
    (value: null, label: 'Any'),
    (value: 10000, label: '10,000+'),
    (value: 15000, label: '15,000+'),
    (value: 20000, label: '20,000+'),
    (value: 30000, label: '30,000+'),
  ];

  static Future<void> show(BuildContext context, {required JobsListController controller}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => JobsFilterSheet(controller: controller),
    );
  }

  @override
  State<JobsFilterSheet> createState() => _JobsFilterSheetState();
}

class _JobsFilterSheetState extends State<JobsFilterSheet> {
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          decoration: const BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Filter · Jobs',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  final departments = widget.controller.lookups.value?.departments ?? const <JobLookupItem>[];
                  if (departments.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DEPARTMENT', style: _sectionLabelStyle),
                        const SizedBox(height: 8),
                        StayOptionGrid(
                          crossAxisCount: 3,
                          childAspectRatio: 2.6,
                          accent: _kActive,
                          labels: ['All', for (final d in departments) d.name],
                          isActive: (i) => _departmentId == (i == 0 ? null : departments[i - 1].id),
                          onTap: (i) => setState(() => _departmentId = i == 0 ? null : departments[i - 1].id),
                        ),
                      ],
                    ),
                  );
                }),
                const Text('EXPERIENCE', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                StayOptionGrid(
                  crossAxisCount: 3,
                  childAspectRatio: 2.6,
                  accent: _kActive,
                  labels: ['Any', for (final b in JobExperienceBucket.all) b.label],
                  isActive: (i) => _experience == _experienceAt(i),
                  onTap: (i) => setState(() => _experience = _experienceAt(i)),
                ),
                const SizedBox(height: 16),
                const Text('MIN SALARY', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                StayOptionGrid(
                  crossAxisCount: 3,
                  childAspectRatio: 2.6,
                  accent: _kActive,
                  labels: [for (final o in JobsFilterSheet.salaryOptions) o.label],
                  isActive: (i) => _minSalary == JobsFilterSheet.salaryOptions[i].value,
                  onTap: (i) => setState(() => _minSalary = JobsFilterSheet.salaryOptions[i].value),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + media.padding.bottom),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _departmentId = null;
                    _experience = null;
                    _minSalary = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.divider, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Reset',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Apply',
                  height: 46,
                  gradient: _kGradient,
                  shadowColor: _kActive,
                  onPressed: () {
                    _closing = true;
                    Navigator.of(context).pop();
                    widget.controller.applyFilters(
                      departmentId: _departmentId,
                      experience: _experience,
                      minSalary: _minSalary,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static JobExperienceBucket? _experienceAt(int i) => i == 0 ? null : JobExperienceBucket.all[i - 1];

  static const _sectionLabelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.textLight,
    letterSpacing: 0.4,
  );
}
