import 'dart:async';
import 'package:flutter/material.dart';

/// Generic one-slide-at-a-time carousel: swipeable via [PageView], with a
/// pausable autoplay loop and a dot-indicator row (`AnimatedContainer`
/// grow-to-pill, matching listing_detail_screen.dart's photo gallery dots).
/// Degrades gracefully for 0/1 items — no timer/PageView/dots spun up unless
/// there's actually more than one slide to rotate through.
class AutoCarousel<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double height;
  final Duration interval;
  final Duration resumeDelay;
  final double viewportFraction;

  const AutoCarousel({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.height,
    this.interval = const Duration(seconds: 3),
    this.resumeDelay = const Duration(seconds: 3),
    this.viewportFraction = 1.0,
  });

  @override
  State<AutoCarousel<T>> createState() => _AutoCarouselState<T>();
}

class _AutoCarouselState<T> extends State<AutoCarousel<T>> {
  late final _controller = PageController(
    viewportFraction: widget.viewportFraction,
  );
  // A ValueNotifier (not setState) for the current page — only the dot row
  // listens to it, so a page change never rebuilds the PageView itself.
  final _pageNotifier = ValueNotifier<int>(0);
  Timer? _autoplayTimer;
  Timer? _resumeTimer;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't safely resolvable in initState, and this only needs
    // to run once — a later system-setting change taking effect next visit
    // to this screen is an acceptable trade-off for a Home-screen carousel.
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      _stopAutoplay();
    } else if (widget.items.length > 1 && _autoplayTimer == null) {
      _startAutoplay();
    }
  }

  @override
  void didUpdateWidget(covariant AutoCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-arm/disarm autoplay when the item count crosses the 1-item
    // threshold after the initial build (e.g. a catalog force-refresh
    // landing while Home stays mounted) — didChangeDependencies alone only
    // fires on the first build and on inherited-widget changes, never on a
    // plain items-length change.
    final crossedIntoMultiItem =
        oldWidget.items.length <= 1 && widget.items.length > 1;
    final crossedIntoSingleItem =
        oldWidget.items.length > 1 && widget.items.length <= 1;
    if (crossedIntoSingleItem) {
      _stopAutoplay();
      _resumeTimer?.cancel();
    } else if (crossedIntoMultiItem && !_reducedMotion) {
      _startAutoplay();
    }
  }

  void _startAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      final next = (_pageNotifier.value + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _stopAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.resumeDelay, () {
      if (mounted && !_reducedMotion) _startAutoplay();
    });
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    if (widget.items.length == 1) {
      return SizedBox(
        height: widget.height,
        child: widget.itemBuilder(context, widget.items[0], 0),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // dragDetails is only declared on the specific Start/End
                // subclasses (non-null there iff a real user drag caused
                // it) — not on the base ScrollNotification type, so the
                // autoplay-driven animateToPage calls (which produce
                // dragDetails-less notifications) fall through untouched.
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _resumeTimer?.cancel();
                  _stopAutoplay();
                } else if (notification is ScrollEndNotification &&
                    notification.dragDetails != null) {
                  _scheduleResume();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (i) => _pageNotifier.value = i,
                itemBuilder: (ctx, i) =>
                    widget.itemBuilder(ctx, widget.items[i], i),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: _pageNotifier,
            builder: (context, page, _) =>
                _CarouselDots(count: widget.items.length, activeIndex: page),
          ),
        ],
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _CarouselDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: activeIndex == i ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: activeIndex == i
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
