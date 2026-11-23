import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'map_lab_screen.dart';

class MapLabEntry {
  static const String routeName = '/map-lab';

  static void open() {
    if (kDebugMode) {
      Get.to(() => const MapLabScreen(), routeName: routeName);
    }
  }

  static Widget row() {
    if (kDebugMode) {
      return ListTile(
        leading: const Icon(Icons.science_outlined),
        title: const Text('Map lab (debug only)'),
        onTap: open,
      );
    }
    return const SizedBox.shrink();
  }
}
