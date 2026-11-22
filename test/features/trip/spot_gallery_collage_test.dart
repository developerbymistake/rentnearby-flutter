import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/spot_gallery_collage.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _urls(int n) => [for (var i = 0; i < n; i++) 'https://res.cloudinary.com/demo/image/upload/v1/g$i.jpg'];

final _shown = <String>[];

Finder get _tiles => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('img:'));

Future<int?> _pump(WidgetTester t, int n, double width) async {
  int? tapped;
  await t.binding.setSurfaceSize(Size(width + 40, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SpotGalleryCollage(urls: _urls(n), fallbackAsset: TripSpotLook.assetOf('lake'), title: 'Naini Lake', onTap: (i) => tapped = i),
        ),
      ),
    ),
  ));
  await t.pump();
  return tapped;
}

void main() {
  setUp(() {
    _shown.clear();
    TripSpotMedia.debugImageBuilder = (url, fit, fallback) {
      _shown.add(url);
      return SizedBox.expand(key: ValueKey('img:$url'));
    };
  });
  tearDown(() => TripSpotMedia.debugImageBuilder = null);

  final phone = <int, (int, String?)>{1: (1, null), 2: (2, null), 3: (3, null), 4: (3, '+1 more'), 5: (3, '+2 more'), 10: (3, '+7 more')};
  for (final e in phone.entries) {
    testWidgets('phone width, n = ${e.key}: ${e.value.$1} tiles ${e.value.$2 ?? 'no overlay'}', (t) async {
      await _pump(t, e.key, 320);
      expect(_tiles, findsNWidgets(e.value.$1));
      final more = e.value.$2;
      if (more == null) {
        expect(find.textContaining('more'), findsNothing);
      } else {
        expect(find.text(more), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }

  final wide = <int, (int, String?)>{1: (1, null), 2: (2, null), 3: (3, null), 4: (4, null), 5: (4, '+1 more'), 10: (4, '+6 more')};
  for (final e in wide.entries) {
    testWidgets('600 content width, n = ${e.key}: ${e.value.$1} tiles ${e.value.$2 ?? 'no overlay'}', (t) async {
      await _pump(t, e.key, 600);
      expect(_tiles, findsNWidgets(e.value.$1));
      final more = e.value.$2;
      if (more == null) {
        expect(find.textContaining('more'), findsNothing);
      } else {
        expect(find.text(more), findsOneWidget);
      }
    });
  }

  testWidgets('heights follow the shapes', (t) async {
    await _pump(t, 1, 320);
    expect(t.getSize(find.byType(SpotGalleryCollage)).height, closeTo(320 * 0.56, 0.5));
    await _pump(t, 2, 320);
    expect(t.getSize(find.byType(SpotGalleryCollage)).height, closeTo(320 * 0.50, 0.5));
    await _pump(t, 5, 320);
    expect(t.getSize(find.byType(SpotGalleryCollage)).height, closeTo(320 * 0.58, 0.5));
    await _pump(t, 5, 600);
    expect(t.getSize(find.byType(SpotGalleryCollage)).height, closeTo(600 * 0.46, 0.5));
  });

  testWidgets('big tile is card size, small tiles square, overlay tile opens its own index', (t) async {
    int? tapped;
    await t.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: SpotGalleryCollage(urls: _urls(10), fallbackAsset: TripSpotLook.assetOf('lake'), title: 'Naini Lake', onTap: (i) => tapped = i),
        ),
      ),
    ));
    expect(_shown[0], contains('c_fill,g_auto,w_720,h_400'));
    expect(_shown[1], contains('c_fill,g_auto,w_320,h_320'));
    await t.tap(find.text('+7 more'));
    expect(tapped, 2);
    expect(find.bySemanticsLabel('Naini Lake, photo 3 of 10'), findsOneWidget);
  });

  testWidgets('loading shows three placeholders, error shows the retry card', (t) async {
    var retried = 0;
    Widget host(SpotGalleryState s) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SpotGallerySection(state: s, urls: const [], title: 'x', fallbackAsset: TripSpotLook.assetOf('lake'), onTap: (_) {}, onRetry: () => retried++),
            ),
          ),
        );
    await t.pumpWidget(host(SpotGalleryState.loading));
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.byType(TemplatePlaceholder), findsNWidgets(3));
    await t.pumpWidget(host(SpotGalleryState.error));
    expect(find.text("Couldn't load photos"), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    await t.tap(find.text('Retry'));
    expect(retried, 1);
    await t.pumpWidget(host(SpotGalleryState.ready));
    expect(find.text('Gallery'), findsNothing);
  });
}
