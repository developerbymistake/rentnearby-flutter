import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../design/design.dart';
import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/storage_service.dart';
import 'intro_slide_a.dart';
import 'intro_slide_b.dart';
import 'intro_strings.dart';
import 'intro_widgets.dart';

typedef IntroSlideBuilder = Widget Function(bool isActive, ValueListenable<double> progress);

class IntroScaffold extends StatefulWidget {
  const IntroScaffold({super.key, this.onFinish, this.autoplay = true});

  final VoidCallback? onFinish;
  final bool autoplay;

  static const int pageCount = 6;
  static const Duration autoplayInterval = Duration(milliseconds: 5600);
  static const Duration pageAnim = templateTransitionDuration;

  @override
  State<IntroScaffold> createState() => _IntroScaffoldState();
}

class _IntroScaffoldState extends State<IntroScaffold> with TickerProviderStateMixin {
  static final List<IntroSlideBuilder> _slides = [
    (a, p) => IntroSlidePick(isActive: a, progress: p),
    (a, p) => IntroSlidePlan(isActive: a, progress: p),
    (a, p) => IntroSlideAsk(isActive: a, progress: p),
    (a, p) => IntroSlideTaxi(isActive: a, progress: p),
    (a, p) => IntroSlideLive(isActive: a, progress: p),
    (a, p) => IntroSlideStart(isActive: a, progress: p),
  ];

  static const int _last = IntroScaffold.pageCount - 1;

  final PageController _pageController = PageController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  late final AnimationController _autoplay;

  int currentPage = 0;
  int _settledPage = 0;
  bool _userDragging = false;
  bool _autoPaused = false;
  bool _autoMove = false;
  bool _finishing = false;
  bool _reduce = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _autoplay = AnimationController(vsync: this, duration: IntroScaffold.autoplayInterval)
      ..addStatusListener(_onAutoplayStatus);
    _pageController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = introReduceMotion(context);
    if (!_initialised || reduce != _reduce) {
      _initialised = true;
      _reduce = reduce;
      _armAutoplay();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _autoplay.dispose();
    _progress.dispose();
    super.dispose();
  }

  double _pageValue() {
    final c = _pageController;
    if (c.hasClients && c.position.haveDimensions && c.page != null) return c.page!;
    return currentPage.toDouble();
  }

  void _onScroll() => _progress.value = _pageValue();

  void _armAutoplay() {
    if (widget.autoplay && !_reduce && currentPage < _last && !_autoPaused && !_userDragging) {
      _autoplay.forward(from: 0);
    } else {
      _autoplay.reset();
    }
  }

  void _onAutoplayStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _userDragging || _autoPaused || !_pageController.hasClients) return;
    if (currentPage >= _last) return;
    _autoMove = true;
    _pageController.animateToPage(
      currentPage + 1,
      duration: IntroScaffold.pageAnim,
      curve: Curves.fastOutSlowIn,
    );
  }

  void _onPageChanged(int i) {
    setState(() {
      currentPage = i;
      _autoPaused = false;
    });
    _armAutoplay();
    if (_reduce) _settle();
  }

  void _settle() {
    if (currentPage == _settledPage) return;
    if (!_autoMove) HapticFeedback.selectionClick();
    _settledPage = currentPage;
    _autoMove = false;
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _autoMove = false;
      _autoplay.reset();
      _userDragging = true;
    } else if (n is ScrollEndNotification) {
      if (_userDragging) {
        _userDragging = false;
        _armAutoplay();
      }
      _settle();
    }
    return false;
  }

  bool _onInteraction(IntroInteractionNotification n) {
    _autoPaused = true;
    _autoplay.reset();
    return true;
  }

  void _goTo(int page) {
    if (!_pageController.hasClients) return;
    final target = page.clamp(0, _last);
    _autoMove = false;
    if (_reduce) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(target, duration: IntroScaffold.pageAnim, curve: Curves.fastOutSlowIn);
    }
  }

  void _next() {
    if (currentPage < _last) {
      _goTo(currentPage + 1);
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    _autoplay.stop();
    if (currentPage >= _last) HapticFeedback.mediumImpact();
    final onFinish = widget.onFinish;
    if (onFinish != null) {
      onFinish();
      return;
    }
    StorageService.saveTourSeen(AppConstants.introCarouselSeenKey);
    Get.offAllNamed(AppRoutes.login);
  }

  Widget _background() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, _) {
          final p = _pageValue().clamp(0.0, _last.toDouble());
          final i = p.floor();
          final j = math.min(i + 1, _last);
          final t = p - i;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(IntroPalette.top[i], IntroPalette.top[j], t)!,
                  Color.lerp(IntroPalette.bottom[i], IntroPalette.bottom[j], t)!,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final isLast = currentPage >= _last;
    final bottomReserve = 124 + viewPadding.bottom;
    final topReserve = viewPadding.top + 56;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: DesignColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: DesignColors.primary,
          body: Stack(
            children: [
              Positioned.fill(child: _background()),
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: NotificationListener<IntroInteractionNotification>(
                    onNotification: _onInteraction,
                    child: PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      children: [
                        for (var i = 0; i < IntroScaffold.pageCount; i++)
                          KeyedSubtree(
                            key: ValueKey('intro_page_$i'),
                            child: IntroPageChrome(
                              index: i,
                              isActive: i == currentPage,
                              progress: _progress,
                              copy: IntroStrings.slides[i],
                              graphic: _slides[i](i == currentPage, _progress),
                              bottomReserve: bottomReserve,
                              topReserve: topReserve,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: viewPadding.top + 8,
                right: 16,
                child: IgnorePointer(
                  ignoring: isLast,
                  child: ExcludeSemantics(
                    excluding: isLast,
                    child: AnimatedOpacity(
                      opacity: isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IntroPillButton(
                        key: const Key('intro_skip'),
                        label: IntroStrings.skip,
                        onTap: _finish,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * 0.12,
                right: width * 0.12,
                bottom: 24 + 52 + 14 + viewPadding.bottom,
                height: 34,
                child: RepaintBoundary(
                  child: IntroJourneyThread(
                    key: const Key('intro_thread'),
                    progress: _progress,
                    currentPage: currentPage,
                    pageCount: IntroScaffold.pageCount,
                    autoplayFill: _autoplay,
                    onStopTap: _goTo,
                    onTaxiTap: () {
                      if (currentPage < _last) _goTo(currentPage + 1);
                    },
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24 + viewPadding.bottom,
                height: 52,
                child: IntroCtaButton(
                  key: const Key('intro_cta'),
                  progress: _progress,
                  isLast: isLast,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
