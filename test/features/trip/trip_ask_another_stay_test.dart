import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/trip/trip_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('open_stay_with_shortlist_opens_the_shortlist_list', (t) async {
    final opened = <Map>[];
    await t.pumpWidget(GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const Scaffold(body: Text('home'))),
        GetPage(
          name: AppRoutes.tripStay,
          page: () {
            opened.add(Map.of(Get.arguments as Map));
            return const Scaffold(body: Text('stay list'));
          },
        ),
      ],
    ));
    TripNavigation.openStay(2, shortlist: true, nearLat: 29.3, nearLng: 79.5);
    await t.pumpAndSettle();
    expect(opened.single['shortlist'], isTrue);
    expect(opened.single['legIndex'], 2);
    expect(opened.single['nearLat'], 29.3);
  });

  test('every_ask_another_stay_entry_opens_the_shortlist', () {
    final files = [
      'lib/features/trip/screens/trip_replies_screen.dart',
      'lib/features/trip/widgets/trip_problem_sheet.dart',
    ];
    for (final f in files) {
      final src = File(f).readAsStringSync();
      expect(src, contains('TripNavigation.reopenStayShortlist('), reason: f);
      expect(src, isNot(contains('TripNavigation.openStay(')), reason: f);
    }
    final call = RegExp(r'TripNavigation\.openStay\(([^;]*)\);');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        expect(m.group(1), contains('shortlist: true'), reason: '${f.path}: ${m.group(0)}');
      }
    }
  });
}
