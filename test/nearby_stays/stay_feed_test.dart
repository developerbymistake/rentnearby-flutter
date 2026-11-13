import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/stay_grid_card.dart';
import 'package:bakhli/features/nearby/data/nearby_repository_base.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/features/nearby/widgets/nearby_label_text.dart';
import 'package:bakhli/features/stay/guest/v2/stay_feed_item.dart';
import 'package:bakhli/features/stay/guest/v2/stay_landing_controller_v2.dart';
import 'package:bakhli/models/card_fact.dart';
import 'package:bakhli/models/home_feed_model_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Map<String, dynamic> _stay(String id, {double? km = 3.2, String label = 'near', String? city = 'Nainital', bool featured = false}) => {
      'id': id,
      'userId': 'u',
      'name': 'Stay $id',
      'cityName': city,
      'districtName': 'Nainital',
      'stateName': 'Uttarakhand',
      'minPricePerNight': 1200,
      'isFeatured': featured,
      'distanceKm': ?km,
      'labelKey': label,
    };

class _Ctrl extends StayLandingControllerV2 {
  final version = 0.obs;
  final calls = <String?>[];
  final types = <String?>[];
  Future<NearbyPage<StayFeedItem>> Function(String? token)? handler;

  @override
  RxInt get centreVersion => version;
  @override
  RxInt? get tabRx => null;
  @override
  int? get tabIndex => null;
  @override
  Future<NearbyPage<StayFeedItem>> fetchPage(String? token) async {
    calls.add(token);
    types.add(selectedStayTypeId.value);
    return handler == null ? const NearbyPage() : handler!(token);
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => Get.testMode = true);

  group('parse', () {
    test('photo url is read, relative paths get the server host, absolute ones stay', () {
      final rel = StayFeedItem.fromJson({..._stay('a'), 'thumbnailUrl': '/uploads/stays/a.jpg'});
      expect(rel.item.thumbnailUrl, endsWith('/uploads/stays/a.jpg'));
      expect(rel.item.thumbnailUrl, startsWith('https://'));
      final abs = StayFeedItem.fromJson({..._stay('b'), 'thumbnailUrl': 'https://picsum.photos/seed/x/900/600'});
      expect(abs.item.thumbnailUrl, 'https://picsum.photos/seed/x/900/600');
      expect(StayFeedItem.fromJson(_stay('c')).item.thumbnailUrl, isNull);
    });

    test('card facts keep type, meals and room name; price keeps FROM and unit', () {
      final s = StayFeedItem.fromJson({..._stay('a'), 'stayTypeName': 'Homestay', 'mealsChip': 'Breakfast', 'roomNameChip': 'Deluxe'});
      expect(s.item.facts.map((f) => f.label), ['Homestay', 'Breakfast', 'Deluxe']);
      expect(s.item.priceCaption, 'FROM');
      expect(s.item.priceUnit, '/night');
      expect(s.minPrice, 1200);
    });

    test('stay item keeps browse fields and distance', () {
      final s = StayFeedItem.fromJson(_stay('a', km: 420, label: 'far'));
      expect(s.id, 'a');
      expect(s.item.title, 'Stay a');
      expect(s.distance.km, 420);
      expect(s.distance.label, NearbyLabel.far);
      expect(s.distance.state, 'Uttarakhand');
    });

    test('far label never reads as near, missing fields tolerated', () {
      final s = StayFeedItem.fromJson(_stay('a', km: 20, label: 'near'));
      expect(s.distance.label, NearbyLabel.far);
      final m = StayFeedItem.fromJson({'id': 'x'});
      expect(m.distance.km, 0);
      expect(m.item.title, 'Stay');
    });

    test('page response parses header, featured and items', () {
      final page = NearbyRepositoryBase.pageFromResponse<StayFeedItem>({
        'data': {
          'header': {'farAway': true, 'nearestKm': 420.0},
          'featured': [_stay('f', featured: true)],
          'items': [_stay('a'), _stay('b')],
          'hasMore': true,
          'nextToken': 't',
        }
      }, StayFeedItem.fromJson);
      expect(page.featured.length, 1);
      expect(page.items.length, 2);
      expect(page.header.farAway, true);
      expect(page.nextToken, 't');
    });
  });

