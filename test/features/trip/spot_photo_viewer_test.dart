import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/features/trip/widgets/spot_photo_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _art = TripSpotLook.assetOf('lake');
List<String> _urls(int n) => [for (var i = 0; i < n; i++) 'https://res.cloudinary.com/demo/image/upload/v1/g$i.jpg'];

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester t, List<String> urls, {int index = 0}) async {
  await t.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => SpotPhotoViewer.open(c, urls: urls, initialIndex: index, title: 'Naini Lake', fallbackAsset: _art),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await _settle(t);
}

PageView _pager(WidgetTester t) => t.widget<PageView>(find.byKey(SpotPhotoViewer.pagerKey));

Future<void> _doubleTap(WidgetTester t) async {
  final c = t.getCenter(find.byKey(SpotPhotoViewer.pagerKey));
  await t.tapAt(c);
  await t.pump(const Duration(milliseconds: 60));
  await t.tapAt(c);
  await _settle(t);
}

void main() {
  testWidgets('empty list does not push', (t) async {
    await _open(t, const []);
    expect(find.byType(SpotPhotoViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('opens at initialIndex with the counter and the close button', (t) async {
    await _open(t, _urls(10), index: 2);
    expect(find.byType(SpotPhotoViewer), findsOneWidget);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byType(SheetCloseButton), findsOneWidget);
    expect(find.bySemanticsLabel('Naini Lake, photo 3 of 10'), findsOneWidget);
  });

  testWidgets('counter follows the swipe', (t) async {
    await _open(t, _urls(10), index: 2);
    await t.drag(find.byKey(SpotPhotoViewer.pagerKey), const Offset(-300, 0));
    await _settle(t);
    expect(find.text('4 / 10'), findsOneWidget);
    await t.drag(find.byKey(SpotPhotoViewer.pagerKey), const Offset(300, 0));
    await _settle(t);
    expect(find.text('3 / 10'), findsOneWidget);
  });

  testWidgets('requested url carries the full segment and a decode width', (t) async {
    await _open(t, _urls(3), index: 1);
    final imgs = t.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
    expect(imgs, isNotEmpty);
    final current = imgs.firstWhere((i) => i.imageUrl.endsWith('/v1/g1.jpg'));
    expect(current.imageUrl, 'https://res.cloudinary.com/demo/image/upload/c_limit,w_1280,q_auto,f_auto/v1/g1.jpg');
    expect(current.fit, BoxFit.contain);
    for (final i in imgs) {
      expect(i.memCacheWidth, isNotNull);
      expect(i.imageUrl, contains('c_limit,w_1280,q_auto,f_auto'));
    }
  });

  testWidgets('double tap toggles 2x and zoom blocks the page swipe', (t) async {
    await _open(t, _urls(5), index: 1);
    expect(_pager(t).physics, isA<PageScrollPhysics>());
    await _doubleTap(t);
    final tc = t.widget<InteractiveViewer>(find.byType(InteractiveViewer).first).transformationController!;
    expect(tc.value.getMaxScaleOnAxis(), closeTo(2, 0.01));
    expect(_pager(t).physics, isA<NeverScrollableScrollPhysics>());
    await t.drag(find.byKey(SpotPhotoViewer.pagerKey), const Offset(-300, 0));
    await _settle(t);
    expect(find.text('2 / 5'), findsOneWidget);
    await _doubleTap(t);
    expect(_pager(t).physics, isA<PageScrollPhysics>());
    final iv = t.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);
    expect(iv.minScale, 1);
    expect(iv.maxScale, 4);
  });

  testWidgets('close button pops', (t) async {
    await _open(t, _urls(2));
    await t.tap(find.byType(SheetCloseButton));
    await _settle(t);
    expect(find.byType(SpotPhotoViewer), findsNothing);
  });

  testWidgets('back pops', (t) async {
    await _open(t, _urls(2));
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.byType(SpotPhotoViewer), findsNothing);
  });

  testWidgets('swipe down past 120 pops, a short swipe does not', (t) async {
    await _open(t, _urls(2));
    await t.drag(find.byKey(SpotPhotoViewer.pagerKey), const Offset(0, 80));
    await _settle(t);
    expect(find.byType(SpotPhotoViewer), findsOneWidget);
    await t.drag(find.byKey(SpotPhotoViewer.pagerKey), const Offset(0, 260));
    await _settle(t);
    expect(find.byType(SpotPhotoViewer), findsNothing);
  });

  testWidgets('a broken url shows the category art on the indigo gradient', (t) async {
    await _open(t, ['', ..._urls(1)]);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == _art), findsOneWidget);
  });

  testWidgets('pushed on the root navigator, above a nested navigator', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (c) => TextButton(
            onPressed: () => SpotPhotoViewer.open(c, urls: _urls(1), title: 'x', fallbackAsset: _art),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await _settle(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav, same(Navigator.of(t.element(find.byType(SpotPhotoViewer)))));
    expect(find.text('1 / 1'), findsOneWidget);
  });
}
