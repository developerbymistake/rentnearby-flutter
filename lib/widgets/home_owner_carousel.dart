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

  static const EdgeInsets pagePadding = EdgeInsets.only(bottom: 12);

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
      final n = slides.length;
      Widget page(int i) => Padding(
            padding: HomeOwnerCarousel.pagePadding,
            child: _OwnerBanner(slide: slides[i % n], isOwner: owner, count: n, index: i % n),
          );
      final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: n == 1
            ? page(0)
            : Stack(
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
      );
    });
  }
}

class _OwnerBanner extends StatelessWidget {
  final _Slide slide;
  final bool isOwner;
  final int count;
  final int index;

  const _OwnerBanner({required this.slide, required this.isOwner, required this.count, required this.index});

  static ListingTone toneOf(_Slide slide) => switch (slide) {
    _Slide.stay => ListingTone.forest,
    _Slide.taxi => ListingTone.coral,
  };

  static String artOf(_Slide slide) => switch (slide) {
    _Slide.stay => ListingArt.hotel,
    _Slide.taxi => ListingArt.taxi,
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
    return WorkoutCard(
      tone: toneOf(slide),
      art: artOf(slide),
      eyebrow: isOwner ? RoleVisuals.displayName(key) : seekerBadge,
      title: isOwner ? ownerTitleOf(slide) : seekerTitle,
      subtitle: isOwner ? 'Grow your reach' : seekerSubtitle,
      ctaLabel: isOwner ? 'List Yours' : seekerCta,
      trailing: count > 1 ? WorkoutTrailing.dots : WorkoutTrailing.none,
      dotCount: count,
      dotIndex: index,
      onTap: isOwner
          ? () => Get.toNamed(ownerRouteOf(slide))
          : () => Get.find<AuthController>().switchToTab(tabOf(slide)),
    );
  }
}
