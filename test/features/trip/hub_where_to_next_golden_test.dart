import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/screens/trip_where_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Future<void> _loadFont() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Poppins-$f.ttf').readAsBytesSync())));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/deven/develop/flutter';
  icons.addFont(Future.value(ByteData.sublistView(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

TripCityModel _c(int k, String n, String s, int spots) => TripCityModel(
      cityKey: k, name: n, stateName: s, latitude: 0, longitude: 0, spotCount: spots, isPopularDestination: true);

void main() {
  testWidgets('where to next renders', (tester) async {
    await _loadFont();
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cat = TripCityCatalog();
    Get.put<TripCityCatalog>(cat);
    cat.seedForTest([
      _c(1, 'Nainital', 'Uttarakhand', 24),
      _c(2, 'Mussoorie', 'Uttarakhand', 18),
      _c(3, 'Rishikesh', 'Uttarakhand', 21),
      _c(4, 'Jim Corbett', 'Uttarakhand', 12),
      _c(5, 'Shimla', 'Himachal', 10),
    ]);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Poppins'),
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(padding: const EdgeInsets.only(top: 44)), child: w!),
        home: const TripWhereScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/golden').createSync(recursive: true);
      File('build/golden/where_to_next.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
