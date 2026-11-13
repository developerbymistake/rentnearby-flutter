import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/stay/models/stay_nearby_model.dart';
import 'package:bakhli/features/taxi/models/taxi_browse_item.dart';
import 'package:bakhli/features/taxi/ways/models/taxi_ways_models.dart';
import 'package:bakhli/features/taxi/ways/widgets/way_driver_row.dart';
import 'package:bakhli/features/trip/widgets/trip_driver_row.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:bakhli/features/trip/widgets/trip_stay_row.dart';
import 'package:bakhli/widgets/listing_contact_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StayNearbyModel _stay({String? url, String? phone}) => StayNearbyModel(
      id: 's1',
      name: 'Hill View',
      latitude: 1,
      longitude: 1,
      distanceKm: 2,
      isActive: true,
      thumbnailUrl: url,
      ownerPhone: phone,
    );

TaxiBrowseItem _taxi() => TaxiBrowseItem(
      id: 't1',
      driverName: 'Ravi Kumar',
      vehicleTypeName: 'Sedan',
      plateDisplay: 'UK07 AB 1234',
      routeCount: 0,
      matchReversed: false,
      createdAt: DateTime(2026, 11, 1),
    );

class _Taps {
  int open = 0, call = 0, ask = 0, shortlist = 0, chat = 0;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

class _Fake {
  ListingContact? contact;
  final dialed = <String>[];
  final routes = <(String, Object?)>[];
  final infos = <String>[];
  int fetches = 0;

