import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../services/storage_service.dart';

/// First-launch pitch carousel — shown once, between Splash and Login, for a
/// user who has never seen the app before. Persisted via
/// StorageService.saveTourSeen(AppConstants.introCarouselSeenKey); see
/// SplashScreen._navigate() for the gate. Never shown to a logged-in user and
/// never shown again once skipped/completed.
class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  static const _pageCount = 4;
  static const _autoAdvanceInterval = Duration(milliseconds: 4800);

  final _pageController = PageController();
  Timer? _autoTimer;
  int _currentPage = 0;
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    _startAutoTimer();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    // Autoplay never wraps past the last content page — this is a linear
    // pitch, not a rotating banner. Looping index 3 (Services) straight back
    // to index 0 (Discover) was the "purple flash" report: a jarring, looks-
    // like-a-glitch jump back to a completely different-coloured page.
    if (_currentPage >= _pageCount - 1) return;
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      // Skip this tick rather than fight an in-progress drag — animateToPage
      // colliding with the user's own active gesture was the other report
      // ("hold a slide and the count goes wrong"). onPageChanged re-arms this
      // timer as soon as the user's own drag settles, so nothing is lost.
      if (!mounted || !_pageController.hasClients || _userDragging) return;
      if (_currentPage >= _pageCount - 1) {
        _autoTimer?.cancel();
        return;
      }
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    _startAutoTimer();
  }

  void _next() {
    if (_currentPage < _pageCount - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    StorageService.saveTourSeen(AppConstants.introCarouselSeenKey);
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLightPage => _currentPage == 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Safety net, not the primary fix: if a drag ever outpaces the page
      // snap for a frame, this is what shows through instead of stark white.
      backgroundColor: const Color(0xFF4338CA),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                _userDragging = true;
              } else if (n is ScrollEndNotification) {
                _userDragging = false;
              }
              return false;
            },
            child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            // Default iOS-style physics rubber-bands past the first/last page,
            // briefly exposing the bare Scaffold behind the PageView — that's
            // the "white screen after the last slide" report. Clamping removes
            // the bounce entirely; the carousel still swipes normally between
            // pages 0-3, it just stops dead at the edges instead of overshooting.
            physics: const ClampingScrollPhysics(),
            children: [
              _DiscoverPage(isActive: _currentPage == 0),
              const _NoBrokerPage(),
              const _GoLivePage(),
              _ServicesPage(isActive: _currentPage == 3),
            ],
            ),
          ),
          if (_currentPage < _pageCount - 1)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: _PillButton(
                  label: 'Skip',
                  onTap: _finish,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  final active = _currentPage == i;
                  final color = _isLightPage
                      ? (active ? AppColors.textDark : AppColors.textDark.withValues(alpha: 0.28))
                      : (active ? Colors.white : Colors.white.withValues(alpha: 0.4));
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  );
                }),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: _CtaButton(
                label: _currentPage == _pageCount - 1 ? 'Get Started' : 'Next',
                onTap: _next,
                primary: _currentPage == _pageCount - 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// GradientButton always renders white text — override with a dark-text variant
// for this screen's white pill, matching the approved mockup's CTA look.
class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// The shared GradientButton always renders white label text, which would be
// invisible on this screen's white pill CTA — a small local button instead,
// matching the approved mockup's white-bg / dark-text look exactly. Only the
// final "Get Started" press gets the app's real primary blue gradient
// instead — every other "Next" stays the plain white pill.
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _CtaButton({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final labelColor = primary ? Colors.white : AppColors.textDark;
    return Material(
      color: primary ? null : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      shadowColor: (primary ? AppColors.primary : Colors.black).withValues(alpha: 0.35),
      child: Ink(
        decoration: BoxDecoration(
          gradient: primary ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18, color: labelColor),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PageChrome extends StatelessWidget {
  final Gradient? gradient;
  final Color? solidColor;
  final Widget graphic;
  final String eyebrow;
  final String headline;
  final String sub;
  final Color textColor;
  final Color eyebrowColor;
  final Color subColor;
  // Lets a page delay its own text block until its graphic's entrance has
  // actually finished (Services' rainbow+icons run well past the default
  // ~250ms this text normally takes) instead of the two overlapping.
  final int textDelayMs;

  const _PageChrome({
    required this.graphic,
    required this.eyebrow,
    required this.headline,
    required this.sub,
    this.gradient,
    this.solidColor,
    this.textColor = Colors.white,
    this.eyebrowColor = Colors.white,
    this.subColor = Colors.white,
    this.textDelayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: gradient, color: solidColor),
      child: SafeArea(
        // This app doesn't lock orientation (main.dart — Android 16+ ignores
        // orientation locks on large screens anyway) and has no dedicated
        // landscape layout anywhere, this screen included. In portrait this
        // content already fits and stays centred exactly as before; in
        // landscape — much less height available — a plain Column would
        // hard-overflow (visible error stripes) instead of just looking
        // cramped. LayoutBuilder + a min-height ConstrainedBox is the
        // standard "centre when it fits, scroll when it doesn't" pattern —
        // same "not tailored, but not broken" bar as the rest of the app.
        // Padding sits OUTSIDE LayoutBuilder so `constraints.maxHeight`
        // already reflects the padded-down space; putting it inside the
        // ScrollView instead double-counted it against the full screen
        // height, which is what pushed everything down with a big top gap.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 130),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
              graphic,
              const SizedBox(height: 22),
              // Eyebrow deliberately does NOT use textDelayMs — it reads as a
              // small static label, not part of the "wait for the graphic"
              // beat, so it shows immediately like every other page's does.
              FadeInUp(
                duration: const Duration(milliseconds: 420),
                child: Text(
                  eyebrow.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: eyebrowColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeInUp(
                duration: const Duration(milliseconds: 480),
                delay: Duration(milliseconds: textDelayMs + 90),
                child: Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.24,
                    letterSpacing: -0.3,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                duration: const Duration(milliseconds: 480),
                delay: Duration(milliseconds: textDelayMs + 170),
                child: Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    height: 1.5,
                    color: subColor,
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 1 — Discover: radar sweep + auto-dragging radius slider
// ============================================================

class _DiscoverPage extends StatefulWidget {
  final bool isActive;
  const _DiscoverPage({super.key, required this.isActive});

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _RadarPin {
  final double distance; // 0..1, radius fraction at which this pin appears
  final double left; // 0..1 position within the radar box
  final double top;
  final String label;
  final List<Color> photoGradient;
  const _RadarPin(this.distance, this.left, this.top, this.label, this.photoGradient);
}

class _DiscoverPageState extends State<_DiscoverPage> with TickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  late final AnimationController _radiusCtrl;
  late final AnimationController _pingCtrl;
  late final Animation<double> _radius;

  static const _radarSize = 202.0; // ~20% bigger than the original 168

  static const _pins = [
    _RadarPin(0.30, 0.20, 0.26, '₹6.5k', [Color(0xFFA5B4FC), Color(0xFF4338CA)]),
    _RadarPin(0.48, 0.80, 0.30, '₹4.2k', [Color(0xFF7DD3FC), Color(0xFF0EA5E9)]),
    _RadarPin(0.63, 0.24, 0.78, 'Plot', [Color(0xFFFDE68A), Color(0xFFF59E0B)]),
    _RadarPin(0.82, 0.78, 0.76, '₹12k', [Color(0xFFC4B5FD), Color(0xFF4338CA)]),
  ];

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _pingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    // Default 0..1 range, driven with repeat(reverse: true) — Flutter's own
    // oscillation machinery, not a hand-rolled animateTo().whenComplete() chain
    // (that chain was the actual cause of the on-device freeze: interrupting it
    // mid-flight via stop()/a fresh animateTo() during a fast page swipe left
    // the controller and the UI thread in a bad state instead of just stopping).
    // The 0..1 progress is curved+remapped to the visual 0.14..0.92 radius
    // range via Tween — Curves expect a 0..1 input, so that remap has to
    // happen after the curve, not by giving the controller itself a custom
    // lowerBound/upperBound (that would feed the curve un-normalized input).
    _radiusCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _radius = Tween<double>(begin: 0.14, end: 0.92)
        .animate(CurvedAnimation(parent: _radiusCtrl, curve: Curves.easeInOutSine));
    if (widget.isActive) _start();
  }

  void _start() {
    _sweepCtrl.repeat();
    _pingCtrl.repeat();
    _radiusCtrl.repeat(reverse: true);
  }

  void _stop() {
    _sweepCtrl.stop();
    _pingCtrl.stop();
    _radiusCtrl.stop();
  }

  @override
  void didUpdateWidget(covariant _DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _start();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stop();
    }
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pingCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageChrome(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4338CA), Color(0xFF0EA5E9)],
      ),
      eyebrow: 'Welcome to Bakhli',
      headline: 'Your Next Address Is\nCloser Than You Think',
      sub: 'Drag the radius — nearby rooms & plots appear as pins.',
      graphic: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _radarSize,
            height: _radarSize,
            child: AnimatedBuilder(
              animation: Listenable.merge([_sweepCtrl, _pingCtrl, _radius]),
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  // rotating sweep beam — Flutter's SweepGradient is the direct
                  // equivalent of the mockup's CSS conic-gradient, same stops.
                  Container(
                    width: _radarSize * 0.72,
                    height: _radarSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                  ),
                  Transform.rotate(
                    angle: _sweepCtrl.value * 2 * math.pi,
                    child: Container(
                      width: _radarSize * 0.72,
                      height: _radarSize * 0.72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0, 296 / 360, 320 / 360, 358 / 360, 0.999, 1.0],
                        ),
                      ),
                    ),
                  ),
                  for (final phase in [_pingCtrl.value, (_pingCtrl.value + 0.5) % 1.0])
                    _PingRing(phase: phase),
                  Container(
                    width: _radarSize * _radius.value,
                    height: _radarSize * _radius.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 4)],
                    ),
                  ),
                  for (final pin in _pins)
                    Align(
                      alignment: Alignment(pin.left * 2 - 1, pin.top * 2 - 1),
                      child: AnimatedScale(
                        scale: _radius.value >= pin.distance ? 1 : 0.3,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _radius.value >= pin.distance ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: _RadarCardPin(pin: pin),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: AnimatedBuilder(
              animation: _radius,
              builder: (context, _) {
                final frac = _radius.value;
                final km = (1 + frac * 14).round();
                final count = _pins.where((p) => frac >= p.distance).length;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text.rich(
                          TextSpan(text: '$km', style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white), children: const [
                            TextSpan(text: 'km', style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white70)),
                          ]),
                        ),
                        Text(
                          count == 1 ? '1 home nearby' : '$count homes nearby',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999))),
                        FractionallySizedBox(
                          widthFactor: frac.clamp(0.0, 1.0),
                          child: Container(height: 5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999))),
                        ),
                        Align(
                          alignment: Alignment(frac * 2 - 1, 0),
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]),
                          ),
                        ),
                        Align(
                          alignment: Alignment(frac * 2 - 1, 0),
                          child: Transform.translate(
                            offset: const Offset(0, -30),
                            child: const Text('👆', style: TextStyle(fontSize: 19)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarCardPin extends StatelessWidget {
  final _RadarPin pin;
  const _RadarCardPin({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 9, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                gradient: LinearGradient(colors: pin.photoGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(pin.label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF4338CA))),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single expanding, fading ring — the radar page uses two of these,
/// half a cycle out of phase, matching the mockup's `.radar-ping`/`.p2` pair
/// (scale .3 -> 5, opacity .65 -> 0, 3.2s each).
class _PingRing extends StatelessWidget {
  final double phase; // 0..1
  const _PingRing({required this.phase});

  @override
  Widget build(BuildContext context) {
    const baseSize = 33.6; // 20% of the 168px radar box, matches mockup
    final size = baseSize * (0.3 + phase * 4.7);
    final opacity = (1 - phase) * 0.65;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 2 — No brokers: owner posts -> seeker finds -> direct chat
// ============================================================

class _NoBrokerPage extends StatelessWidget {
  const _NoBrokerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageChrome(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF97316), Color(0xFFDB2777)],
      ),
      eyebrow: 'No Brokers, Ever',
      headline: 'Talk Directly.\nPay Zero Commission.',
      sub: 'The owner posts, a seeker finds it, they chat — no one in between.',
      graphic: SizedBox(
        height: 144,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ZoomIn(delay: const Duration(milliseconds: 200), child: _StoryFrame(
              child: _OwnerPostsGraphic(),
              label: 'Owner\nposts',
            )),
            _Chevron(delay: const Duration(milliseconds: 650)),
            ZoomIn(delay: const Duration(milliseconds: 850), child: _StoryFrame(
              child: _SeekerFindsGraphic(),
              label: 'Seeker\nfinds it',
            )),
            _Chevron(delay: const Duration(milliseconds: 1300)),
            ZoomIn(delay: const Duration(milliseconds: 1500), child: _StoryFrame(
              child: _DirectChatGraphic(),
              label: 'Direct\nchat',
            )),
          ],
        ),
      ),
    );
  }
}

class _StoryFrame extends StatelessWidget {
  final Widget child;
  final String label;
  const _StoryFrame({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  final Duration delay;
  const _Chevron({required this.delay});

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      delay: delay,
      duration: const Duration(milliseconds: 300),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _OwnerPostsGraphic extends StatelessWidget {
  const _OwnerPostsGraphic();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFFED7AA), Color(0xFFF97316)]),
            ),
          ),
          Positioned(
            top: -5,
            right: -5,
            child: BounceIn(
              delay: const Duration(milliseconds: 550),
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFF059669)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekerFindsGraphic extends StatelessWidget {
  const _SeekerFindsGraphic();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 5, width: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 3),
              Container(height: 8, width: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 3),
              Container(height: 5, width: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3))),
            ],
          ),
          Positioned(
            top: -2,
            right: 0,
            child: BounceIn(
              delay: const Duration(milliseconds: 650),
              child: const Icon(Icons.search_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectChatGraphic extends StatelessWidget {
  const _DirectChatGraphic();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0, left: 2,
            child: Column(children: [
              _Avatar(icon: Icons.home_rounded),
              const SizedBox(height: 3),
              const Text('Owner', style: TextStyle(fontFamily: 'Poppins', fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
          Positioned(
            top: 0, right: 2,
            child: Column(children: [
              _Avatar(icon: Icons.person_rounded),
              const SizedBox(height: 3),
              const Text('Seeker', style: TextStyle(fontFamily: 'Poppins', fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
          Positioned(
            top: 9,
            left: 22,
            right: 22,
            child: Container(height: 1.5, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const Positioned(top: -3, child: _BrokerStrike()),
          Positioned(
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const _SparkBurst(),
                BounceIn(
                  delay: const Duration(milliseconds: 1850),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                    child: const Text('₹0 fee', style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFDB2777))),
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

class _Avatar extends StatelessWidget {
  final IconData icon;
  const _Avatar({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: Icon(icon, size: 12, color: const Color(0xFFDB2777)),
    );
  }
}

/// The briefcase pops in, holds, then gets a red diagonal slash drawn across
/// it and busts away (fade + shrink + rotate) — matches the mockup's
/// `brokerBust`/`slashDraw` keyframe pair, one-shot on mount.
class _BrokerStrike extends StatefulWidget {
  const _BrokerStrike();
  @override
  State<_BrokerStrike> createState() => _BrokerStrikeState();
}

class _BrokerStrikeState extends State<_BrokerStrike> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    Future.delayed(const Duration(milliseconds: 1050), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 22),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_ctrl);
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0), weight: 22),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 40),
    ]).animate(_ctrl);
    final rotation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.24), weight: 40),
    ]).animate(_ctrl);
    final slash = CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.5, curve: Curves.easeOut));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: opacity.value,
        child: Transform.rotate(
          angle: rotation.value,
          child: Transform.scale(
            scale: scale.value,
            child: SizedBox(
              width: 16,
              height: 16,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)),
                    child: const Icon(Icons.work_rounded, size: 11, color: Colors.white),
                  ),
                  CustomPaint(size: const Size(16, 16), painter: _SlashPainter(progress: slash.value)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  final double progress;
  const _SlashPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final start = Offset(size.width * 0.14, size.height * 0.86);
    final end = Offset(size.width * 0.86, size.height * 0.14);
    final current = Offset.lerp(start, end, progress)!;
    canvas.drawLine(
      start,
      current,
      Paint()
        ..color = const Color(0xFFF87171)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SlashPainter old) => old.progress != progress;
}

/// A handful of tiny dots that fly outward and fade — one-shot, timed to the
/// "₹0 fee" badge's own entrance, matching the mockup's spark-particle burst.
class _SparkBurst extends StatefulWidget {
  const _SparkBurst();
  @override
  State<_SparkBurst> createState() => _SparkBurstState();
}

class _SparkBurstState extends State<_SparkBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _offsets = [
    Offset(-30, -16),
    Offset(28, -18),
    Offset(-18, 10),
    Offset(22, 12),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(const Duration(milliseconds: 1850), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        // This Stack sizes itself to its largest non-positioned child (each
        // dot is only 4x4) — without Clip.none the particles self-clip the
        // moment Transform.translate carries them past that tiny box.
        clipBehavior: Clip.none,
        children: [
          for (final o in _offsets)
            Opacity(
              opacity: (1 - _ctrl.value).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: o * _ctrl.value,
                child: Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 3 — Go live: 3-step tracker + Draft -> Live mini listing card
// ============================================================

class _GoLivePage extends StatefulWidget {
  const _GoLivePage({super.key});
  @override
  State<_GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<_GoLivePage> {
  bool _live = false;

  final _cardCtrl = PageController(viewportFraction: 0.8);
  Timer? _cardTimer;

  static const _listings = [
    (photo: [Color(0xFF5EEAD4), Color(0xFF0891B2)], title: '2BHK near Ghantaghar', meta: 'Dehradun · Posted just now'),
    (photo: [Color(0xFFFDE68A), Color(0xFFF59E0B)], title: '1BHK near Paltan Bazaar', meta: 'Dehradun · 2 mins ago'),
    (photo: [Color(0xFFC4B5FD), Color(0xFF4338CA)], title: 'Plot · 3200 sqft', meta: 'Rishikesh · Just now'),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _live = true);
    });
    // Mirrors HomeBannerCarousel's own Timer+PageController auto-advance —
    // this is decorative ("look how many listings go live"), not the primary
    // narrative carousel, so wrap-around looping here is fine/expected.
    _cardTimer = Timer.periodic(const Duration(milliseconds: 1900), (_) {
      if (!mounted || !_cardCtrl.hasClients) return;
      final current = _cardCtrl.page?.round() ?? 0;
      final next = (current + 1) % _listings.length;
      _cardCtrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _cardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageChrome(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF059669), Color(0xFF0891B2)],
      ),
      eyebrow: 'Go Live In Minutes',
      headline: 'List It Free In Minutes',
      sub: 'Snap a few photos, drop a pin, go live — found by people nearby.',
      graphic: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepCircle(icon: Icons.location_on_rounded, delay: 400),
                _StepRail(delay: 500),
                _StepCircle(icon: Icons.camera_alt_rounded, delay: 800),
                _StepRail(delay: 900),
                _StepCircle(icon: Icons.check_rounded, delay: 1150),
              ],
            ),
          ),
          // Was 14px — the step-circles' own shadow and the cards below read
          // as stuck together at that gap ("3 option chipak rahe the").
          const SizedBox(height: 30),
          FadeInUp(
            delay: const Duration(milliseconds: 1450),
            child: SizedBox(
              height: 128,
              width: 220,
              child: PageView.builder(
                controller: _cardCtrl,
                itemCount: _listings.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _ListingCard(listing: _listings[i], live: _live),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ({List<Color> photo, String title, String meta}) listing;
  final bool live;
  const _ListingCard({required this.listing, required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(colors: listing.photo),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: live ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    live ? 'Live' : 'Draft',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, color: live ? const Color(0xFF3A2400) : Colors.white),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(listing.title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(listing.meta, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final IconData icon;
  final int delay;
  const _StepCircle({required this.icon, required this.delay});

  @override
  Widget build(BuildContext context) {
    return ZoomIn(
      delay: Duration(milliseconds: delay),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 2)],
        ),
        child: Icon(icon, color: const Color(0xFF059669), size: 19),
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  final int delay;
  const _StepRail({required this.delay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        builder: (context, value, _) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(height: 2, color: Colors.white.withValues(alpha: 0.28)),
            FractionallySizedBox(widthFactor: value, child: Container(height: 2, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 4 — Services: 5 category stamps
// ============================================================

class _ServicesPage extends StatefulWidget {
  final bool isActive;
  const _ServicesPage({required this.isActive});

  @override
  State<_ServicesPage> createState() => _ServicesPageState();
}

class _ServiceStop {
  final IconData icon;
  final String label;
  final Color color;
  final double t; // 0..1 position along the arc, left to right
  const _ServiceStop(this.icon, this.label, this.color, this.t);
}

class _ServicesPageState extends State<_ServicesPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _stops = [
    _ServiceStop(Icons.terrain_rounded, 'Char Dham', AppColors.success, 0.08),
    _ServiceStop(Icons.explore_rounded, 'Tour & Travel', Color(0xFF0284C7), 0.29),
    _ServiceStop(Icons.self_improvement_rounded, 'Yoga & Diet', Color(0xFFC2410C), 0.5),
    _ServiceStop(Icons.camera_alt_rounded, 'Photography', Color(0xFF0284C7), 0.71),
    _ServiceStop(Icons.school_rounded, 'Education', AppColors.success, 0.92),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    if (widget.isActive) _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _ServicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _ctrl.forward(from: 0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageChrome(
      solidColor: const Color(0xFFFBF6EC),
      textColor: AppColors.textDark,
      eyebrowColor: const Color(0xFF0284C7),
      subColor: AppColors.textMedium,
      eyebrow: 'Beyond Rooms & Plots',
      headline: 'Book Experiences,\nNot Just Addresses',
      sub: 'Char Dham Yatra, treks, yoga & more — expert teams, connected on demand.',
      // Headline/sub wait for most of the rainbow+icon sequence to play out,
      // shortened from 2100ms so they don't lag noticeably behind it.
      textDelayMs: 1500,
      // A rainbow arc sweeps in left-to-right, and each category pops in the
      // instant the sweep reaches its spot on the arc — "rainbow jaise jaise
      // banega, cards waise waise aayenge."
      graphic: SizedBox(
        width: 260,
        height: 148,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = _ctrl.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(size: const Size(260, 148), painter: _RainbowArcPainter(progress: progress)),
                for (final stop in _stops) _ServiceStopIcon(stop: stop, progress: progress),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceStopIcon extends StatelessWidget {
  final _ServiceStop stop;
  final double progress;
  const _ServiceStopIcon({required this.stop, required this.progress});

  // Same arc geometry as _RainbowArcPainter — center at bottom-middle, a
  // wide flat ellipse arch swept from angle pi (left) through -pi/2 (top)
  // to 0 (right). Kept in sync by hand rather than shared state, since it's
  // just two numbers (center, radii); see the painter for the paired math.
  // Sits at a bigger radius than the rainbow's outermost band (see
  // _RainbowArcPainter) — outside the arc, not on top of it, so no band
  // colour ever shows behind an icon/label and fights its readability.
  static const _cx = 130.0, _cy = 140.0, _rx = 126.0, _ry = 134.0;

  @override
  Widget build(BuildContext context) {
    final angle = math.pi + stop.t * math.pi;
    final dx = _cx + _rx * math.cos(angle);
    final dy = _cy + _ry * math.sin(angle);
    final visible = progress >= stop.t;
    return Positioned(
      left: dx - 34,
      top: dy - 26,
      // Slides up into place while it fades/scales in, the same "content
      // rises into position" motion FadeInUp gives every other page's text —
      // not just a static pop, so this page doesn't feel stiller than the rest.
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
        scale: visible ? 1 : 0.3,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.95), boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
                        ]),
                      ),
                      CustomPaint(size: const Size(44, 44), painter: _DashedCirclePainter(color: stop.color)),
                      Icon(stop.icon, color: stop.color, size: 19),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w800, color: stop.color, letterSpacing: 0.1),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// A rainbow arch, drawn as concentric coloured bands sweeping in left to
/// right as `progress` goes 0->1 — the backdrop the 5 category stops sit on.
class _RainbowArcPainter extends CustomPainter {
  final double progress;
  const _RainbowArcPainter({required this.progress});

  static const _bands = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFFBBF24), // yellow
    Color(0xFF10B981), // green
    Color(0xFF0EA5E9), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(130, 140);
    final sweep = math.pi * progress;
    // Hairline-thin stripes sitting edge-to-edge (step == width, a hair of
    // overlap to hide anti-aliasing seams) — a real rainbow's bands touch
    // with no visible gap between them, and read as one continuous arc.
    const stripeWidth = 1.0;
    const step = 0.9;
    for (int i = 0; i < _bands.length; i++) {
      final rx = 92.0 - i * step;
      final ry = 97.0 - i * step;
      if (rx <= 0 || ry <= 0) continue;
      final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
      canvas.drawArc(
        rect,
        math.pi,
        sweep,
        false,
        Paint()
          ..color = _bands[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stripeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainbowArcPainter old) => old.progress != progress;
}

/// A dashed circular outline — Flutter's `Border` only supports solid/none,
/// so the mockup's dashed stamp-circle needs a small painter instead.
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    const dashLength = 5.0;
    const gapLength = 4.0;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = 2 * math.pi / dashCount;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));
    for (int i = 0; i < dashCount; i++) {
      final start = i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}
