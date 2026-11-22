import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/seeker_home/seeker_home_parts.dart';
import 'package:bakhli/features/seeker_home/seeker_rail_art.dart';
import 'package:bakhli/features/seeker_home/strings/seeker_home_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Size size = const Size(360, 800), double scale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Column(children: [child])),
      ),
    );

SeekerRecentRow _row({String? photo, String? type, VoidCallback? onTap}) => SeekerRecentRow(
      title: 'Lakeside Homestay Bhimtal',
      subtitle: 'Bhimtal · ₹1,800/night',
      photoUrl: photo,
      stayTypeName: type,
      onTap: onTap ?? () {},
    );

BoxDecoration _rowDeco(WidgetTester t) {
  final c = t.widgetList<Container>(find.descendant(of: find.byType(SeekerRecentRow), matching: find.byType(Container))).first;
  return c.decoration! as BoxDecoration;
}

void main() {
  testWidgets('photo: KitPhoto in the thumbnail', (t) async {
    await t.pumpWidget(_host(_row(photo: 'https://res.cloudinary.com/demo/image/upload/a.jpg')));
    expect(find.descendant(of: find.byKey(SeekerRecentRow.thumbKey), matching: find.byType(KitPhoto)), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('no photo: house art tile for every stay type', (t) async {
    for (final type in [null, 'Homestay', 'Guest House', 'Camp', 'Hostel']) {
      await t.pumpWidget(_host(_row(type: type)));
      final art = t.widget<Art3D>(find.descendant(of: find.byKey(SeekerRecentRow.thumbKey), matching: find.byType(Art3D)));
      expect(art.asset, SeekerRailArt.house, reason: '$type');
      expect(find.byType(KitPhoto), findsNothing);
    }
  });

  testWidgets('white row, radius 16 on all corners, forest arrow', (t) async {
    await t.pumpWidget(_host(_row()));
    final d = _rowDeco(t);
    expect(d.color, DesignColors.onPrimary);
    expect(d.borderRadius, DS.circular(16));
    final thumb = t.widget<Container>(find.byKey(SeekerRecentRow.thumbKey)).decoration! as BoxDecoration;
    expect(thumb.borderRadius, DS.circular(16));
    expect(t.getSize(find.byKey(SeekerRecentRow.thumbKey)), Size.square(DS.s(58)));
    expect(t.widget<Text>(find.text(SeekerHomeStrings.rowArrow)).style?.color, ListingPalette.forest.g2);
  });

  testWidgets('tap fires once', (t) async {
    var taps = 0;
    await t.pumpWidget(_host(_row(onTap: () => taps++)));
    await t.tap(find.byType(SeekerRecentRow));
    expect(taps, 1);
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('fits at $w @$scale', (t) async {
        final size = Size(w, 800);
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(_row(), size: size, scale: scale));
        expect(t.takeException(), isNull);
      });
    }
  }
}
