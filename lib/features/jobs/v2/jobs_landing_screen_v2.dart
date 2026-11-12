import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../../../config/app_routes.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../widgets/location_search_sheet.dart';
import '../../nearby/nearby_strings.dart';
import '../../nearby/widgets/nearby_header_strip.dart';
import '../../nearby/widgets/nearby_label_text.dart';
import '../../nearby/widgets/nearby_state_views.dart';
import '../models/job_experience_bucket.dart';
import '../models/job_lookups_model.dart';
import '../models/job_summary_model.dart';
import '../widgets/job_list_card.dart';
import '../widgets/jobs_ui.dart';
import 'jobs_city_sheet_v2.dart';
import 'jobs_feed_controller.dart';
import 'jobs_feed_repository.dart';
import 'jobs_filter_sheet_v2.dart';

class JobsLandingScreenV2 extends StatefulWidget {
  const JobsLandingScreenV2({super.key});

  @override
  State<JobsLandingScreenV2> createState() => _JobsLandingScreenV2State();
}

class _JobsLandingScreenV2State extends State<JobsLandingScreenV2> {
  static const KitTone _tone = JobsUi.tone;
  late final JobsFeedController _ctrl;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<JobsFeedController>(tag: JobsFeedController.tag)
        ? Get.find<JobsFeedController>(tag: JobsFeedController.tag)
        : Get.put(JobsFeedController(), tag: JobsFeedController.tag);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    Get.delete<JobsFeedController>(tag: JobsFeedController.tag);
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
        subtitle: 'Work at stays, nearest first',
        subtitleLines: 2,
        onBack: () => Get.back(),
        trailing: [_buildSearchButton()],
        bottom: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 4, 0), child: _buildDistrictPill()),
        autoHeight: true,
      ),
    );
  }

  Widget _buildDistrictPill() {
    return Obx(() {
      final c = _ctrl.city.value;
      final pin = _ctrl.searchPin.value;
      final label = pin != null
          ? pin.label
          : c == null
              ? 'My location'
              : [c.name, if (c.stateName.isNotEmpty) c.stateName].join(', ');
      return PressScale(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill, boxShadow: ShadowTokens.elev1),
          child: Material(
            color: Colors.transparent,
            borderRadius: CardRadius.pill,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: DesignColors.splash,
              highlightColor: Colors.transparent,
              onTap: _pickCity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      const TravelIcon(TravelIcon.place, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.textStrong),
                        ),
                      ),
                      if (c != null || pin != null)
                        InkWell(
                          onTap: _ctrl.useMyLocation,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: KitMetrics.touch,
                            height: KitMetrics.touch,
                            child: Icon(Icons.close_rounded, size: 20, color: DesignColors.textStrong),
                          ),
                        )
                      else
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

  Widget _buildSearchButton() {
    return Obx(() {
      final active = _ctrl.searchPin.value != null;
      return PillAction(
        label: active ? 'Cancel' : 'Search',
        tone: _tone,
        filled: !active,
        icon: Icon(active ? Icons.close_rounded : Icons.search_rounded,
            size: 16, color: active ? _tone.accentDark : DesignColors.onPrimary),
        onTap: active ? _ctrl.useMyLocation : _searchPlace,
      );
    });
  }

  Future<void> _searchPlace() async {
    final c = _ctrl.city.value;
    final bias = c != null
        ? LatLng(c.latitude, c.longitude)
        : (Get.isRegistered<LocationController>() ? Get.find<LocationController>().effectiveSearchCenter : null);
    final picked = await LocationSearchSheet.show(context, bias: bias);
    if (picked == null || !mounted) return;
    _ctrl.pickPin(picked.latLng.latitude, picked.latLng.longitude, picked.name);
  }

  Future<void> _pickCity() async {
    final picked = await JobsCitySheetV2.show(context);
    if (picked == null || !mounted) return;
    _ctrl.pickCity(picked);
  }

  Widget _buildFilterChips() {
    return Obx(() {
      final l = _ctrl.lookups.value;
      final departments = l?.departments ?? const <JobLookupItem>[];
      const buckets = JobExperienceBucket.all;
      final deptId = _ctrl.selectedDepartmentId.value;
      final experience = _ctrl.selectedExperience.value;
      final salary = _ctrl.minSalary.value;
      final salaryOptions = JobsFilterSheetV2.salaryOptions;
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

  String get _title {
    final first = _ctrl.items.isEmpty ? null : _ctrl.items.first.distance;
    if (first == null || first.isFar) return NearbyStrings.jobsNearest;
    final c = _ctrl.city.value;
    return c == null ? 'Jobs near you' : NearbyStrings.jobsNearCity(c.name);
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.sectionGap - 8, KitMetrics.gutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2),
                  ),
                ),
              ),
              Obx(() {
                final active = _ctrl.hasFilters;
                return PillAction(
                  label: 'Filter',
                  tone: _tone,
                  filled: active,
                  icon: Icon(Icons.tune_rounded, size: 16, color: active ? DesignColors.onPrimary : _tone.accentDark),
                  onTap: () => JobsFilterSheetV2.show(context, controller: _ctrl),
                );
              }),
            ],
          ),
          Obx(() => NearbyHeaderStrip(header: _ctrl.header.value)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildPlaceholderList();
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _ctrl.loadFailed.value
                ? NearbyError(onRetry: _ctrl.retry)
                : const NearbyEmpty(title: NearbyStrings.jobsEmptyTitle, body: NearbyStrings.jobsEmptyBody),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: 4),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => _card(items[i], i),
        ),
      );
    });
  }

  Widget _card(JobFeedItem item, int i) {
    final job = item.job;
    final d = item.distance;
    return KitCardEntrance(
      key: ValueKey(job.id),
      index: i,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobListCard(
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
          if (d != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(KitMetrics.gutter + 4, 0, KitMetrics.gutter, 8),
              child: NearbyLabelText(distance: d),
            ),
        ],
      ),
    );
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
      if (!_ctrl.hasMore.value && !_ctrl.isLoading.value && _ctrl.items.length < 3) {
        return Padding(padding: EdgeInsets.only(top: 12, bottom: 32 + bottom), child: const NearbyThin());
      }
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
