import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/design.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../features/jobs/controllers/my_jobs_controller.dart';
import '../features/nearby/nearby_strings.dart';
import '../features/stay/setup/stay_flow.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/setup/taxi_flow.dart';
import '../features/trip/widgets/trip_popular_rail.dart';
import '../utils/app_toast.dart';
import '../widgets/home_hero_carousel.dart';
import '../widgets/home_stay_rail_card.dart';
import '../widgets/home_taxi_rail_card.dart';
import '../widgets/plan_subscription_card.dart';
import '../widgets/tab_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sections = 7;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);

  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _tabs = Get.find<TabConfigController>();

  @override
  void dispose() {
    _scroll.dispose();
    _replay.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _home.reloadDistrict();
    if (mounted) _replay.value++;
  }

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
          final firstName = name.isNotEmpty ? name.split(' ').first : 'there';
          return TabHeaderFrame(
            title: 'Hi, $firstName',
            subtitle: 'Where to next?',
            color: ListingPalette.sunrise.page,
            iconsKey: TourKeys.homeActionMenu,
            child: body,
          );
        }),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      color: ListingPalette.sunrise.g2,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(bottom: _bottomClear(context)),
        child: StaggerHost(
          count: _sections,
          replay: _replay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StaggerItem(
                index: 0,
                child: KeyedSubtree(
                  key: TourKeys.homeManageListingsCard,
                  child: const HomeHeroCarousel(),
                ),
              ),
              StaggerItem(index: 1, child: _buildPlanNudge()),
              StaggerItem(index: 2, child: _buildOwnerQuickActions()),
              StaggerItem(index: 3, child: const TripPopularRail()),
              StaggerItem(index: 4, child: _buildListingsSections()),
              StaggerItem(index: 5, child: _buildRecentlyAddedSection()),
              StaggerItem(index: 6, child: _buildInstagramCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingsSections() {
    return Obx(() {
      final far = _home.farAway.value;
      final rails = <Widget>[
        if (_tabs.isStaysActive)
          _buildRail(
            title: far ? NearbyStrings.staysNearest : NearbyStrings.staysNear,
            tab: AppTabs.stays,
            section: HomeSectionKeys.stays,
            loading: _home.staysLoading.value,
            rail: () => _buildStaysRail(_home.stays),
          ),
        if (_tabs.isTaxiActive)
          _buildRail(
            title: far ? NearbyStrings.taxisNearest : NearbyStrings.taxisNear,
            tab: AppTabs.taxi,
            section: HomeSectionKeys.taxis,
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
    if (items.isEmpty) {
      return _emptyRailMessage('No stays listed here yet.', asset: TravelIcon.stay);
    }
    return MealsRail(
      physics: const BouncingScrollPhysics(),
      children: [for (var i = 0; i < items.length; i++) HomeStayRailCard(stay: items[i], index: i)],
    );
  }

  Widget _buildTaxisRail(List<TaxiBrowseItem> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No taxis listed here yet.', asset: TravelIcon.taxi, tone: KitTone.taxi);
    }
    return MealsRail(
      physics: const BouncingScrollPhysics(),
      children: [for (var i = 0; i < items.length; i++) HomeTaxiRailCard(taxi: items[i], index: i)],
    );
  }

  Widget _buildRail({
    required String title,
    required int tab,
    required String section,
    required bool loading,
    required Widget Function() rail,
  }) {
    final failed = _home.failedSections.contains(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleRow3D(title: title, action: 'See all', onAction: () => _auth.switchToTab(tab)),
        SkeletonSwitcher(
          loading: loading,
          skeleton: _buildRailSkeleton(),
          child: failed
              ? _railErrorMessage(() => _home.reloadSections({section}))
              : rail(),
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

  Widget _emptyRailMessage(String text, {String asset = TravelIcon.stay, KitTone tone = KitTone.stay}) =>
      _railMessage(
        child: StateCard(
          title: 'Nothing here yet',
          message: text,
          asset: asset,
          kit: tone,
          padding: DS.sym(h: 16, v: 12),
        ),
      );

  Widget _railErrorMessage(VoidCallback onRetry) => _railMessage(
        onTap: onRetry,
        child: StateCard.error(
          title: "Couldn't load",
          message: 'Tap to retry',
          padding: DS.sym(h: 16, v: 12),
        ),
      );

  Widget _railMessage({required Widget child, VoidCallback? onTap}) => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(4), DS.s(18), DS.gv(16)),
        child: SectionTile(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: SizedBox(width: double.infinity, child: child),
        ),
      );

  Future<void> _postJob() async {
    if (_auth.user.value?.stayStatus != 'Approved') {
      AppToast.info('Stay must be live first');
      return;
    }
    final result = await Get.toNamed(AppRoutes.postJob);
    if (result == true) MyJobsController.invalidateList();
  }

  Widget _buildPlanNudge() {
    final plans = Get.find<PlanController>();
    return Obx(() {
      final me = plans.myPlan.value;
      final play = me.play;
      final days = me.daysLeft;
      String? message;
      String action = 'Renew';
      if (play != null && play.needsFix) {
        message = PlanStateCopy.status(me);
        action = PlanStateCopy.action(me);
      } else if (play != null && play.ownsActivePlan) {
        final at = play.expiryAt ?? me.endsAt;
        if (!play.renewsAutomatically && at != null && days != null && days <= 7) {
          message = 'Ends on ${PlanStateCopy.date(at)}';
          action = 'Resubscribe';
        }
      } else if (me.hasPaidPlan && days != null && days <= 7) {
        message = days <= 0 ? 'Plan ends today' : 'Plan ends in $days day${days == 1 ? '' : 's'}';
      }
      if (!me.paymentEnabled || message == null) return const SizedBox.shrink();
      final tone = ListingTone.cF;
      return WideCard(
        kind: WideKind.slim,
        tone: tone,
        art: ListingArt.calendar,
        title: message,
        trailing: _WhitePill(label: action, color: tone.button),
        onTap: () => Get.toNamed(AppRoutes.plansBilling),
      );
    });
  }

  Widget _buildOwnerQuickActions() {
    return Obx(() {
      final stays = _auth.staysEnabled;
      final taxis = _auth.taxisEnabled;
      final jobs = _auth.jobsEnabled;
      final tiles = <Widget>[
        if (stays)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddStay,
            child: _ownerQuickActionTile(
              art: ListingArt.stay,
              tone: ListingTone.forest,
              plus: true,
              label: 'Add Stay',
              description: 'List a new stay',
              onTap: StayFlow.start,
            ),
          ),
        if (taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddTaxi,
            child: _ownerQuickActionTile(
              art: ListingArt.taxi,
              tone: ListingTone.coral,
              plus: true,
              label: 'Add Taxi',
              description: 'List your taxi',
              onTap: () => TaxiFlow.start(),
            ),
          ),
        if (stays || taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionLeads,
            child: _ownerQuickActionTile(
              art: ListingArt.clipboard,
              tone: ListingTone.cC,
              label: stays ? 'My Stays' : 'My Taxi',
              description: stays ? 'Manage your stays' : 'Manage your taxi',
              onTap: () => Get.toNamed(stays ? AppRoutes.myStays : AppRoutes.myTaxi),
            ),
          ),
        if (jobs) ...[
          _ownerQuickActionTile(
            art: ListingArt.pushpin,
            tone: ListingTone.cD,
            plus: true,
            label: 'Post Job',
            description: 'Hire for your stay',
            onTap: _postJob,
          ),
          _ownerQuickActionTile(
            art: ListingArt.clipboard,
            tone: ListingTone.cD,
            label: 'My Jobs',
            description: 'Your job posts',
            onTap: () => Get.toNamed(AppRoutes.myJobs),
          ),
        ],
      ];
      if (tiles.isEmpty) return const SizedBox.shrink();
      return MealsRail(physics: const BouncingScrollPhysics(), children: tiles);
    });
  }

  Widget _ownerQuickActionTile({
    required String art,
    required ListingTone tone,
    required String label,
    required String description,
    required VoidCallback? onTap,
    bool plus = false,
  }) {
    return MealsCardV(
      tone: tone,
      art: art,
      title: label,
      description: description,
      goIcon: plus ? Icons.add : Icons.arrow_forward,
      onTap: onTap,
      semanticsLabel: label,
    );
  }

  Widget _buildRecentlyAddedSection() {
    return Obx(() {
      if (!_tabs.isStaysActive) return const SizedBox.shrink();
      final loading = _home.recentlyAddedStaysLoading.value;
      final items = loading ? const <HomeRecentItem>[] : _home.recentMixed();
      final failed = {HomeSectionKeys.recentStays}.where(_home.failedSections.contains).toSet();

      final Widget body;
      if (items.isEmpty && failed.isNotEmpty) {
        body = _railErrorMessage(() => _home.reloadSections(failed));
      } else if (items.isEmpty) {
        body = _emptyRailMessage('No stays added yet.');
      } else {
        body = Column(
          children: [
            for (var i = 0; i < items.length; i++) EntranceOnce(index: i, offset: 50, child: _recentRow(items[i], i)),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TitleRow3D(title: 'Recently added stays'),
          SkeletonSwitcher(
            loading: loading,
            skeleton: const Column(children: [WideCardSkeleton(kind: WideKind.photo), WideCardSkeleton(kind: WideKind.photo), WideCardSkeleton(kind: WideKind.photo)]),
            child: body,
          ),
        ],
      );
    });
  }

  static final List<ListingTone> _recentTones = [ListingTone.cE, ListingTone.cF, ListingTone.cB];

  Widget _recentRow(HomeRecentItem item, int index) {
    final s = item.stay;
    if (s == null) return const SizedBox.shrink();
    final url = s.item.thumbnailUrl;
    void open() => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.item.id});
    return WideCard(
      kind: WideKind.photo,
      tone: _recentTones[index % _recentTones.length],
      photo: url == null || url.isEmpty ? null : SizedBox.expand(child: KitPhoto(url: url, width: double.infinity, height: double.infinity)),
      sticker: ListingArt.stay,
      badge: s.item.isFeatured ? 'Featured' : null,
      tag: s.item.tagLabel,
      title: s.item.title,
      subtitle: s.districtName.isNotEmpty ? s.districtName : s.item.locationLabel,
      reserveChips: false,
      priceCaption: s.item.priceCaption,
      number: s.item.priceValue,
      unit: s.item.priceUnit,
      onGo: open,
      onTap: open,
    );
  }

  Widget _buildInstagramCard() {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: KeyedSubtree(
        key: TourKeys.homeInstagramCard,
        child: WorkoutCard(
          tone: ListingTone.cD,
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

class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.circular(22), boxShadow: DS.shadows(Ink3D.whiteBtn)),
      child: Padding(
        padding: DS.sym(h: 14, v: 8),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, color)),
      ),
    );
  }
}