  ListingContactDeps get deps => ListingContactDeps(
        fetchContact: (kind, id) async {
          fetches++;
          return contact;
        },
        currentUserId: () => 'me',
        dial: (p) async => dialed.add(p),
        createConversation: (type, id) async => null,
        openRoute: (r, a) => routes.add((r, a)),
        info: infos.add,
      );
}

void main() {
  late _Fake fake;

  setUp(() {
    fake = _Fake();
    ListingContactActions.debugDeps = fake.deps;
    ListingContactActions.busy.clear();
  });

  tearDown(() => ListingContactActions.debugDeps = null);

  group('trip stay row taps', () {
    testWidgets('Call and Ask run their own callbacks, never the detail', (t) async {
      final taps = _Taps();
      await t.pumpWidget(_host(TripStayRow(
        stay: _stay(),
        onOpen: () => taps.open++,
        onCall: () => taps.call++,
        onAsk: () => taps.ask++,
      )));
      await t.tap(find.byIcon(Icons.call_rounded));
      await t.tap(find.byIcon(Icons.send_rounded));
      expect((taps.call, taps.ask, taps.open), (1, 1, 0));
      await t.tap(find.text('Hill View'));
      expect(taps.open, 1);
    });

    testWidgets('Shortlist cell toggles the shortlist, not the detail', (t) async {
      final taps = _Taps();
      await t.pumpWidget(_host(TripStayRow(
        stay: _stay(),
        onOpen: () => taps.open++,
        onCall: () => taps.call++,
        onAsk: () => taps.ask++,
        onShortlist: () => taps.shortlist++,
      )));
      await t.tap(find.byIcon(Icons.add_rounded));
      expect((taps.shortlist, taps.open, taps.ask), (1, 0, 0));
    });

    testWidgets('asked stay with a chat opens the chat', (t) async {
      final taps = _Taps();
      await t.pumpWidget(_host(TripStayRow(
        stay: _stay(),
        status: TripDisplayStatus.asked,
        onOpen: () => taps.open++,
        onCall: () => taps.call++,
        onOpenChat: () => taps.chat++,
      )));
      await t.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      expect((taps.chat, taps.open), (1, 0));
    });

    testWidgets('Call shows a spinner while busy', (t) async {
      await t.pumpWidget(_host(TripStayRow(stay: _stay(), onOpen: () {}, onCall: () {}, callBusy: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('trip stay photo', () {
    testWidgets('thumbnail url reaches the photo banner', (t) async {
      const url = 'https://example.com/a.jpg';
      await t.pumpWidget(_host(TripStayRow(stay: _stay(url: url), onOpen: () {})));
      final photo = t.widget<KitPhoto>(find.byType(KitPhoto));
      expect(photo.url, url);
      expect(t.widget<WideCard>(find.byType(WideCard)).kind, WideKind.photo);
    });

    testWidgets('no url shows the halo art, not a blank band', (t) async {
      for (final url in [null, '']) {
        await t.pumpWidget(_host(TripStayRow(key: ValueKey('$url'), stay: _stay(url: url), onOpen: () {})));
        expect(find.byType(KitPhoto), findsNothing);
        expect(t.widget<WideCard>(find.byType(WideCard)).kind, WideKind.halo);
        expect(t.widgetList<Art3D>(find.byType(Art3D)).where((a) => a.asset == ListingArt.key), isNotEmpty);
      }
    });

    test('nearby model: empty url is no photo, relative url gets the server', () {
      Map<String, dynamic> json(Object? u) => {'id': 's1', 'latitude': 1, 'longitude': 1, 'distanceKm': 1, 'thumbnailUrl': u};
      expect(StayNearbyModel.fromJson(json('')).thumbnailUrl, isNull);
      expect(StayNearbyModel.fromJson(json(null)).thumbnailUrl, isNull);
      expect(StayNearbyModel.fromJson(json('/uploads/a.jpg')).thumbnailUrl, allOf(startsWith('https://'), endsWith('/uploads/a.jpg')));
      expect(StayNearbyModel.fromJson(json('https://cdn.x/a.jpg')).thumbnailUrl, 'https://cdn.x/a.jpg');
    });
  });

  group('trip stay Call action', () {
    Future<BuildContext> ctxOf(WidgetTester t) async {
      late BuildContext ctx;
      await t.pumpWidget(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }));
      return ctx;
    }

    testWidgets('no phone in the list: loads the detail and dials a visible phone', (t) async {
      final ctx = await ctxOf(t);
      fake.contact = const ListingContact(ownerId: 'host', phone: '9876543210');
      await TripStayRow.call(ctx, _stay());
      expect(fake.fetches, 1);
      expect(fake.dialed, ['9876543210']);
      expect(fake.routes, isEmpty);
    });

    testWidgets('hidden phone: opens the detail with its arguments and a short message', (t) async {
      final ctx = await ctxOf(t);
      fake.contact = const ListingContact(ownerId: 'host');
      await TripStayRow.call(ctx, _stay(), detailArguments: {'distanceKm': 2.0});
      expect(fake.dialed, isEmpty);
      expect(fake.infos, [ListingContactActions.phoneHiddenMessage]);
      expect(fake.routes.single.$1, AppRoutes.stayDetail);
      expect(fake.routes.single.$2, {'distanceKm': 2.0, 'id': 's1'});
    });

    testWidgets('visible phone in the list: dials it without a detail load', (t) async {
      final ctx = await ctxOf(t);
      final dialed = <String>[];
      final before = TripStayRow.dial;
      TripStayRow.dial = (p) async => dialed.add(p);
      addTearDown(() => TripStayRow.dial = before);
      await TripStayRow.call(ctx, _stay(phone: '9876543210'));
      expect(dialed, ['9876543210']);
      expect(fake.fetches, 0);
      expect(fake.routes, isEmpty);
    });
  });

  group('trip driver row taps', () {
    Widget row(_Taps taps, {TripDisplayStatus? status, bool busy = false, VoidCallback? onShortlist}) => _host(TripDriverRow(
          item: _taxi(),
          status: status,
          contactBusy: busy,
          onOpen: () => taps.open++,
          onCall: () => taps.call++,
          onAsk: () => taps.ask++,
          onMenu: (_) {},
          onShortlist: onShortlist,
        ));

    testWidgets('Call and Ask run their own callbacks, never the detail', (t) async {
      final taps = _Taps();
      await t.pumpWidget(row(taps));
      await t.tap(find.byIcon(Icons.call_rounded));
      await t.tap(find.byIcon(Icons.send_rounded));
      expect((taps.call, taps.ask, taps.open), (1, 1, 0));
    });

    testWidgets('asked driver: View status goes to the ask, not the detail', (t) async {
      final taps = _Taps();
      await t.pumpWidget(row(taps, status: TripDisplayStatus.asked));
      await t.tap(find.byIcon(Icons.visibility_outlined));
      expect((taps.ask, taps.open), (1, 0));
    });

    testWidgets('Shortlist cell toggles the shortlist', (t) async {
      final taps = _Taps();
      await t.pumpWidget(row(taps, onShortlist: () => taps.shortlist++));
      await t.tap(find.byIcon(Icons.add_rounded));
      expect((taps.shortlist, taps.open, taps.ask), (1, 0, 0));
    });

    testWidgets('taxi card shows vehicle art, no photo, and a spinner while the call loads', (t) async {
      await t.pumpWidget(row(_Taps(), busy: true));
      expect(find.byType(KitPhoto), findsNothing);
      expect(t.widget<WideCard>(find.byType(WideCard)).kind, WideKind.halo);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ways driver row', () {
    WayDriver driver() => WayDriver.fromJson({'taxiId': 't9', 'driverName': 'Mohan', 'fromName': 'Dehradun', 'toName': 'Mussoorie', 'listedFare': 1500});

    testWidgets('Call runs onCall, not the detail; spinner while busy', (t) async {
      var call = 0, open = 0;
      await t.pumpWidget(_host(WayDriverRow(driver: driver(), onTap: () => open++, onCall: () => call++)));
      await t.tap(find.byIcon(Icons.call_rounded));
      expect((call, open), (1, 0));
      await t.pumpWidget(_host(WayDriverRow(driver: driver(), onTap: () {}, onCall: () {}, callBusy: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
