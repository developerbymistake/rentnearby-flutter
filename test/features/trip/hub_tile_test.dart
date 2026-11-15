import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hub shows five tiles, only the first is live', () {
    final v = HubTiles.visible();
    expect(v.length, 5);
    expect(v.first.status, HubTileStatus.live);
    expect(v.skip(1).every((t) => t.status == HubTileStatus.soon), isTrue);
  });

  testWidgets('tile is 160 high and its art box is 158 wide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: HubTile(config: HubTiles.all.first, onTap: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(HubTile)).height, closeTo(DS.s(160), 0.001));
    final art = tester.widgetList<Positioned>(find.byType(Positioned)).where((p) => p.width == DS.s(158));
    expect(art.length, 1);
    expect(art.first.top, DS.s(-46));
    expect(art.first.bottom, DS.s(2));
  });
}
