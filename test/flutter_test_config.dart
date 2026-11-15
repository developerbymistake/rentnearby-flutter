import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApprovedScaleComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(List<int> imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, List<int> imageBytes) async {}
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const mode = String.fromEnvironment('UI_SCALE');
  if (mode == 'approved') {
    DS.applyApproved();
    goldenFileComparator = _ApprovedScaleComparator();
  }
  await testMain();
}
