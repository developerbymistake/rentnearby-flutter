import 'dart:io';
import 'package:flutter/services.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/real_phone.dart';
import 'overlay_support.dart';

class _Catalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => const [];
}

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ListView(padding: EdgeInsets.only(top: 60, bottom: OverlayInsets.list(context, pill: true)), children: [
        for (var i = 0; i < 20; i++) SizedBox(height: 90, child: Text('Item $i')),
      ]),
      Positioned(
        left: 0,
        right: 0,
        bottom: OverlayInsets.pillBottom(context),
        child: Center(child: StayFloatingPill(key: const ValueKey('pill'), label: 'Map view', onTap: () {})),
      ),
    ]);
  }
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.path);
    loadRealFonts();
    shotsDir = r'F:\Dhasu\UI_Template_resume\Slice3\shots';
  });
  tearDown(Get.reset);

  for (final size in [phoneSize, const Size(360, 640)]) {
    for (final scale in [1.0, 1.3]) {
      overlayTest('pill dock clears list ${size.height} x$scale', (t) async {
        await pumpOverlay(t, const _Probe(), size: size, scale: scale);
        await scrollToEnd(t, find.byType(_Probe));
        await shot(t, 'O_pill_${size.height.toInt()}_$scale');
        final top = overlayTop(t, pill: find.byKey(const ValueKey('pill')));
        expect(contentBottom(t, find.byType(ListView)), lessThanOrEqualTo(top));
      });

      overlayTest('trips tab end clears overlays ${size.height} x$scale', (t) async {
        Get.put<TripCityCatalog>(_Catalog(), permanent: true);
        await pumpOverlay(t, const TripsDiscoveryScreen(), size: size, scale: scale);
        await scrollToEnd(t, find.byType(TripsDiscoveryScreen));
        await shot(t, 'O_trips_${size.height.toInt()}_$scale');
        expect(contentBottom(t, find.byType(TripsDiscoveryScreen)), lessThanOrEqualTo(overlayTop(t)));
      });
    }
  }
}