  group('home mapping', () {
    test('stay label lines are honest', () {
      expect(HomeFeedModelV2.stay(_stay('a', km: 3.2)).item.locationLabel, 'Nainital. About 3.2 km away');
      final far = HomeFeedModelV2.stay(_stay('a', km: 420, label: 'far', city: 'Haldwani')).item.locationLabel;
      expect(far, 'Haldwani, Uttarakhand. About 420 km away');
      expect(far.toLowerCase().contains('near you'), false);
      expect(HomeFeedModelV2.stay(_stay('a', km: 2, label: 'inCity')).item.locationLabel, 'In Nainital');
    });

    test('no distance keeps the old label and district name', () {
      final m = HomeFeedModelV2.stay(_stay('a', km: null));
      expect(m.item.locationLabel, 'Nainital');
      expect(m.districtName, 'Nainital');
    });

    test('taxi city carries the label line and feed shape parses', () {
      final feed = HomeFeedModelV2.fromJson({
        'tabs': {'stays': true, 'taxi': false},
        'stays': [_stay('a')],
        'taxis': [
          {
            'id': 't',
            'driverName': 'Ravi',
            'vehicleTypeName': 'Sedan',
            'plateDisplay': 'UK04',
            'routeCount': 2,
            'createdAt': '2026-01-01T00:00:00Z',
            'cityName': 'Haldwani',
            'stateName': 'Uttarakhand',
            'distanceKm': 25,
            'labelKey': 'far',
          }
        ],
        'recentStays': null,
      });
      expect(feed.stays!.length, 1);
      expect(feed.taxis!.single.cityName, 'Haldwani, Uttarakhand. About 25 km away');
      expect(feed.recentStays, isNull);
      expect(feed.isSectionTabOff('taxis'), true);
    });
  });

  group('controller', () {
    test('reloads when the centre changes', () async {
      final c = _Ctrl()..handler = (t) async => NearbyPage(items: [StayFeedItem.fromJson(_stay('a'))]);
      c.onInit();
      await _flush();
      expect(c.calls.length, 1);
      c.version.value++;
      await _flush();
      await _flush();
      expect(c.calls.length, 2);
      expect(c.items.length, 1);
    });

    test('stay type filter reloads with the type', () async {
      final c = _Ctrl();
      c.onInit();
      await _flush();
      c.setStayType('villa');
      await _flush();
      expect(c.types.last, 'villa');
      c.setStayType('villa');
      await _flush();
      expect(c.calls.length, 2);
    });

    test('posted trigger reloads', () async {
      final c = _Ctrl();
      c.onInit();
      await _flush();
      c.stayPostedTrigger.value++;
      await _flush();
      expect(c.calls.length, 2);
    });

    test('featured dedupes against items and empty system is empty', () async {
      final c = _Ctrl()
        ..handler = (t) async => NearbyPage(
              featured: [StayFeedItem.fromJson(_stay('f', featured: true))],
              items: [StayFeedItem.fromJson(_stay('f')), StayFeedItem.fromJson(_stay('b'))],
            );
      c.onInit();
      await _flush();
      expect(c.featured.length, 1);
      expect(c.items.map((e) => e.id), ['b']);
      final e = _Ctrl();
      e.onInit();
      await _flush();
      expect(e.isEmpty, true);
    });
  });

  group('layout', () {
    for (final w in [300.0, 560.0]) {
      testWidgets('card with label fits at ${w.toInt()} dp and 1.3 text', (t) async {
        t.view.physicalSize = Size(w, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        const far = NearbyDistance(km: 420, label: NearbyLabel.far, city: 'Haldwani', state: 'Uttarakhand');
        await t.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(w, 900), textScaler: const TextScaler.linear(1.3)),
            child: Builder(builder: (context) {
              final labelH = 12 + MediaQuery.textScalerOf(context).scale(14) * 6;
              return Scaffold(
                body: GridView.builder(
                  padding: const EdgeInsets.all(KitMetrics.gutter),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: RailCard.gridMaxExtent,
                    mainAxisExtent: StayGridCard.height + labelH,
                    mainAxisSpacing: RailCard.gridSpacing,
                    crossAxisSpacing: RailCard.gridSpacing,
                  ),
                  itemCount: 4,
                  itemBuilder: (_, i) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: StayGridCard.height,
                        child: StayGridCard(
                          thumbnailUrl: null,
                          tagLabel: 'FOR STAY',
                          title: 'A very long stay name for the test',
                          locationLabel: 'Nainital',
                          facts: const [CardFact('Hotel')],
                          priceCaption: 'FROM',
                          priceValue: 'Rs 1,200',
                          priceUnit: '/night',
                          onViewDetails: () {},
                        ),
                      ),
                      const Expanded(
                        child: ClipRect(
                          child: SingleChildScrollView(
                            physics: NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.only(top: 6, left: 2),
                            child: NearbyLabelText(distance: far),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  });
}
