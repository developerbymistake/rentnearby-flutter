import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Static, local-asset image strip shown on Home right below the Rooms/Plots
/// toggle — a rounded card like every other section here (CategoryCard/
/// _HomeListingCard's own 16px-radius + soft-shadow recipe), auto-rotating,
/// with a small dot row below mirroring listing_detail_screen's existing
/// photo-gallery dot geometry. Every slide is a bundled local asset (not
/// network), so there's no placeholder/error state to handle.
class HomeBannerCarousel extends StatefulWidget {
  final VoidCallback onTap;

  const HomeBannerCarousel({super.key, required this.onTap});

  static const double height = 148;

  static const List<String> _slides = [
    'assets/images/home_carousel/chardham.jpg',
    'assets/images/home_carousel/yoga.jpg',
    'assets/images/home_carousel/travel.jpg',
    'assets/images/home_carousel/adventure.jpg',
    'assets/images/home_carousel/jimcorbett.jpg',
  ];

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _pageController = PageController();
  Timer? _autoTimer;
  int _currentPage = 0;

  static const _autoAdvanceInterval = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _startAutoTimer();
  }

  // (Re)arms the auto-advance loop — called from initState and again from
  // onPageChanged, so a manual swipe resets the window instead of the timer
  // fighting the user mid-gesture.
  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % HomeBannerCarousel._slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    _startAutoTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = HomeBannerCarousel._slides;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
      children: [
        Container(
          height: HomeBannerCarousel.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => GestureDetector(
                onTap: widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  slides[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: HomeBannerCarousel.height,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == i ? AppColors.primary : AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
