import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/features/trip/data/spot_gallery_loader.dart';
import 'package:bakhli/features/trip/data/trip_repository.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_strings_spots_x.dart';
import 'package:bakhli/features/trip/utils/spot_gallery_cache.dart';
import 'package:bakhli/features/trip/utils/trip_spots_cache.dart';
import 'package:bakhli/features/trip/widgets/spot_photo_viewer.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_detail_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_row.dart';
import 'package:bakhli/features/trip/widgets/trip_spots_extras.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_phone.dart';

String _u(String n) => 'https://res.cloudinary.com/demo/image/upload/v1/$n.jpg';

const _long = 'A calm lake in the middle of the town, ringed by green hills on all sides. Boating starts early in the morning '
    'and goes on till sunset, with rowing boats and pedal boats at the main jetty. The mall road runs along the north shore '
    'with small cafes and shops, and the walk to the far side takes about forty minutes. Evenings are busy in summer.';

TripSpotModel _spot({int photos = 3, int gallery = 0, String? description = 'A calm lake.', String? area = 'Mallital', bool featured = true, String name = 'Naini Lake'}) => TripSpotModel(
      id: 'naini',
      source: 'osm',
      name: name,
      description: description,
      latitude: 29.38,
      longitude: 79.45,
      category: 'lake',
      area: area,
      visitMinutes: 90,
      isFeatured: featured,
      images: [for (var i = 0; i < photos; i++) _u('p$i')],
      galleryCount: gallery,
    );

class _Repo extends TripRepository {
  int calls = 0;
  Completer<SpotDetail>? gate;
  Object? error;
  SpotDetail answer = SpotDetail(gallery: [for (var i = 0; i < 5; i++) _u('g$i')]);

  @override
  Future<SpotDetail> spotDetail(int cityKey, String spotId) async {
    calls++;
    if (gate != null) return gate!.future;
    if (error != null) throw error!;
    return answer;
  }
}

late _Repo _repo;
final _shown = <String>[];
late BuildContext _ctx;

