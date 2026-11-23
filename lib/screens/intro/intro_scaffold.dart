import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../design/design.dart';
import '../../design/extra/ext_auth.dart';
import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/storage_service.dart';
import 'intro_strings.dart';
import 'intro_widgets.dart';
import 'story/intro_story_art.dart';
import 'story/intro_story_math.dart';
import 'story/intro_story_scene.dart';
import 'story/intro_story_state.dart';

class IntroScaffold extends StatefulWidget {
  const IntroScaffold({super.key, this.onFinish, this.autoplay = true});

  final VoidCallback? onFinish;
  final bool autoplay;

  static const int pageCount = 6;
  static const Duration autoplayInterval = Duration(milliseconds: 5600);
  static const Duration pageAnim = Duration(milliseconds: 900);

  @override
  State<IntroScaffold> createState() => _IntroScaffoldState();
}

class _IntroScaffoldState extends State<IntroScaffold> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _last = IntroScaffold.pageCount - 1;
  static const Curve _pageCurve = IntroSpringCurve();

  final PageController _pageController = PageController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final IntroStoryState _story = IntroStoryState();
  late final AnimationController _autoplay;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  int currentPage = 0;
  int _settledPage = 0;
  bool _userDragging = false;
  bool _autoMove = false;
  bool _finishing = false;
  bool _reduce = false;
  bool _initialised = false;
  bool _foreground = true;
  double _artScale = 0;

  @override
  void initState() {
    super.initState();
    _autoplay = AnimationController(vsync: this, duration: IntroScaffold.autoplayInterval)..addStatusListener(_onAutoplayStatus);
    _ticker = createTicker(_onTick);
    _pageController.addListener(_onScroll);
    _story.setProgress(0);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = introReduceMotion(context);
    if (!_initialised || reduce != _reduce) {
      _initialised = true;
      _reduce = reduce;
      _story.reduce = reduce;
      _story.setProgress(_pageValue());
      _armAutoplay();
      _syncTicker();
    }
    _loadArt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _autoplay.dispose();
    _progress.dispose();
    _story.dispose();
    IntroStoryArt.instance.release();
    super.dispose();
  }

  void _loadArt() {
    final mq = MediaQuery.of(context);
    final scale = mq.size.width / 360;
    if (scale <= 0 || scale == _artScale) return;
    _artScale = scale;
    final art = IntroStoryArt.instance;
    final pending = art.load(scale, mq.devicePixelRatio);
    if (art.ready.value) {
      _story.onArtReady();
      return;
    }
    pending.then((_) {
      if (mounted && IntroStoryArt.instance.ready.value) _story.onArtReady();
    });
  }

  void _syncTicker() {
    final run = !_reduce && !_finishing && _foreground;
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, .05);
    _lastTick = elapsed;
    _story.tick(dt);
  }

  double _pageValue() {
    final c = _pageController;
    if (c.hasClients && c.position.haveDimensions && c.page != null) return c.page!;
    return currentPage.toDouble();
  }

  void _onScroll() {
    final p = _pageValue();
    _progress.value = p;
    _story.setProgress(p);
  }

  void _armAutoplay() {
    if (widget.autoplay && !_reduce && currentPage < _last && !_userDragging) {
      _autoplay.forward(from: 0);
    } else {
      _autoplay.reset();
    }
  }

  void _onAutoplayStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _userDragging || !_pageController.hasClients) return;
    if (currentPage >= _last) return;
    _autoMove = true;
    _pageController.animateToPage(currentPage + 1, duration: IntroScaffold.pageAnim, curve: _pageCurve);
  }

  void _onPageChanged(int i) {
    setState(() => currentPage = i);
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

  void _goTo(int page) {
    if (!_pageController.hasClients) return;
    final target = page.clamp(0, _last);
    _autoMove = false;
    if (_reduce) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(target, duration: IntroScaffold.pageAnim, curve: _pageCurve);
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
    _syncTicker();
    if (currentPage >= _last) HapticFeedback.mediumImpact();
    final onFinish = widget.onFinish;
    if (onFinish != null) {
      onFinish();
      return;
    }
    StorageService.saveTourSeen(AppConstants.introCarouselSeenKey);
    Get.offAllNamed(AppRoutes.login);
  }

  Widget _skip() {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, p, child) {
        final gone = p > 4.7;
        return IgnorePointer(
          ignoring: gone,
          child: ExcludeSemantics(
            excluding: gone,
            child: Opacity(opacity: 1 - smooth((p - 4.4) / .4), child: child),
          ),
        );
      },
      child: IntroPillButton(key: const Key('intro_skip'), label: IntroStrings.skip, onTap: _finish),
    );
  }

  Widget _overlayStyle(Widget child) {
    return ValueListenableBuilder<double>(
      valueListenable: _progress,
      child: child,
      builder: (context, p, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (p > 4.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: DesignColors.onPrimary,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage >= _last;
    return _overlayStyle(
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: AuthInk.page,
          body: LayoutBuilder(builder: (context, c) {
            final pad = MediaQuery.viewPaddingOf(context);
            final size = c.biggest;
            final metrics = IntroPanelMetrics.measure(
              width: size.width,
              screenHeight: size.height,
              bottomInset: pad.bottom,
              scaler: MediaQuery.textScalerOf(context),
            );
            final panelTop = size.height - metrics.height;
            final ctaBottom = IntroPanelMetrics.ctaBottom + pad.bottom;
            return Stack(
              children: [
                Positioned.fill(child: IntroStoryScene(state: _story, progress: _progress, panelTop: panelTop)),
                Positioned(left: 0, right: 0, top: panelTop, bottom: 0, child: const IgnorePointer(child: IntroPanel())),
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: PageView(
                      controller: _pageController,
                      physics: const IntroPagePhysics(parent: BouncingScrollPhysics()),
                      onPageChanged: _onPageChanged,
                      children: [
                        for (var i = 0; i < IntroScaffold.pageCount; i++)
                          KeyedSubtree(key: ValueKey('intro_page_$i'), child: const SizedBox.expand()),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: IntroPanelMetrics.sideInset,
                  right: IntroPanelMetrics.sideInset,
                  top: panelTop + IntroPanelMetrics.topInset,
                  bottom: ctaBottom + IntroPanelMetrics.ctaHeight,
                  child: IgnorePointer(child: IntroTextBlocks(progress: _progress, compact: metrics.compact)),
                ),
                Positioned(
                  top: pad.top + DS.s(10),
                  left: DS.s(22),
                  right: DS.s(16),
                  child: Row(
                    children: [
                      IntroDots(progress: _progress, count: IntroScaffold.pageCount),
                      const Spacer(),
                      _skip(),
                    ],
                  ),
                ),
                Positioned(
                  left: DS.s(20),
                  right: DS.s(20),
                  bottom: ctaBottom,
                  height: IntroPanelMetrics.ctaHeight,
                  child: IntroCtaButton(key: const Key('intro_cta'), progress: _progress, isLast: isLast, onTap: _next),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
