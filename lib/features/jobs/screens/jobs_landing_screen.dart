import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/jobs_list_controller.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import '../models/job_summary_model.dart';
import '../widgets/job_list_card.dart';
import 'jobs_filter_sheet.dart';

const _kAccent = StayColors.accent;
const _kAccentDark = StayColors.accentDark;
const _kGradient = StayColors.gradient;

class JobsLandingScreen extends StatefulWidget {
  const JobsLandingScreen({super.key});

  @override
  State<JobsLandingScreen> createState() => _JobsLandingScreenState();
}

class _JobsLandingScreenState extends State<JobsLandingScreen> {
  late final JobsListController _ctrl;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<JobsListController>(tag: JobsListController.tag)
        ? Get.find<JobsListController>(tag: JobsListController.tag)
        : Get.put(JobsListController(), tag: JobsListController.tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<JobsListController>(tag: JobsListController.tag);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  void _viewDetails(JobSummaryModel job) => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': job.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        color: _kAccent,
        onRefresh: _ctrl.pullRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildFilterChips()),
            SliverToBoxAdapter(child: _buildListHeader()),
            _buildBody(),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _kGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                    Get.find<TabConfigController>().displayNameForIndex(AppTabs.jobs, 'Jobs'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  )),
              const SizedBox(height: 2),
              Text(
                'Work at stays near you',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 18),
              _buildDistrictPill(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictPill() {
    final loc = Get.find<LocationController>();
    return Obx(() {
      final district = loc.effectiveDistrict;
      final cityName = loc.browsingCity.value?.name ?? loc.autoCity.value?.name ?? 'Current';
      final searchLabel = loc.searchPinLabel.value;
      final searching = searchLabel != null;
      final List<InlineSpan> spans = searching || district == null
          ? [TextSpan(text: searchLabel ?? 'Pick a district')]
          : [
              TextSpan(text: district.name),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Iconsax.arrow_right_3, size: 12, color: _kAccentDark.withValues(alpha: 0.6)),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: searching ? null : () => LocationSwitchSheet.show(context, plots: false),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.premium(_kAccent, alpha: 0.16, blur: 16, offset: const Offset(0, 6)),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.location, size: 17, color: _kAccentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _kAccentDark),
                ),
              ),
              if (!searching)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(Iconsax.arrow_down_1, size: 14, color: _kAccentDark),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 17 + MediaQuery.textScalerOf(context).scale(17),
        child: Obx(() {
          final l = _ctrl.lookups.value;
          final departments = l?.departments ?? const <JobLookupItem>[];
          const buckets = JobExperienceBucket.all;
          final deptId = _ctrl.selectedDepartmentId.value;
          final experience = _ctrl.selectedExperience.value;
          final salary = _ctrl.minSalary.value;
          final salaryOptions = JobsFilterSheet.salaryOptions;
          final chips = <Widget>[
            _dropdownChip(
              label: JobLookups.nameOf(departments, deptId) ?? 'Department',
              selected: deptId != null,
              title: 'Department',
              options: ['Any', ...departments.map((e) => e.name)],
              selectedIndex: deptId == null ? 0 : departments.indexWhere((e) => e.id == deptId) + 1,
              onPicked: (i) => _ctrl.setDepartment(i == 0 ? null : departments[i - 1].id),
            ),
            _dropdownChip(
              label: experience?.label ?? 'Experience',
              selected: experience != null,
              title: 'Experience',
              options: ['Any', for (final b in buckets) b.label],
              selectedIndex: experience == null ? 0 : buckets.indexOf(experience) + 1,
              onPicked: (i) => _ctrl.applyFilters(
                departmentId: _ctrl.selectedDepartmentId.value,
                experience: i == 0 ? null : buckets[i - 1],
                minSalary: _ctrl.minSalary.value,
              ),
            ),
            _dropdownChip(
              label: salary == null ? 'Salary' : '₹${salaryOptions.firstWhere((o) => o.value == salary).label}',
              selected: salary != null,
              title: 'Min salary',
              options: [for (final o in salaryOptions) o.label],
              selectedIndex: salaryOptions.indexWhere((o) => o.value == salary),
              onPicked: (i) => _ctrl.applyFilters(
                departmentId: _ctrl.selectedDepartmentId.value,
                experience: _ctrl.selectedExperience.value,
                minSalary: salaryOptions[i].value,
              ),
            ),
          ];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) => chips[i],
          );
        }),
      ),
    );
  }

  Widget _dropdownChip({
    required String label,
    required bool selected,
    required String title,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) {
    final fg = selected ? Colors.white : AppColors.textDark;
    return GestureDetector(
      onTap: () => _pickOption(title: title, options: options, selectedIndex: selectedIndex, onPicked: onPicked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _kAccent : AppColors.divider, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Iconsax.arrow_down_1, size: 14, color: selected ? Colors.white : _kAccentDark),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) async {
    final gen = _ctrl.resetGeneration.value;
    final picked = await showModalBottomSheet<int>(
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
            margin: const EdgeInsets.symmetric(vertical: 12),
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
              itemCount: options.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.divider),
              itemBuilder: (_, i) {
                final on = i == selectedIndex;
                return ListTile(
                  minTileHeight: 48,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(options[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                          color: on ? _kAccent : AppColors.textDark)),
                  trailing: on ? const Icon(Iconsax.tick_circle, size: 20, color: _kAccent) : null,
                  onTap: () => Navigator.pop(sheetCtx, i),
                );
              },
            ),
          ),
        ]),
      ),
    );
    if (picked == null || !mounted || gen != _ctrl.resetGeneration.value) return;
    onPicked(picked);
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final n = _ctrl.total.value;
              return Text(
                n == null ? 'Jobs near you' : '$n ${n == 1 ? 'job' : 'jobs'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              );
            }),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => JobsFilterSheet.show(context, controller: _ctrl),
            child: Obx(() {
              final active = _ctrl.hasFilters;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? _kAccent.withValues(alpha: 0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? _kAccent : AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.setting_4, size: 14, color: _kAccentDark),
                    const SizedBox(width: 5),
                    const Text(
                      'Filter',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentDark),
                    ),
                    if (active) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.noDistrict.value) {
          return SliverToBoxAdapter(
            child: _buildMessage(
              icon: Iconsax.location_slash,
              title: 'Pick a district',
              subtitle: 'Choose where to find jobs',
            ),
          );
        }
        if (_ctrl.isLoading.value) return _buildShimmerList();
        final failed = _ctrl.loadFailed.value;
        return SliverToBoxAdapter(
          child: _buildMessage(
            icon: failed ? Iconsax.cloud_cross : Iconsax.briefcase,
            title: failed ? "Couldn't load jobs" : 'No jobs yet',
            subtitle: failed ? 'Check your connection and try again' : 'Try another district',
            onRetry: failed ? _ctrl.retry : null,
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: 4),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final job = items[i];
            return JobListCard(
              key: ValueKey(job.id),
              title: job.title,
              roleLabel: job.roleName,
              experienceTag: job.experienceLabel,
              metaLine: job.locationLabel,
              topRightText: job.postedAgo,
              salaryLabel: job.salaryLabel,
              salaryUnit: job.salaryUnit,
              trailingChip: job.jobTypeName.isEmpty ? null : job.jobTypeName,
              accent: _kAccent,
              accentDark: _kAccentDark,
              onTap: () => _viewDetails(job),
            );
          },
        ),
      );
    });
  }

  Widget _buildShimmerList() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 4),
      sliver: SliverList.separated(
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 104,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: GradientButton(
                label: 'Retry',
                height: 42,
                gradient: _kGradient,
                shadowColor: _kAccent,
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Obx(() {
      if (_ctrl.items.isEmpty) return const SizedBox(height: 32);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextButton(
            onPressed: _ctrl.retryLoadMore,
            child: const Text(
              "Couldn't load more. Tap to retry",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: _kAccentDark),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        child: SizedBox(height: 36, child: child),
      );
    });
  }
}
