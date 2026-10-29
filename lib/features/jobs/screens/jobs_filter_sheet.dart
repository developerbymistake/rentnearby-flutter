import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../../stay/setup/stay_option_grid.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/jobs_list_controller.dart';

const _kGradient = StayColors.gradient;
const _kActive = StayColors.accent;

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
  late String? _experienceId = widget.controller.selectedExperienceLevelId.value;
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
                const Text('EXPERIENCE', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                Obx(() {
                  final levels = widget.controller.lookups.value?.experienceLevels ?? const [];
                  final ids = <String?>[null, ...levels.map((e) => e.id)];
                  return StayOptionGrid(
                    crossAxisCount: 2,
                    childAspectRatio: 3.9,
                    labels: ['Any', ...levels.map((e) => e.name)],
                    isActive: (i) => _experienceId == ids[i],
                    onTap: (i) => setState(() => _experienceId = ids[i]),
                  );
                }),
                const SizedBox(height: 16),
                const Text('MIN SALARY', style: _sectionLabelStyle),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 2.4,
                  children: JobsFilterSheet.salaryOptions
                      .map((o) => SelectableChip(
                            label: o.label,
                            selected: _minSalary == o.value,
                            activeColor: _kActive,
                            onTap: () => setState(() => _minSalary = o.value),
                          ))
                      .toList(),
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
                    _experienceId = null;
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
                    widget.controller.applyFilters(experienceLevelId: _experienceId, minSalary: _minSalary);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _sectionLabelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.textLight,
    letterSpacing: 0.4,
  );
}
