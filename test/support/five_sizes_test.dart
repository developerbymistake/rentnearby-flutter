import 'package:bakhli/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'five_sizes.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.id, this.seen);

  final int id;
  final List<String> seen;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    seen.add('$id:${mq.size.width.toInt()}x${mq.size.height.toInt()}');
    return Scaffold(body: Text('probe $id', style: Theme.of(context).textTheme.bodyMedium));
  }
}

void main() {
  testWidgets('pump_at_five_sizes_builds_a_fresh_page_at_every_size', (tester) async {
    final seen = <String>[];
    var built = 0;
    final checked = <Size>[];
    await pumpAtFiveSizes(
      tester,
      () => _Probe(built++, seen),
      check: (t, size) async {
        checked.add(size);
        expect(find.text('probe ${built - 1}'), findsOneWidget);
        expect(t.view.physicalSize / t.view.devicePixelRatio, size);
        final ctx = t.element(find.byType(Scaffold));
        expect(ScrollConfiguration.of(ctx).runtimeType, AppScrollBehavior);
      },
    );
    expect(checked, fiveSizes);
    expect(built, 5);
    for (var i = 0; i < fiveSizes.length; i++) {
      expect(seen, contains('$i:${sizeLabel(fiveSizes[i])}'));
    }
  });

  testWidgets('pump_at_five_sizes_reports_an_overflow', (tester) async {
    final errors = <String>[];
    await pumpAtFiveSizes(
      tester,
      () => const Scaffold(body: Row(children: [SizedBox(width: 700, height: 10)])),
      expectNoOverflow: false,
      check: (t, size) async {
        final e = t.takeException();
        if (e != null) errors.add(sizeLabel(size));
      },
    );
    expect(errors, fiveSizes.map(sizeLabel).toList());
  });
}
