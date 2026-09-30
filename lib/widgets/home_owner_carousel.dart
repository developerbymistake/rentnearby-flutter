import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../config/app_tabs.dart';
import '../config/app_tour_state.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import 'floating_loop.dart';
import 'pulse_once.dart';
import 'sweep_highlight.dart';

class HomeOwnerCarousel extends StatefulWidget {
  const HomeOwnerCarousel({super.key});

  @override
  State<HomeOwnerCarousel> createState() => _HomeOwnerCarouselState();
}

class _HomeOwnerCarouselState extends State<HomeOwnerCarousel>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 2);
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
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
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
      final slides = <bool>[
        if (_tabs.isRoomsActive) true,
        if (_tabs.isPlotsActive) false,
      ];
      if (slides.length != _count) _onCountChanged(slides.length);
      if (slides.isEmpty) return const SizedBox.shrink();
      final page = _page % slides.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 160,
            child: slides.length == 1
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _OwnerBanner(isRooms: slides.first),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _OwnerBanner(isRooms: slides[i % slides.length]),
                      ),
                    ),
                  ),
          ),
          if (slides.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    height: 6,
                    width: i == page ? 18 : 6,
                    decoration: BoxDecoration(
                      color: i == page
                          ? (slides[page] ? AppColors.primary : AppColors.plot)
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _OwnerBanner extends StatelessWidget {
  final bool isRooms;

  const _OwnerBanner({required this.isRooms});

  @override
  Widget build(BuildContext context) {
    final accent = isRooms ? AppColors.primary : AppColors.plot;
    final imageGlowColor = isRooms ? AppColors.primary : AppColors.success;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFAFBFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14), width: 1),
        boxShadow: AppShadows.premium(
          AppColors.primary,
          alpha: 0.05,
          blur: 8,
          offset: const Offset(0, 2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 185,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 8),
                      child: Container(
                        width: 84,
                        height: 16,
                        decoration: BoxDecoration(
                          color: imageGlowColor.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                ),
                FloatingLoop(
                  child: SizedBox.expand(
                    child: Image.asset(
                      isRooms
                          ? 'assets/images/owner_cta/house.png'
                          : 'assets/images/owner_cta/plot.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 70, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Are you an Owner?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRooms ? 'List your room' : 'List your plot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Grow your reach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Get.toNamed(
                    isRooms ? AppRoutes.myListings : AppRoutes.myPlots,
                  ),
                  child: PulseOnce(
                    child: SweepHighlight(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add Your Listing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
