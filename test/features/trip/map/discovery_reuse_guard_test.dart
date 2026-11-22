import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery layer files import no plan controller, trip_plan model, stay file or routes', () {
    const adapter = 'trip_map_spot_actions.dart';
    final banned = RegExp(r"import '[^']*(trip_plan|/stay/|app_routes|trip_routes|get_navigation)");
    final files = Directory('lib/features/trip/map').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files.length, greaterThanOrEqualTo(6));
    for (final f in files) {
      if (f.path.replaceAll(r'\', '/').endsWith('/$adapter')) continue;
      final src = f.readAsStringSync();
      expect(banned.hasMatch(src), isFalse, reason: f.path);
      expect(src.contains('Get.toNamed') || src.contains('Get.to('), isFalse, reason: f.path);
    }
  });

  test('map files never use CachedNetworkImage widgets', () {
    for (final f in Directory('lib/features/trip/map').listSync().whereType<File>()) {
      expect(f.readAsStringSync().contains('CachedNetworkImage('), isFalse, reason: f.path);
    }
  });
}
