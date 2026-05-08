import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // Tracks when user is sent to OS settings — lifecycle observer re-triggers on return.
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.5)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textController);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _startAnimations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Re-enter navigation flow when user returns from OS settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _navigate();
    }
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    _navigate();
  }

  Future<void> _navigate() async {
    await _ensureLocationPermission();
    if (!mounted || _waitingForSettings) return;

    final isSupported = await _checkDistrictSupport();
    if (!mounted || !isSupported) return;

    if (StorageService.isLoggedIn) {
      Get.offAllNamed(AppRoutes.main);
    } else {
      Get.offAllNamed(AppRoutes.otp);
    }
  }

  Future<void> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Location Required',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: const Text(
              'RentNearBy needs location access to show rooms near you. Please enable it in Settings.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _waitingForSettings = true;
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      // After dialog closes, _waitingForSettings is true — lifecycle observer takes over.
      return;
    }

    if (permission == LocationPermission.denied) {
      // User denied but not permanently — show explanation and let them try again.
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Location Required',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: const Text(
              'This app needs your location to find rooms nearby. Please allow location access to continue.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _ensureLocationPermission();
              },
              child: const Text('Allow',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }

  // Returns false and shows a non-dismissible popup if user is outside all supported districts.
  // Returns true if location is unavailable (let through — explore screen handles it).
  Future<bool> _checkDistrictSupport() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return true;
      }

      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high),
          );

      final response = await ApiService.get('/admin/districts');
      final List<dynamic> raw = response['data'] ?? [];
      final districts = raw.map((d) => DistrictModel.fromJson(d)).toList();

      if (districts.isEmpty) return true;

      double minDist = double.infinity;
      for (final d in districts) {
        if (d.latitude == null || d.longitude == null) continue;
        final dist =
            _haversineKm(pos.latitude, pos.longitude, d.latitude!, d.longitude!);
        if (dist < minDist) minDist = dist;
      }

      if (minDist > 100) {
        if (!mounted) return false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Service Not Available',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: const Text(
                'RentNearBy is not available in your district yet. Contact our support on WhatsApp to request coverage in your area.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            actions: [
              TextButton(
                onPressed: _launchWhatsApp,
                child: const Text('Contact Support',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF25D366),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _launchWhatsApp() async {
    // TODO: replace with real support number via admin panel
    const number = '919999999999';
    final uri = Uri.parse(
        'https://wa.me/$number?text=Hi%2C%20I%20want%20RentNearBy%20in%20my%20district.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dlat = (lat2 - lat1) * pi / 180;
    final dlng = (lng2 - lng1) * pi / 180;
    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dlng / 2) *
            sin(dlng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          size: 52, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) => FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        const Text('RentNearBy',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 8),
                        Text('Find rooms near you. No brokers.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.75),
                              letterSpacing: 0.2,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) => Opacity(
                  opacity: _textOpacity.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => _dot(i)),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, v, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
