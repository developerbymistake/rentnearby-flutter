import 'package:flutter/material.dart';
import '../jobs_colors.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../screens/explore_location_search_mixin.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../controllers/jobs_list_controller.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import '../models/job_summary_model.dart';
import '../widgets/job_list_card.dart';
import '../widgets/jobs_ui.dart';
import 'jobs_filter_sheet.dart';

class JobsLandingScreen extends StatefulWidget {
  const JobsLandingScreen({super.key});

  @override
  State<JobsLandingScreen> createState() => _JobsLandingScreenState();
}

class _JobsLandingScreenState extends State<JobsLandingScreen> with ExploreLocationSearchMixin<JobsLandingScreen> {
  static const KitTone _tone = JobsUi.tone;
  late final JobsListController _ctrl;
  final _scroll = ScrollController();

  @override
  get searchPalette => JobColors.palette;

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
    final loc = Get.find<LocationController>();
    Future.microtask(loc.resetBrowsing);
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent * 0.7) _ctrl.loadNextPage();
  }

  void _viewDetails(JobSummaryModel job) => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': job.id});

  double get _chipsHeight => 24 + MediaQuery.textScalerOf(context).scale(17);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: RefreshIndicator(
        color: _tone.accentDark,
        onRefresh: _ctrl.pullRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            PinnedFilterBar(
              extent: _chipsHeight + top + 8,
              padding: EdgeInsets.only(top: top + 4, bottom: 4),
              child: SizedBox(height: _chipsHeight, child: _buildFilterChips()),
            ),
            SliverToBoxAdapter(child: _buildListHeader()),
            _buildBody(),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(
      () => ModuleHeader(
        tone: _tone,
        title: Get.find<TabConfigController>().displayName(AppTabKeys.jobs, 'Jobs'),
        subtitle: 'Work at stays near you',
        onBack: () => Get.back(),
        trailing: [_buildSearchButton()],
        bottom: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 4, 0), child: _buildDistrictPill()),
        autoHeight: true,
      ),
    );
  }

  Widget _buildSearchButton() {
    return Obx(() {
      final active = isSearchActive;
      final resolving = searchResolving;
      return PressScale(
        enabled: !resolving,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: resolving ? null : () => onSearchToggleTap(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KitMetrics.touch),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? DesignColors.error : DesignColors.surface,
                  borderRadius: CardRadius.pill,
                  boxShadow: ShadowTokens.elev1,
                ),
                child: resolving
                    ? KitDots(color: _tone.accentDark, size: 6)
                    : active
                    ? Text('Cancel', style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.surface))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 20, color: _tone.accentDark),
                          const SizedBox(width: 6),
                          Text('Search', style: TypeTokens.style(14, FontWeight.w600, color: _tone.accentDark)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    });
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
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded, size: 16, color: DesignColors.textGrey),
                ),
              ),
              TextSpan(text: cityName),
            ];
      return PressScale(
        enabled: !searching,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill, boxShadow: ShadowTokens.elev1),
          child: Material(
            color: Colors.transparent,
            borderRadius: CardRadius.pill,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: DesignColors.splash,
              highlightColor: Colors.transparent,
              onTap: searching ? null : () => LocationSwitchSheet.show(context, palette: JobColors.palette),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const TravelIcon(TravelIcon.place, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: spans),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.textStrong),
                        ),
                      ),
                      if (!searching)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(color: DesignColors.scaffold, shape: BoxShape.circle),
                          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: DesignColors.textStrong),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFilterChips() {
    return Obx(() {
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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      );
    });
  }

  Widget _dropdownChip({
    required String label,
    required bool selected,
    required String title,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) {
    return JobsDropdownChip(
      label: label,
      selected: selected,
      onTap: () => _pickOption(title: title, options: options, selectedIndex: selectedIndex, onPicked: onPicked),
    );
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) async {
    final gen = _ctrl.resetGeneration.value;
    final picked = await showJobsOptionSheet(context, title: title, labels: options, selectedIndex: selectedIndex);
    if (picked == null || !mounted || gen != _ctrl.resetGeneration.value) return;
    onPicked(picked);
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.sectionGap - 8, KitMetrics.gutter, 4),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final n = _ctrl.total.value;
              return Text(
                n == null ? 'Jobs near you' : '$n ${n == 1 ? 'job' : 'jobs'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2),
              );
            }),
          ),
          Obx(() {
            final active = _ctrl.hasFilters;
            return PillAction(
              label: 'Filter',
              tone: _tone,
              filled: active,
              icon: Icon(Icons.tune_rounded, size: 16, color: active ? DesignColors.onPrimary : _tone.accentDark),
              onTap: () => JobsFilterSheet.show(context, controller: _ctrl),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.noDistrict.value) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 24),
              child: StateCard(kit: _tone, asset: TravelIcon.place, title: 'Pick a district', message: 'Choose where to find jobs'),
            ),
          );
        }
        if (_ctrl.isLoading.value) return _buildPlaceholderList();
        final failed = _ctrl.loadFailed.value;
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: failed
                ? StateCard.error(
                    kit: _tone,
                    title: "Couldn't load jobs",
                    message: 'Check your connection and try again',
                    actionLabel: 'Retry',
                    onAction: _ctrl.retry,
                  )
                : const StateCard(kit: _tone, asset: TravelIcon.note, title: 'No jobs yet', message: 'Try another district'),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: 4),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final job = items[i];
            return KitCardEntrance(
              key: ValueKey(job.id),
              index: i,
              child: JobListCard(
                title: job.title,
                roleLabel: job.roleName,
                experienceTag: job.experienceLabel,
                metaLine: job.locationLabel,
                topRightText: job.postedAgo,
                salaryLabel: job.salaryLabel,
                salaryUnit: job.salaryUnit,
                trailingChip: job.jobTypeName.isEmpty ? null : job.jobTypeName,
                accent: _tone.accent,
                accentDark: _tone.accentDark,
                onTap: () => _viewDetails(job),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildPlaceholderList() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 4),
      sliver: SliverList.builder(itemCount: 5, itemBuilder: (_, _) => ListRow.skeleton()),
    );
  }

  Widget _buildFooter() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Obx(() {
      if (_ctrl.items.isEmpty) return SizedBox(height: 32 + bottom);
      Widget child = const SizedBox.shrink();
      if (_ctrl.isLoadingMore.value) {
        child = Center(child: KitDots(color: _tone.accentDark));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: TextLink(label: "Couldn't load more. Tap to retry", tone: _tone, onTap: _ctrl.retryLoadMore),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: 12, bottom: 32 + bottom),
        child: SizedBox(height: KitMetrics.touch, child: child),
      );
    });
  }
}
