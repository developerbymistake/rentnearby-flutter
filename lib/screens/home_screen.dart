import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../design/design.dart';
import '../design/extra/instagram_look.dart';
import '../config/app_tabs.dart';
import '../features/seeker_home/seeker_feed_controller.dart';
import '../features/seeker_home/seeker_home_parts.dart';
import '../features/seeker_home/seeker_quick_actions.dart';
import '../features/seeker_home/strings/seeker_home_strings.dart';
import '../features/social/b/rail/trips_to_join_rail.dart';
import '../features/social/b/rail/trips_rail_controller.dart';
import '../features/social/b/widgets/find_buddies_post_card.dart';
import '../features/trip/widgets/trip_popular_rail.dart';
import '../widgets/home_hero_carousel.dart';
import '../widgets/tab_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sections = 6;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _replay = ValueNotifier<int>(0);

  final _home = Get.find<HomeController>();
  final _auth = Get.find<AuthController>();

  SeekerFeedController? get _feed => SeekerFeedController.maybe;

  @override
  void dispose() {
    _scroll.dispose();
    _replay.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final feed = _feed;
    final rail = TripsRailController.maybe;
    await Future.wait<void>([_home.reload(), if (feed != null) feed.reload(), if (rail != null) rail.load()]);
    if (mounted) _replay.value++;
  }

  Future<void> _retryRails() => Future.wait<void>([_home.reload(), if (_feed case final f?) f.reload()]);

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
            subtitle: SeekerHomeStrings.whereToNext,
            color: ListingPalette.sunrise.page,
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
                const StaggerItem(index: 0, child: HomeHeroCarousel()),
                const StaggerItem(index: 1, child: SeekerQuickActions()),
                const StaggerItem(index: 2, child: FindBuddiesPostCard(place: FindBuddiesPostPlace.home)),
                const StaggerItem(index: 3, child: TripsToJoinRail()),
                StaggerItem(index: 4, child: _buildRailsArea()),
                StaggerItem(index: 5, child: _buildInstagramCard()),
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
      final revision = _home.popularVersion.value;
      final failed = _home.railsFailedNoCopy && !_home.anyRailLoading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_auth.canUseTravellerFeatures) Visibility(visible: !failed, maintainState: true, child: TripPopularRail(revision: revision)),
          if (failed) SeekerRailsErrorCard(onRetry: _retryRails),
        ],
      );
    });
  }

  Widget _buildInstagramCard() {
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
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
    );
  }
}
