import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/design.dart';
import '../design/extra/instagram_look.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../features/nearby/nearby_strings.dart';
import '../features/seeker_home/seeker_feed_controller.dart';
import '../features/seeker_home/seeker_home_parts.dart';
import '../features/seeker_home/seeker_quick_actions.dart';
import '../features/seeker_home/seeker_status_rule.dart';
import '../features/seeker_home/seeker_tour_steps.dart';
import '../features/seeker_home/strings/seeker_home_strings.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/trip/widgets/trip_popular_rail.dart';
import '../widgets/home_hero_carousel.dart';
import '../widgets/home_stay_rail_card.dart';
import '../widgets/home_taxi_rail_card.dart';
import '../widgets/tab_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sections = 4;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);

  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _tabs = Get.find<TabConfigController>();

  SeekerFeedController? get _feed => SeekerFeedController.maybe;

  @override
  void dispose() {
    _scroll.dispose();
    _replay.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final feed = _feed;
    await Future.wait<void>([_home.reloadDistrict(), if (feed != null) feed.reload()]);
    if (mounted) _replay.value++;
  }

  Future<void> _retryRails() => Future.wait<void>([_home.retryRails(), if (_feed case final f?) f.reload()]);

  Future<void> _openInstagram() async {
    final appUri = Uri.parse(
      'instagram://user?username=${AppConstants.instagramUsername}',
    );
    if (!await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse(
          'https://www.instagram.com/${AppConstants.instagramUsername}',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  double _bottomClear(BuildContext context) {
    return BarMetrics.bodyBottomOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    return Scaffold(
      backgroundColor: ListingPalette.sunrise.page,
      body: TabEntrance(
        tab: AppTabs.home,
        child: Obx(() {
          final name = _auth.profileName.value.trim();
          final firstName = name.isNotEmpty ? name.split(' ').first : SeekerHomeStrings.greetingFallbackName;
          return TabHeaderFrame(
            title: SeekerHomeStrings.greeting(firstName),
            subtitle: SeekerTripWords.headerSubtitle(_feed?.feed.value),
            color: ListingPalette.sunrise.page,
            iconsKey: TourKeys.homeActionMenu,
            child: body,
          );
        }),
      ),
    );
  }

  // The feed is read first: once it is shown, rail loading flags no longer rebuild the whole body (FX-29).
  bool get _firstOpen {
    final noRail = !_home.hasAnyRail;
    final railLoading = _home.anyRailLoading;
    final f = _feed;
    if (f == null || f.feed.value != null) return false;
    return noRail && (railLoading || f.loading.value);
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      color: ListingPalette.sunrise.g2,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(bottom: _bottomClear(context)),
        child: Obx(() {
          if (_firstOpen) return const SeekerHomeSkeleton();
          return StaggerHost(
            count: _sections,
            replay: _replay,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggerItem(
                  index: 0,
                  child: KeyedSubtree(
                    key: SeekerTourKeys.homeTripCard,
                    child: const HomeHeroCarousel(),
                  ),
                ),
                const StaggerItem(index: 1, child: SeekerQuickActions()),
                StaggerItem(index: 2, child: _buildRailsArea()),
                StaggerItem(index: 3, child: _buildInstagramCard()),
              ],
            ),
          );
        }),
      ),
    );
  }

  // The popular rail stays mounted across the error switch (hidden, not rebuilt or re-sorted; FX-31); o_sk_6 shows one error card.
  Widget _buildRailsArea() {
    return Obx(() {
      final failed = _home.railsFailedNoCopy && !_home.anyRailLoading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Visibility(visible: !failed, maintainState: true, child: const TripPopularRail()),
          if (failed)
            SeekerRailsErrorCard(onRetry: _retryRails)
          else ...[
            _buildListingsSections(),
            _buildRecentlyAddedSection(),
          ],
        ],
      );
    });
  }

  Widget _buildListingsSections() {
    return Obx(() {
      final far = _home.farAway.value;
      final rails = <Widget>[
        if (_tabs.isStaysActive && (_home.staysLoading.value || _home.stays.isNotEmpty))
          _buildRail(
            title: far ? NearbyStrings.staysNearest : NearbyStrings.staysNear,
            tab: AppTabs.stays,
            loading: _home.staysLoading.value,
            rail: () => _buildStaysRail(_home.stays),
          ),
        if (_tabs.isTaxiActive && (_home.taxisLoading.value || _home.taxis.isNotEmpty))
          _buildRail(
            title: far ? NearbyStrings.taxisNearest : NearbyStrings.taxisNear,
            tab: AppTabs.taxi,
            loading: _home.taxisLoading.value,
            rail: () => _buildTaxisRail(_home.taxis),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rails,
      );
    });
  }

  Widget _buildStaysRail(List<HomeStayModel> items) {
    return MealsRail(
      physics: const BouncingScrollPhysics(),
      children: [for (var i = 0; i < items.length; i++) HomeStayRailCard(stay: items[i], index: i)],
    );
  }

  Widget _buildTaxisRail(List<TaxiBrowseItem> items) {
    return MealsRail(
      physics: const BouncingScrollPhysics(),
      children: [for (var i = 0; i < items.length; i++) HomeTaxiRailCard(taxi: items[i], index: i)],
    );
  }

  Widget _buildRail({
    required String title,
    required int tab,
    required bool loading,
    required Widget Function() rail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: TitleRow3D(title: title, action: SeekerHomeStrings.seeAll, onAction: () => _auth.openPlace(AppPlaces.ofTab(tab))),
        ),
        SkeletonSwitcher(
          loading: loading,
          skeleton: _buildRailSkeleton(),
          child: rail(),
        ),
      ],
    );
  }

  Widget _buildRailSkeleton() {
    return const MealsRail(
      physics: NeverScrollableScrollPhysics(),
      children: [MealsCardSkeleton(), MealsCardSkeleton(), MealsCardSkeleton()],
    );
  }

  Widget _buildRecentlyAddedSection() {
    return Obx(() {
      if (!_tabs.isStaysActive) return const SizedBox.shrink();
      final loading = _home.recentlyAddedStaysLoading.value;
      final items = loading ? const <HomeRecentItem>[] : _home.recentMixed();
      if (!loading && items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: const TitleRow3D(title: SeekerHomeStrings.recentlyAdded)),
          SkeletonSwitcher(
            loading: loading,
            skeleton: const Column(children: [WideCardSkeleton(kind: WideKind.slim), WideCardSkeleton(kind: WideKind.slim)]),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) EntranceOnce(index: i, offset: 50, child: _recentRow(items[i])),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _recentRow(HomeRecentItem item) {
    final s = item.stay;
    if (s == null) return const SizedBox.shrink();
    return SeekerRecentRow(
      key: ValueKey('recent-${s.item.id}'),
      title: s.item.title,
      subtitle: s.item.locationLabel.isNotEmpty ? s.item.locationLabel : s.districtName,
      photoUrl: s.item.thumbnailUrl,
      stayTypeName: s.stayTypeName,
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.item.id}),
    );
  }

  Widget _buildInstagramCard() {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: KeyedSubtree(
        key: TourKeys.homeInstagramCard,
        child: WorkoutCard(
          tone: InstagramLook.tone,
          gradient: InstagramLook.gradient,
          art: ListingArt.camera,
          eyebrow: 'Instagram',
          title: 'Follow us',
          ctaLabel: 'Follow',
          minHeight: 112,
          semanticsLabel: 'Follow us on Instagram',
          onTap: _openInstagram,
        ),
      ),
    );
  }
}