Future<void> _open(
  WidgetTester t,
  TripSpotModel spot, {
  int? cityKey = 1,
  String version = 'v1',
  bool selected = false,
  bool locked = false,
  VoidCallback? onToggle,
  bool noToggle = false,
  bool partial = false,
  bool showAction = true,
  bool revalidate = false,
  Size size = const Size(360, 800),
  double scale = 1.0,
}) async {
  await pumpPhone(
    t,
    Scaffold(body: Builder(builder: (c) {
      _ctx = c;
      return const SizedBox.expand();
    })),
    size: size,
    devicePixelRatio: 2,
    textScale: scale,
  );
  TripSpotDetailSheet.show(_ctx,
      spot: spot,
      selected: selected,
      locked: locked,
      onToggle: noToggle ? null : (onToggle ?? () {}),
      cityKey: cityKey,
      version: version,
      partial: partial,
      showAction: showAction,
      revalidate: revalidate);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

Finder get _gallery => find.text('Gallery');

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('spot_sheet').path,
    );
    await GetStorage.init();
    await TripSpotsCache.init();
  });

  setUp(() {
    _shown.clear();
    SpotGalleryLoader.debugReset();
    SpotGalleryCache.clear();
    _repo = _Repo();
    SpotGalleryLoader.repository = _repo;
    TripSpotMedia.debugImageBuilder = (url, fit, fallback) {
      _shown.add(url);
      return ColoredBox(key: ValueKey('img:$url'), color: const Color(0xFF88AACC));
    };
  });
  tearDown(() {
    TripSpotMedia.debugImageBuilder = null;
    SpotGalleryLoader.debugReset();
  });

  group('gallery', () {
    testWidgets('count 0: section absent, zero requests', (t) async {
      await _open(t, _spot(gallery: 0));
      expect(_gallery, findsNothing);
      expect(_repo.calls, 0);
    });

    testWidgets('cityKey null: section absent, zero requests', (t) async {
      await _open(t, _spot(gallery: 5), cityKey: null);
      expect(_gallery, findsNothing);
      expect(_repo.calls, 0);
    });

    testWidgets('gallery of 5: header, count, +2 more, one request', (t) async {
      await _open(t, _spot(gallery: 5));
      await _settle(t);
      expect(_gallery, findsOneWidget);
      expect(find.text('5 photos'), findsOneWidget);
      expect(find.text('+2 more'), findsOneWidget);
      expect(_repo.calls, 1);
    });

    testWidgets('loading: header without count and three placeholders, then tiles', (t) async {
      _repo.gate = Completer<SpotDetail>();
      await _open(t, _spot(gallery: 5));
      expect(_gallery, findsOneWidget);
      expect(find.text('5 photos'), findsNothing);
      expect(find.byType(TemplatePlaceholder), findsNWidgets(3));
      _repo.gate!.complete(SpotDetail(gallery: [_u('a')]));
      await _settle(t);
      expect(find.text('1 photo'), findsOneWidget);
      expect(find.byType(TemplatePlaceholder), findsNothing);
    });

    testWidgets('error shows the small card and Retry refetches', (t) async {
      _repo.error = Exception('down');
      await _open(t, _spot(gallery: 3));
      await _settle(t);
      expect(find.text("Couldn't load photos"), findsOneWidget);
      _repo.error = null;
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await _settle(t);
      expect(_repo.calls, 2);
      expect(find.text('5 photos'), findsOneWidget);
    });

    testWidgets('a 200 with an empty list: section absent', (t) async {
      _repo.answer = const SpotDetail(gallery: []);
      await _open(t, _spot(gallery: 4));
      await _settle(t);
      expect(_gallery, findsNothing);
    });

    testWidgets('cached same version: zero requests, tiles at once', (t) async {
      SpotGalleryCache.put(1, 'naini', 'v1', SpotDetail(gallery: [_u('a'), _u('b')]));
      await _open(t, _spot(gallery: 2));
      expect(find.text('2 photos'), findsOneWidget);
      expect(_repo.calls, 0);
    });

    testWidgets('new version refetches', (t) async {
      SpotGalleryCache.put(1, 'naini', 'v1', SpotDetail(gallery: [_u('a')]));
      await _open(t, _spot(gallery: 5), version: 'v2');
      await _settle(t);
      expect(_repo.calls, 1);
      expect(find.text('5 photos'), findsOneWidget);
    });

    testWidgets('sheet closed before the answer: no error', (t) async {
      _repo.gate = Completer<SpotDetail>();
      await _open(t, _spot(gallery: 5));
      await t.tap(find.byType(SheetCloseButton));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.byType(TripSpotDetailSheet), findsNothing);
      _repo.gate!.complete(SpotDetail(gallery: [_u('a')]));
      await _settle(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('partial: always asks and shows the spot of the answer', (t) async {
      _repo.answer = SpotDetail(
        spot: TripSpotModel.fromJson({'id': 'naini', 'name': 'Naini Lake', 'latitude': 1, 'longitude': 2, 'category': 'lake', 'description': 'From the server.', 'galleryCount': 2}),
        gallery: [_u('a'), _u('b')],
      );
      await _open(t, _spot(gallery: 0, description: null, photos: 1), partial: true);
      await _settle(t);
      expect(_repo.calls, 1);
      expect(find.text('From the server.'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
    });

    testWidgets('partial failure keeps what it has and shows the error card with Retry; Retry asks again', (t) async {
      _repo.error = Exception('down');
      await _open(t, _spot(gallery: 0, description: 'Local copy.'), partial: true);
      await _settle(t);
      expect(find.text('Local copy.'), findsOneWidget);
      expect(find.text(TripStringsSpotsX.galleryError), findsOneWidget);
      expect(find.text(TripStringsSpotsX.galleryErrorBody), findsOneWidget);
      _repo.error = null;
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await _settle(t);
      expect(_repo.calls, 2);
      expect(find.text(TripStringsSpotsX.galleryError), findsNothing);
    });

    group('revalidate (map Details, D12)', () {
      setUp(() async {
        await GetStorage(TripSpotsCache.container).erase();
      });

      final fresh = SpotDetail(
        spot: TripSpotModel.fromJson({
          'id': 'naini',
          'name': 'Naini Lake',
          'latitude': 29.38,
          'longitude': 79.45,
          'category': 'lake',
          'description': 'Edited by the admin.',
          'images': [_u('fresh')],
          'galleryCount': 2,
        }),
        gallery: [_u('ga'), _u('gb')],
        version: 'v2',
      );

      testWidgets('full model: one request, the answer photos and text replace the cached row', (t) async {
        _repo.answer = fresh;
        await _open(t, _spot(gallery: 0, photos: 1, description: 'Old text.'), revalidate: true);
        await _settle(t);
        expect(_repo.calls, 1);
        expect(find.text('Edited by the admin.'), findsOneWidget);
        expect(find.text('Old text.'), findsNothing);
        expect(_shown.any((u) => u.contains('fresh')), isTrue);
        expect(find.text('2 photos'), findsOneWidget);
      });

      testWidgets('a cache hit is shown at once and still asked once', (t) async {
        SpotGalleryCache.put(1, 'naini', 'v1', SpotDetail(gallery: [_u('a')]));
        _repo.gate = Completer<SpotDetail>();
        await _open(t, _spot(gallery: 1), revalidate: true);
        expect(find.text('1 photo'), findsOneWidget);
        expect(_repo.calls, 1);
        _repo.gate!.complete(fresh);
        await _settle(t);
        expect(find.text('2 photos'), findsOneWidget);
      });

      testWidgets('full model + failed call: no error card, the row stays', (t) async {
        _repo.error = Exception('down');
        await _open(t, _spot(gallery: 0, description: 'Local copy.'), revalidate: true);
        await _settle(t);
        expect(find.text('Local copy.'), findsOneWidget);
        expect(find.text(TripStringsSpotsX.galleryError), findsNothing);
      });

      testWidgets('full model with a gallery + failed call: the gallery error card with Retry, as on the list', (t) async {
        _repo.error = Exception('down');
        await _open(t, _spot(gallery: 3, description: 'Local copy.'), revalidate: true);
        await _settle(t);
        expect(find.text('Local copy.'), findsOneWidget);
        expect(find.text(TripStringsSpotsX.galleryError), findsOneWidget);
        _repo.error = null;
        _repo.answer = fresh;
        await t.ensureVisible(find.text('Retry'));
        await t.tap(find.text('Retry'));
        await _settle(t);
        expect(_repo.calls, 2);
        expect(find.text('2 photos'), findsOneWidget);
      });

      testWidgets('partial + failed call: error card with Retry', (t) async {
        _repo.error = Exception('down');
        await _open(t, _spot(gallery: 0, photos: 1), partial: true, revalidate: true);
        await _settle(t);
        expect(find.text(TripStringsSpotsX.galleryError), findsOneWidget);
        _repo.error = null;
        _repo.answer = fresh;
        await t.ensureVisible(find.text('Retry'));
        await t.tap(find.text('Retry'));
        await _settle(t);
        expect(_repo.calls, 2);
        expect(find.text('Edited by the admin.'), findsOneWidget);
      });

      testWidgets('a newer answer version removes the stored city list; the same version keeps it', (t) async {
        TripSpotsCache.save(1, [_spot()], 'v1');
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        _repo.answer = SpotDetail(gallery: const [], version: 'v1');
        await _open(t, _spot(), revalidate: true);
        await _settle(t);
        expect(TripSpotsCache.versionOf(1), 'v1');
        Navigator.of(_ctx).pop();
        await t.pump(const Duration(milliseconds: 700));
        _repo.answer = fresh;
        await _open(t, _spot(), revalidate: true);
        await _settle(t);
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        expect(TripSpotsCache.versionOf(1), isNull);
      });
    });

    testWidgets('gallery tile opens the viewer over the gallery list', (t) async {
      await _open(t, _spot(gallery: 5));
      await _settle(t);
      await t.ensureVisible(find.text('+2 more'));
      await t.tap(find.text('+2 more'));
      await _settle(t);
      expect(find.byType(SpotPhotoViewer), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
    });
  });

  group('hero and text', () {
    testWidgets('3 photos: dots, hero segment, tap opens viewer at the current page', (t) async {
      await _open(t, _spot(photos: 3));
      expect(_shown.first, contains('c_fill,g_auto,w_1080,h_640'));
      expect(find.bySemanticsLabel('Naini Lake, photo 1 of 3'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Naini Lake, photo 1 of 3'));
      await _settle(t);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('1 photo: no dots, tap shows 1 / 1', (t) async {
      await _open(t, _spot(photos: 1));
      expect(find.byType(AnimatedContainer), findsNothing);
      await t.tap(find.bySemanticsLabel('Naini Lake, photo 1 of 1'));
      await _settle(t);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('0 photos: art hero, not tappable', (t) async {
      await _open(t, _spot(photos: 0));
      expect(find.byType(PageView), findsNothing);
      expect(find.bySemanticsLabel(RegExp('photo 1 of')), findsNothing);
    });

    testWidgets('chips: Featured first, no area chip when missing', (t) async {
      await _open(t, _spot(area: null));
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Mallital'), findsNothing);
      expect(find.text('~1.5 h'), findsOneWidget);
      expect(t.getTopLeft(find.text('Featured')).dx, lessThan(t.getTopLeft(find.text('~1.5 h')).dx + 1));
    });

    testWidgets('short description: no pill', (t) async {
      await _open(t, _spot());
      expect(find.text('A calm lake.'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });

    testWidgets('no description: block absent', (t) async {
      await _open(t, _spot(description: null));
      expect(find.text('A calm lake.'), findsNothing);
      expect(find.text('Read more'), findsNothing);
    });

    testWidgets('long description: Read more, then Show less', (t) async {
      await _open(t, _spot(description: _long));
      expect(t.widget<Text>(find.text(_long)).maxLines, 4);
      await t.ensureVisible(find.text('Read more'));
      await t.tap(find.text('Read more'));
      await t.pump();
      expect(find.text('Show less'), findsOneWidget);
      expect(t.widget<Text>(find.text(_long)).maxLines, isNull);
    });
  });

  group('action', () {
    testWidgets('Add to trip', (t) async {
      await _open(t, _spot());
      expect(find.text('Add to trip'), findsOneWidget);
    });

    testWidgets('Remove comes from the strings class as a white pill', (t) async {
      await _open(t, _spot(), selected: true);
      expect(find.widgetWithText(WhitePillButton, 'Remove'), findsOneWidget);
    });

    testWidgets('Added without a toggle', (t) async {
      await _open(t, _spot(), selected: true, noToggle: true);
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('locked and not selected is dimmed', (t) async {
      await _open(t, _spot(), locked: true);
      final o = t.widget<Opacity>(find.ancestor(of: find.byType(GradientPillButton), matching: find.byType(Opacity)).first);
      expect(o.opacity, Alpha.v45);
    });

    testWidgets('showAction false: no button at all', (t) async {
      await _open(t, _spot(), showAction: false);
      expect(find.text('Add to trip'), findsNothing);
      expect(find.byType(GradientPillButton), findsNothing);
    });
  });

  group('sizes', () {
    testWidgets('hero is 200 at 320 and 248 at 360+', (t) async {
      double f(double w) => math.max(DS.s(200), math.min(DS.s(248), w * 0.62));
      for (final w in [300.0, 320.0, 360.0, 400.0, 640.0]) {
        expect(TripSpotDetailSheet.heroHeight(w), closeTo(f(w), 0.01));
      }
      if (DS.s(1) == 1) {
        expect(TripSpotDetailSheet.heroHeight(320), 200);
        expect(TripSpotDetailSheet.heroHeight(400), 248);
        expect(TripSpotDetailSheet.heroHeight(640), 248);
      }
    });

    for (final w in [320.0, 360.0]) {
      for (final s in [1.0, 1.3]) {
        for (final long in [false, true]) {
          testWidgets('opens tall at $w x $s (${long ? 'long' : 'short'}): 92% below the status bar, white card to the bottom, action pinned', (t) async {
            if (long) _repo.answer = SpotDetail(gallery: [for (var i = 0; i < 10; i++) _u('g$i')]);
            await _open(t, long ? _spot(gallery: 10, description: _long) : _spot(description: null), size: Size(w, 800), scale: s);
            await _settle(t);
            expect(t.takeException(), isNull);
            final sheet = t.getRect(find.byType(TripSpotDetailSheet));
            final mq = MediaQuery.of(_ctx);
            expect(sheet.height, closeTo(800 - TripSpotDetailSheet.topGap(mq), 0.5));
            expect(sheet.height, greaterThanOrEqualTo((800 - mq.padding.top) * 0.9));
            expect(sheet.bottom, closeTo(800, 0.5));
            final pill = t.getRect(find.byType(GradientPillButton));
            expect(pill.bottom, greaterThan(sheet.bottom - DS.s(100)));
            final card = t.getRect(find.descendant(of: find.byType(TripSpotDetailSheet), matching: find.byWidgetPredicate((x) => x is Container && x.constraints != null && x.constraints!.minHeight > DS.s(100))).first);
            expect(card.bottom, greaterThanOrEqualTo(pill.top - DS.gv(12) - 0.5));
            await t.tap(find.byType(GradientPillButton));
            await t.pump();
            await t.pump(const Duration(milliseconds: 700));
            expect(find.byType(TripSpotDetailSheet), findsNothing);
          });
        }
      }
    }

    test('topGap leaves 8% of the screen below the status bar', () {
      const mq = MediaQueryData(size: Size(360, 800), padding: EdgeInsets.only(top: 24));
      expect(TripSpotDetailSheet.topGap(mq), closeTo(24 + 776 * 0.08, 0.01));
    });

    for (final w in [320.0, 360.0, 411.0, 820.0]) {
      for (final s in [1.0, 1.3]) {
        testWidgets('no exception at $w x $s with a long title and full gallery', (t) async {
          _repo.answer = SpotDetail(gallery: [for (var i = 0; i < 10; i++) _u('g$i')]);
          await _open(t, _spot(gallery: 10, description: _long, name: 'Naina Devi Temple and the old mall road jetty'), size: Size(w, 800), scale: s);
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(_gallery, findsOneWidget);
        });
      }
    }
  });

  group('lists and decode limits', () {
    Future<void> host(WidgetTester t, Widget child) async {
      await pumpPhone(t, Scaffold(body: SingleChildScrollView(child: child)), devicePixelRatio: 2);
    }

    testWidgets('row with 3 photos: card segment and +2 chip; 1 photo: no chip', (t) async {
      await host(t, Column(children: [
        TripSpotRow(spot: _spot(photos: 3), selected: false, onToggle: () {}),
        TripSpotRow(spot: _spot(photos: 1).copyForTest('one'), selected: false, onToggle: () {}),
      ]));
      expect(_shown.every((u) => u.contains('c_fill,g_auto,w_720,h_400')), isTrue);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('rail card uses the square segment', (t) async {
      await host(t, TripMustSeeRail(city: 'Nainital', spots: [_spot(photos: 2)], selected: const {}, lockedOf: (_) => false, toggleOf: (_) => null));
      expect(_shown.single, contains('c_fill,g_auto,w_320,h_320'));
    });

    testWidgets('every spot CachedNetworkImage has a decode width', (t) async {
      TripSpotMedia.debugImageBuilder = null;
      await host(t, Column(children: [
        TripSpotRow(spot: _spot(photos: 3), selected: false, onToggle: () {}),
        SizedBox(height: 200, width: 300, child: TripSpotMedia(spot: _spot(photos: 1), size: SpotPhotoSize.hero)),
      ]));
      final images = t.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(images, isNotEmpty);
      for (final i in images) {
        expect(i.memCacheWidth, isNotNull);
        expect(i.memCacheWidth, lessThanOrEqualTo(1080));
      }
    });
  });
}

extension on TripSpotModel {
  TripSpotModel copyForTest(String id) => TripSpotModel(
        id: id,
        source: source,
        name: name,
        latitude: latitude,
        longitude: longitude,
        category: category,
        visitMinutes: visitMinutes,
        images: images,
      );
}
