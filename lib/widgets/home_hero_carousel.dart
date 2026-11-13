import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../config/app_tour_state.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/design.dart';
import '../features/trip/widgets/trip_home_card.dart';
import 'role_option_card.dart';

enum _Slide { trip, stay, taxi }

class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key});

  static const EdgeInsets pagePadding = EdgeInsets.only(bottom: 8);
  static const double dotsBottom = 12;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 4);
  static const _base = 6000;

  final _auth = Get.find<AuthController>();
  final _tabs = Get.find<TabConfigController>();
  final _controller = PageController(initialPage: _base);
  final _workers = <Worker>[];
  Timer? _timer;
  int _page = _base;
  int _count = 0;
  bool _userDragging = false;
  bool _appResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workers.add(ever(_auth.tabIndex, (_) => _sync()));
    _workers.add(ever(tourInProgress, (_) => _sync()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final w in _workers) {
      w.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _sync();
  }

  bool get _canRun =>
      _count > 1 &&
      _appResumed &&
      !_userDragging &&
      !tourInProgress.value &&
      _auth.tabIndex.value == AppTabs.home;

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!mounted || !_canRun) return;
    _timer = Timer.periodic(_interval, (_) {
      // Get.currentRoute is not observable; a route pushed over Home is only detectable by polling.
      if (!mounted || !_controller.hasClients) return;
      if (Get.currentRoute != AppRoutes.main) return;
      _controller.animateToPage(
        _page + 1,
        duration: KitMotion.reduce(context)
            ? Duration.zero
            : templateTransitionDuration,
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  void _onCountChanged(int count) {
    _count = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _page = _base;
      if (_count > 1 && _controller.hasClients) _controller.jumpToPage(_base);
      _sync();
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
      _sync();
    } else if (n is ScrollEndNotification && _userDragging) {
      _userDragging = false;
      _sync();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final owner = _auth.effectiveIsOwner;
      final slides = <_Slide>[
        _Slide.trip,
        if (_tabs.isStaysActive && (!owner || _auth.staysEnabled)) _Slide.stay,
        if (_tabs.isTaxiActive && (!owner || _auth.taxisEnabled)) _Slide.taxi,
      ];
      if (slides.length != _count) _onCountChanged(slides.length);
      if (slides.isEmpty) return const SizedBox.shrink();
      final n = slides.length;
      Widget page(int i) => Padding(
            padding: n == 1 ? const EdgeInsets.only(bottom: HomeHeroCarousel.dotsBottom) : HomeHeroCarousel.pagePadding,
            child: _HeroSlide(slide: slides[i % n], isOwner: owner),
          );
      final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: n == 1
            ? page(0)
            : Column(
                children: [
                  Stack(
                    children: [
                      for (var i = 0; i < n; i++)
                        ExcludeSemantics(
                          child: Visibility(
                            visible: false,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: page(i),
                          ),
                        ),
                      Positioned.fill(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: PageView.builder(
                            controller: _controller,
                            clipBehavior: Clip.none,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (_, i) => page(i),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Dots(count: n, index: _page % n),
                ],
              ),
      );
    });
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HomeHeroCarousel.dotsBottom),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: KitMotion.reduce(context) ? Duration.zero : templateTransitionDuration,
                curve: Curves.fastOutSlowIn,
                width: i == index ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == index ? DesignColors.primary : DesignColors.primary.withValues(alpha: Alpha.soft),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final _Slide slide;
  final bool isOwner;

  const _HeroSlide({required this.slide, required this.isOwner});

  static ListingTone toneOf(_Slide slide) => switch (slide) {
    _Slide.trip => ListingTone.indigo,
    _Slide.stay => ListingTone.forest,
    _Slide.taxi => ListingTone.coral,
  };

  static String artOf(_Slide slide) => switch (slide) {
    _Slide.trip => ListingArt.luggage,
    _Slide.stay => ListingArt.hotel,
    _Slide.taxi => ListingArt.taxi,
  };

  static String roleKeyOf(_Slide slide) => switch (slide) {
    _Slide.stay => UserRoleKeys.stayOwner,
    _ => UserRoleKeys.taxiDriver,
  };

  static (String, String, String) seekerCopyOf(_Slide slide) => switch (slide) {
    _Slide.stay => ('Looking for a stay?', 'Find your stay', 'Browse stays near you'),
    _ => ('Need a taxi?', 'Find a taxi', 'Local taxis near you'),
  };

  static String ownerTitleOf(_Slide slide) => slide == _Slide.stay ? 'List your stay' : 'List your taxi';

  static String ownerRouteOf(_Slide slide) => slide == _Slide.stay ? AppRoutes.myStays : AppRoutes.myTaxi;

  static int tabOf(_Slide slide) => slide == _Slide.stay ? AppTabs.stays : AppTabs.taxi;

  @override
  Widget build(BuildContext context) {
    if (slide == _Slide.trip) return const TripHomeCard(entrance: false);
    final (seekerBadge, seekerTitle, seekerSubtitle) = seekerCopyOf(slide);
    return WorkoutCard(
      tone: toneOf(slide),
      art: artOf(slide),
      eyebrow: isOwner ? RoleVisuals.displayName(roleKeyOf(slide)) : seekerBadge,
      title: isOwner ? ownerTitleOf(slide) : seekerTitle,
      subtitle: isOwner ? 'Grow your reach' : seekerSubtitle,
      trailing: WorkoutTrailing.arrow,
      semanticsLabel: isOwner ? ownerTitleOf(slide) : seekerTitle,
      onTap: isOwner
          ? () => Get.toNamed(ownerRouteOf(slide))
          : () => Get.find<AuthController>().switchToTab(tabOf(slide)),
    );
  }
}
