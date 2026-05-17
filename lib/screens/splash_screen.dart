import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _navigate();
    }
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    _navigate();
  }

  Future<void> _navigate() async {
    while (true) {
      final granted = await _ensureLocationPermission();
      if (!mounted) return;
      if (_waitingForSettings) return;
      if (granted) break;
    }

    final isSupported = await _checkDistrictSupport();
    if (!mounted || !isSupported) return;

    if (StorageService.isLoggedIn) {
      Get.offAllNamed(AppRoutes.main);
    } else {
      Get.offAllNamed(AppRoutes.otp);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (_isGranted(permission)) return true;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (_isGranted(permission)) return true;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Location Required',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            content: const Text(
                'Bakhli needs location access to show rooms near you. Please enable it in Settings.',
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
        ),
      );
      return false;
    }

    if (!mounted) return false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Location Required',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          content: const Text(
              'Bakhli needs your location to find rooms nearby. Please allow location access to continue.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Allow',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  bool _isGranted(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  Future<bool> _checkDistrictSupport() async {
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
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
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Service Not Available',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              content: const Text(
                  'Bakhli is not available in your district yet. Contact our support on WhatsApp to request coverage in your area.',
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
    const number = '917060023511';
    final uri = Uri.parse(
        'https://wa.me/$number?text=Hi%2C%20I%20want%20Bakhli%20in%20my%20district.');
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
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash_screen.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
