import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
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
  ListingTone get _look => JobsLook.page;
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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: JobsLook.pageColor,
      body: KitStatusBar(
        lightIcons: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: _look.g2,
              edgeOffset: top,
              onRefresh: _ctrl.pullRefresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: top)),
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  SliverToBoxAdapter(child: _buildListHeader()),
                  _buildBody(),
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            ),
            Positioned(left: 0, right: 0, top: 0, height: top, child: ColoredBox(color: JobsLook.pageColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(
          () => JobsHeader(
            tone: _look,
            art: ListingArt.luggage,
            title: Get.find<TabConfigController>().displayName(AppTabKeys.jobs, 'Jobs'),
            subtitle: 'Work at stays, nearest first',
            onBack: () => Get.back(),
          ),
        ),
        _buildPlaceBar(),
      ],
    );
  }

  Widget _buildPlaceBar() {
    return Obx(() {
      final c = _ctrl.city.value;
      final pin = _ctrl.searchPin.value;
      final label = pin != null
          ? pin.label
          : c == null
              ? 'My location'
              : [c.name, if (c.stateName.isNotEmpty) c.stateName].join(', ');
      final active = pin != null;
      return JobsPlaceBar(
        tone: _look,
        label: label,
        onPlaceTap: _pickCity,
        onClear: c != null || pin != null ? _ctrl.useMyLocation : null,
        actionLabel: active ? 'Cancel' : 'Search',
        cancel: active,
        onAction: active ? _ctrl.useMyLocation : _searchPlace,
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
      return JobsFilterTiles(
        children: [
          _dropdownChip(
            tone: ListingTone.cB,
            art: ListingArt.clipboard,
            label: JobLookups.nameOf(departments, deptId) ?? 'Department',
            selected: deptId != null,
            title: 'Department',
            options: ['Any', ...departments.map((e) => e.name)],
            selectedIndex: deptId == null ? 0 : departments.indexWhere((e) => e.id == deptId) + 1,
            onPicked: (i) => _ctrl.setDepartment(i == 0 ? null : departments[i - 1].id),
          ),
          _dropdownChip(
            tone: ListingTone.cD,
            art: ListingArt.mountain,
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
            tone: ListingTone.cF,
            art: ListingArt.moneyBag,
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
        ],
      );
    });
  }

  Widget _dropdownChip({
    required ListingTone tone,
    required String art,
    required String label,
    required bool selected,
    required String title,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) {
    return JobsFilterTile(
      tone: tone,
      art: art,
      label: label,
      selected: selected,
      onTap: () => _pickOption(title: title, art: art, options: options, selectedIndex: selectedIndex, onPicked: onPicked),
    );
  }

  Future<void> _pickOption({
    required String title,
    required String art,
    required List<String> options,
    required int selectedIndex,
    required void Function(int) onPicked,
  }) async {
    final gen = _ctrl.resetGeneration.value;
    final picked = await showJobsOptionSheet(context, title: title, labels: options, selectedIndex: selectedIndex, art: art);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Obx(
                  () => Semantics(
                    header: true,
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.4, height: 1.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Obx(
                () => JobsFilterButton(
                  tone: _look,
                  active: _ctrl.hasFilters,
                  onTap: () => JobsFilterSheetV2.show(context, controller: _ctrl),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Obx(() => NearbyHeaderStrip(header: _ctrl.header.value)),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Obx(() {
      final items = _ctrl.items;
      if (items.isEmpty) {
        if (_ctrl.isLoading.value) return _buildPlaceholderList();
        return SliverToBoxAdapter(
          child: _ctrl.loadFailed.value
              ? JobsStateBlock(
                  tone: _look,
                  art: ListingArt.worldMap,
                  title: NearbyStrings.errorTitle,
                  message: NearbyStrings.errorBody,
                  actionLabel: NearbyStrings.tryAgain,
                  onAction: _ctrl.retry,
                )
              : JobsStateBlock(
                  tone: _look,
                  art: ListingArt.luggage,
                  title: NearbyStrings.jobsEmptyTitle,
                  message: NearbyStrings.jobsEmptyBody,
                ),
        );
      }
      return SliverList.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i], i),
      );
    });
  }

  Widget _card(JobFeedItem item, int i) {
    final job = item.job;
    final d = item.distance;
    return KitCardEntrance(
      key: ValueKey(job.id),
      index: i,
      child: JobListCard(
        tone: JobsLook.card(i),
        title: job.title,
        roleLabel: job.roleName,
        experienceTag: job.experienceLabel,
        metaLine: job.locationLabel,
        topRightText: job.postedAgo,
        salaryLabel: job.salaryLabel,
        salaryShort: job.salaryCompact,
        salaryUnit: job.salaryUnit,
        trailingChip: job.jobTypeName.isEmpty ? null : job.jobTypeName,
        label: d == null ? null : NearbyLabelText.textFor(d),
        labelNote: d != null && d.isFar ? NearbyStrings.byRoad : null,
        accent: _tone.accent,
        accentDark: _tone.accentDark,
        onTap: () => _viewDetails(job),
      ),
    );
  }

  Widget _buildPlaceholderList() {
    return SliverList.builder(itemCount: 5, itemBuilder: (_, _) => const WideCardSkeleton());
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
        child = Center(child: KitDots(color: _look.g2));
      } else if (_ctrl.loadMoreFailed.value) {
        child = Center(
          child: Tap3D(
            onTap: _ctrl.retryLoadMore,
            label: "Couldn't load more. Tap to retry",
            exclude: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text("Couldn't load more. Tap to retry", textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, _look.text, letterSpacing: 0)),
            ),
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(top: 14, bottom: 32 + bottom),
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: Center(child: child)),
      );
    });
  }
}
