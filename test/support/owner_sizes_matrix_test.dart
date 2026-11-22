import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/sheets/owner_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'owner_sizes.dart';

// FX-34 helper self-test, run on the FX-32 skeleton inside a short body.
Widget _shortBody() => Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(height: DS.s(110), child: const ColoredBox(color: Colors.white)),
          const Expanded(child: OwnerSkeletonList(rows: 4)),
        ]),
      ),
    );

void main() {
  test('the matrix has the eight devices of FX-34, including a short landscape window and a tablet', () {
    expect(ownerMatrixSizes, containsAll(const [Size(360, 640), Size(600, 960), Size(820, 1180), Size(800, 360)]));
    expect(ownerMatrixSizes.length, 8);
  });

  test('FX-32 rows fit the height, at least one, never more than asked', () {
    final row = DS.s(72) + DS.s(12);
    expect(OwnerSkeletonList.fitRows(double.infinity, 3), 3);
    expect(OwnerSkeletonList.fitRows(10, 3), 1);
    expect(OwnerSkeletonList.fitRows(DS.s(24) + row * 2, 4), 2);
    expect(OwnerSkeletonList.fitRows(DS.s(24) + row * 10, 4), 4);
  });

  testOwnerMatrix('FX-32 skeleton in a short body', _shortBody, keyboard: true);
}
