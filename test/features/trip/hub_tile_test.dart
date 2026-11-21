import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile_config.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hub shows five tiles in order, where and buddy are live', () {
    final v = HubTiles.visible();
    expect(v.map((t) => t.id).toList(), ['where', 'adventures', 'buddy', 'guide', 'rentals']);
    expect(v.where((t) => t.status == HubTileStatus.live).map((t) => t.id).toList(), ['where', 'buddy']);
    expect(v.firstWhere((t) => t.id == 'buddy').route, AppRoutes.buddies);
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
