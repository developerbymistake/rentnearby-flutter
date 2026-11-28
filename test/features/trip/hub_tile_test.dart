import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_tile_config.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/config/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hub shows six tiles in order, where, groups and buddy are live', () {
    final v = HubTiles.visible();
    expect(v.map((t) => t.id).toList(), ['where', 'groups', 'buddy', 'guide', 'rentals', 'adventures']);
    expect(v.where((t) => t.status == HubTileStatus.live).map((t) => t.id).toList(), ['where', 'groups', 'buddy']);
    expect(v.firstWhere((t) => t.id == 'groups').route, AppRoutes.travelBuddies);
    expect(v.firstWhere((t) => t.id == 'buddy').route, AppRoutes.people);
  });

  test('tile sides alternate left and right', () {
    expect([for (final t in HubTiles.all) t.side], [
      for (var i = 0; i < HubTiles.all.length; i++) i.isEven ? HubTileSide.textLeft : HubTileSide.textRight,
    ]);
  });

  test('groups and buddy tiles carry their copy', () {
    final groups = HubTiles.all.firstWhere((t) => t.id == 'groups');
    expect(groups.line, 'Join destination and activity');
    expect(groups.title, 'TRAVEL GROUPS');
    final buddy = HubTiles.all.firstWhere((t) => t.id == 'buddy');
    expect(buddy.line, 'Find your perfect');
    expect(buddy.title, 'TRAVEL BUDDY');
  });

  test('groups tile has its own art, not the buddy art', () {
    final groups = HubTiles.all.firstWhere((t) => t.id == 'groups');
    final buddy = HubTiles.all.firstWhere((t) => t.id == 'buddy');
    final groupsArt = groups.art.map((a) => a.asset).toList();
    expect(groupsArt, [ListingArt.camping, TravelIcon.chat]);
    expect(groupsArt.any(buddy.art.map((a) => a.asset).contains), isFalse);
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
