import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/plan_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/design.dart';
import '../config/app_tabs.dart';
import '../navigation/tour_keys.dart';
import '../features/jobs/controllers/my_jobs_controller.dart';
import '../features/stay/setup/stay_flow.dart';
import '../features/taxi/models/taxi_browse_item.dart';
import '../features/taxi/setup/taxi_flow.dart';
import '../features/trip/widgets/trip_home_card.dart';
import '../features/trip/widgets/trip_popular_rail.dart';
import '../utils/app_toast.dart';
import '../widgets/home_owner_carousel.dart';
import '../widgets/home_stay_rail_card.dart';
import '../widgets/home_taxi_rail_card.dart';
import '../widgets/nearby_item_row.dart';
import '../widgets/plan_subscription_card.dart';

const double _railHeight = HomeStayRailCard.railHeight;
const double _tileHeight = 168;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sections = 8;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _barOpacity = ValueNotifier<double>(0);
  final ValueNotifier<double> _barHeight = ValueNotifier<double>(0);
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);
  final GlobalKey _barKey = GlobalKey();

  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();
  final _tabs = Get.find<TabConfigController>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = (_scroll.offset / 24).clamp(0.0, 1.0);
      if (o != _barOpacity.value) _barOpacity.value = o;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _barOpacity.dispose();
    _barHeight.dispose();
    _replay.dispose();
    super.dispose();
  }

  void _measureBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _barKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      if ((box.size.height - _barHeight.value).abs() > 0.5) _barHeight.value = box.size.height;
    });
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

  Widget _gap(double h) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    final inset = AppInsets.topViewPadding(context);
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: TabEntrance(
        tab: AppTabs.home,
        child: Stack(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _barHeight,
              builder: (context, barHeight, _) {
                final top = (barHeight > 0 ? barHeight : inset + 84) + 8;
                return RefreshIndicator(
                  color: DesignColors.primary,
                  edgeOffset: top - 8,
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.only(top: top, bottom: _bottomClear(context)),
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
                              child: const HomeOwnerCarousel(),
                            ),
                          ),
                          StaggerItem(index: 1, child: _buildPlanNudge()),
                          StaggerItem(index: 2, child: _buildOwnerQuickActions()),
                          StaggerItem(index: 3, child: _buildTripCard()),
                          _gap(16),
                          StaggerItem(index: 4, child: const TripPopularRail()),
                          _gap(8),
                          StaggerItem(index: 5, child: _buildInstagramCard()),
                          _gap(16),
                          StaggerItem(index: 6, child: _buildListingsSections()),
                          StaggerItem(index: 7, child: _buildRecentlyAddedSection()),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: EntranceOnce(child: _buildTopBar(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _barOpacity,
      builder: (BuildContext context, double opacity, Widget? _) {
        if (opacity == 0) _measureBar();
        return Container(
          key: opacity == 0 ? _barKey : null,
          decoration: BoxDecoration(
            color: DesignColors.tint(DesignColors.surface, opacity),
            borderRadius: CardRadius.header,
            boxShadow: <BoxShadow>[
              ShadowTokens.tint(DesignColors.shadowBase, ShadowSpec.strong.scaled(opacity)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: KitMetrics.gutter,
              right: KitMetrics.gutter,
              top: AppInsets.topViewPadding(context) + 16 - 8.0 * opacity,
              bottom: 12 - 8.0 * opacity,
            ),
            child: _buildHero(context, opacity),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, double opacity) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Obx(() {
            final name = _auth.profileName.value;
            final firstName = name.trim().isNotEmpty ? name.trim().split(' ').first : 'there';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $firstName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(
                    22 + 6 - 6 * opacity,
                    FontWeight.w700,
                    color: DesignColors.textStrong,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Where to next?',
                  style: TypeTokens.style(14, FontWeight.w500, color: TypeTokens.secondary, letterSpacing: 0.4),
                ),
              ],
            );
          }),
        ),
        const SizedBox(width: 12),
        _buildHeaderIcons(),
      ],
    );
  }

  Widget _buildHeaderIcons() {
    return Row(
      key: TourKeys.homeActionMenu,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerIconButton(
          icon: 'fitness_app/bell.png',
          unreadCount: Get.find<NotificationController>().unreadCount,
          onTap: () => Get.toNamed(AppRoutes.notifications),
        ),
        const SizedBox(width: 8),
        _headerIconButton(
          icon: 'travel3d/speech_balloon.png',
          unreadCount: Get.find<ChatController>().unreadCount,
          onTap: () => Get.toNamed(AppRoutes.chatsList),
        ),
      ],
    );
  }

  Widget _headerIconButton({
    required String icon,
    required VoidCallback onTap,
    RxInt? unreadCount,
  }) {
    return PressScale(
      child: SizedBox(
        width: KitMetrics.touch,
        height: KitMetrics.touch,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.surfaceAlt,
                boxShadow: [
                  ShadowTokens.tint(DesignColors.primary, const ShadowSpec(0.4, Offset(4, 4), 8)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: DesignColors.splash,
                  highlightColor: Colors.transparent,
                  onTap: onTap,
                  child: Center(
                    child: Image.asset('assets/images/design/$icon', width: 22, height: 22),
                  ),
                ),
              ),
            ),
            if (unreadCount != null)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: Obx(() {
                    final count = unreadCount.value;
                    if (count <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: const BoxDecoration(
                        color: DesignColors.error,
                        borderRadius: CardRadius.pill,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.onPrimary),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String action = '', VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong)),
          ),
          if (action.isNotEmpty)
            InkWell(
              onTap: onTap,
              borderRadius: CardRadius.chip,
              splashColor: DesignColors.splash,
              highlightColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: KitMetrics.touch),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(action, style: TypeTokens.style(14, FontWeight.w600, color: DesignColors.primary)),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: DesignColors.primary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListingsSections() {
    return Obx(() {
      final rails = <Widget>[
        if (_tabs.isStaysActive)
          _buildRail(
            title: 'Stays near you',
            tab: AppTabs.stays,
            section: HomeSectionKeys.stays,
            loading: _home.staysLoading.value,
            rail: () => _buildStaysRail(_home.stays),
          ),
        if (_tabs.isTaxiActive)
          _buildRail(
            title: 'Taxis near you',
            tab: AppTabs.taxi,
            section: HomeSectionKeys.taxis,
            loading: _home.taxisLoading.value,
            rail: () => _buildTaxisRail(_home.taxis),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rail in rails) Padding(padding: const EdgeInsets.only(bottom: 4), child: rail),
        ],
      );
    });
  }

  Widget _buildStaysRail(List<HomeStayModel> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No stays listed here yet.', asset: TravelIcon.stay);
    }
    return SizedBox(
      height: _railHeight,
      child: RailReveal(
        itemCount: items.length,
        itemBuilder: (_, i) => HomeStayRailCard(stay: items[i]),
        physics: const BouncingScrollPhysics(),
      ),
    );
  }

  Widget _buildTaxisRail(List<TaxiBrowseItem> items) {
    if (items.isEmpty) {
      return _emptyRailMessage('No taxis listed here yet.', asset: TravelIcon.taxi, tone: KitTone.taxi);
    }
    return SizedBox(
      height: _railHeight,
      child: RailReveal(
        itemCount: items.length,
        itemBuilder: (_, i) => HomeTaxiRailCard(taxi: items[i]),
        physics: const BouncingScrollPhysics(),
      ),
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
        _sectionTitle(title, action: 'View all', onTap: () => _auth.switchToTab(tab)),
        const SizedBox(height: 4),
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
    return SizedBox(
      height: _railHeight,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: KitMetrics.cardGap),
        itemBuilder: (_, _) => Padding(
          padding: HomeStayRailCard.cellPadding,
          child: RailCard.skeleton(),
        ),
      ),
    );
  }

  Widget _emptyRailMessage(String text, {String asset = TravelIcon.stay, KitTone tone = KitTone.stay}) =>
      _railMessage(
        child: StateCard(
          title: 'Nothing here yet',
          message: text,
          asset: asset,
          kit: tone,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

  Widget _railErrorMessage(VoidCallback onRetry) => _railMessage(
        onTap: onRetry,
        child: const StateCard.error(
          title: "Couldn't load",
          message: 'Tap to retry',
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

  Widget _railMessage({required Widget child, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 4, KitMetrics.gutter, 16),
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
      return SlimBar(
        title: message,
        tone: KitTone.taxi,
        filled: true,
        margin: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, 12),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignColors.whiteSoft),
          child: const Icon(Icons.schedule_rounded, size: 20, color: DesignColors.onPrimary),
        ),
        trailing: Text(action, style: TypeTokens.style(12, FontWeight.w700, color: DesignColors.onPrimary)),
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
              asset: TravelIcon.stay,
              tone: KitTone.stay,
              plus: true,
              label: 'Add Stay',
              onTap: StayFlow.start,
            ),
          ),
        if (taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionAddTaxi,
            child: _ownerQuickActionTile(
              asset: TravelIcon.taxi,
              tone: KitTone.taxi,
              plus: true,
              label: 'Add Taxi',
              onTap: () => TaxiFlow.start(),
            ),
          ),
        if (stays || taxis)
          KeyedSubtree(
            key: TourKeys.homeQuickActionLeads,
            child: _ownerQuickActionTile(
              asset: TravelIcon.checkout,
              tone: KitTone.rose,
              label: stays ? 'My Stays' : 'My Taxi',
              onTap: () => Get.toNamed(stays ? AppRoutes.myStays : AppRoutes.myTaxi),
            ),
          ),
        if (jobs) ...[
          _ownerQuickActionTile(
            asset: TravelIcon.pin,
            tone: KitTone.jobs,
            plus: true,
            label: 'Post Job',
            onTap: _postJob,
          ),
          _ownerQuickActionTile(
            asset: TravelIcon.note,
            tone: KitTone.jobs,
            label: 'My Jobs',
            onTap: () => Get.toNamed(AppRoutes.myJobs),
          ),
        ],
      ];
      if (tiles.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: _tileHeight + 24,
        child: RailReveal(
          itemCount: tiles.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: tiles[i],
          ),
        ),
      );
    });
  }

  Widget _ownerQuickActionTile({
    required String asset,
    required KitTone tone,
    required String label,
    required VoidCallback? onTap,
    bool plus = false,
  }) {
    return GradientIconCard(
      title: label,
      iconAsset: asset,
      startColor: tone.gradient.colors.first,
      endColor: tone.gradient.colors.last,
      showPlus: plus,
      onTap: onTap,
      width: 130,
      height: _tileHeight,
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
            for (var i = 0; i < items.length; i++) EntranceOnce(index: i, offset: 50, child: _recentRow(items[i])),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Recently added stays'),
          const SizedBox(height: 6),
          SkeletonSwitcher(
            loading: loading,
            skeleton: Column(children: [for (var i = 0; i < 3; i++) ListRow.skeleton()]),
            child: body,
          ),
        ],
      );
    });
  }

  Widget _recentRow(HomeRecentItem item) {
    final s = item.stay;
    if (s == null) return const SizedBox.shrink();
    return NearbyItemRow(
      thumbnailUrl: s.item.thumbnailUrl,
      tag: s.item.tagLabel,
      title: s.item.title,
      subtitle: s.districtName.isNotEmpty ? s.districtName : s.item.locationLabel,
      caption: s.item.priceCaption,
      value: s.item.priceValue,
      unit: s.item.priceUnit,
      placeholderIcon: Icons.home_rounded,
      isFeatured: s.item.isFeatured,
      onTap: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.item.id}),
    );
  }

  Widget _buildTripCard() => const TripHomeCard();

  Widget _buildInstagramCard() {
    return KeyedSubtree(
      key: TourKeys.homeInstagramCard,
      child: SlimBar(
        title: 'Follow us on Instagram',
        tone: KitTone.jobs,
        filled: true,
        leadingAsset: TravelIcon.photo,
        onTap: _openInstagram,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(color: DesignColors.surfaceAlt, borderRadius: CardRadius.pill),
          child: Text('Follow', style: TypeTokens.style(12, FontWeight.w700, color: KitTone.jobs.accentDark)),
        ),
      ),
    );
  }
}
