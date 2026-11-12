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
import 'role_option_card.dart';

enum _Slide { stay, taxi }

class HomeOwnerCarousel extends StatefulWidget {
  const HomeOwnerCarousel({super.key});

  static const double bannerHeight = 140;
  static double heightOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 340 ? bannerHeight + 24 : bannerHeight;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    KitMetrics.gutter,
    4,
    KitMetrics.gutter,
    24,
  );

  @override
  State<HomeOwnerCarousel> createState() => _HomeOwnerCarouselState();
}

class _HomeOwnerCarouselState extends State<HomeOwnerCarousel>
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
        if (_tabs.isStaysActive && (!owner || _auth.staysEnabled)) _Slide.stay,
        if (_tabs.isTaxiActive && (!owner || _auth.taxisEnabled)) _Slide.taxi,
      ];
      if (slides.length != _count) _onCountChanged(slides.length);
      if (slides.isEmpty) return const SizedBox.shrink();
      final page = _page % slides.length;
      final height = HomeOwnerCarousel.heightOf(context) + 28;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: slides.length == 1
                ? Padding(
                    padding: HomeOwnerCarousel.pagePadding,
                    child: _OwnerBanner(slide: slides.first, isOwner: owner),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: PageView.builder(
                      controller: _controller,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => Padding(
                        padding: HomeOwnerCarousel.pagePadding,
                        child: _OwnerBanner(
                          slide: slides[i % slides.length],
                          isOwner: owner,
                        ),
                      ),
                    ),
                  ),
          ),
          if (slides.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: KitMotion.reduce(context)
                        ? Duration.zero
                        : templateTransitionDuration,
                    curve: Curves.fastOutSlowIn,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == page ? 20 : 8,
                    decoration: BoxDecoration(
                      color: i == page
                          ? _OwnerBanner.toneOf(slides[page]).accentDark
                          : DesignColors.idleDot,
                      borderRadius: CardRadius.pill,
                    ),
                  ),
              ],
            ),
        ],
      );
    });
  }
}

class _OwnerBanner extends StatelessWidget {
  final _Slide slide;
  final bool isOwner;

  const _OwnerBanner({required this.slide, required this.isOwner});

  static KitTone toneOf(_Slide slide) => switch (slide) {
    _Slide.stay => KitTone.stay,
    _Slide.taxi => KitTone.taxi,
  };

  static String roleKeyOf(_Slide slide) => switch (slide) {
    _Slide.stay => UserRoleKeys.stayOwner,
    _Slide.taxi => UserRoleKeys.taxiDriver,
  };

  static (String, String, String, String) seekerCopyOf(_Slide slide) =>
      switch (slide) {
        _Slide.stay => (
          'Looking for a stay?',
          'Find your stay',
          'Browse stays near you',
          'Browse Stays',
        ),
        _Slide.taxi => (
          'Need a taxi?',
          'Find a taxi',
          'Local taxis near you',
          'Browse Taxis',
        ),
      };

  static String ownerTitleOf(_Slide slide) => switch (slide) {
    _Slide.stay => 'List your stay',
    _Slide.taxi => 'List your taxi',
  };

  static String ownerRouteOf(_Slide slide) => switch (slide) {
    _Slide.stay => AppRoutes.myStays,
    _Slide.taxi => AppRoutes.myTaxi,
  };

  static int tabOf(_Slide slide) => switch (slide) {
    _Slide.stay => AppTabs.stays,
    _Slide.taxi => AppTabs.taxi,
  };

  @override
  Widget build(BuildContext context) {
    final (seekerBadge, seekerTitle, seekerSubtitle, seekerCta) = seekerCopyOf(
      slide,
    );
    final key = roleKeyOf(slide);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.15),
      ),
      child: HeroBanner(
        tone: toneOf(slide),
        height: HomeOwnerCarousel.heightOf(context),
        iconAsset: RoleVisuals.iconAsset(key),
        badge: isOwner ? RoleVisuals.displayName(key) : seekerBadge,
        title: isOwner ? ownerTitleOf(slide) : seekerTitle,
        subtitle: isOwner ? 'Grow your reach' : seekerSubtitle,
        cta: isOwner ? 'List Yours' : seekerCta,
        onTap: isOwner
            ? () => Get.toNamed(ownerRouteOf(slide))
            : () => Get.find<AuthController>().switchToTab(tabOf(slide)),
      ),
    );
  }
}
