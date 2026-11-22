import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_details.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/widgets/detail_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _Launcher extends UrlLauncherPlatform {
  final List<String> opened = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

Widget _host(Widget bar, {Size size = const Size(360, 800), double scale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: size.width, child: bar))),
      ),
    );

DetailActionBar _stay({VoidCallback? onChat, bool reported = false, bool owner = false}) => DetailActionBar(
      latitude: 29.39,
      longitude: 79.45,
      ownerPhone: '9876543210',
      onChat: onChat,
      whatsAppPhone: onChat == null ? '9876543210' : null,
      isOwner: owner,
      onReport: reported ? null : () {},
      palette: templateModulePalette,
      calm: true,
      showSafety: false,
    );

DetailActionBar _taxi({VoidCallback? onReport}) => DetailActionBar(
      ownerPhone: '9876500000',
      whatsAppPhone: '9876500000',
      showDirections: false,
      safetyText: TaxiOptionSets.safetyLine,
      onReport: onReport ?? () {},
      palette: templateTaxiPalette,
      calm: true,
    );

double _dy(WidgetTester t, String text) => t.getCenter(find.text(text)).dy;

void main() {
  late _Launcher launcher;
  setUp(() {
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('stay bar: Directions, Call, WhatsApp in one row, then Report, no safety line', (t) async {
    await t.pumpWidget(_host(_stay()));
    for (final s in ['Directions', 'Call', 'WhatsApp', 'Report this listing']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Chat'), findsNothing);
    expect(find.textContaining('never collects'), findsNothing);
    expect(_dy(t, 'Directions'), closeTo(_dy(t, 'Call'), 0.01));
    expect(_dy(t, 'Call'), closeTo(_dy(t, 'WhatsApp'), 0.01));
    expect(_dy(t, 'Report this listing'), greaterThan(_dy(t, 'Call')));
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.call_rounded && w.color == Ink3D.title), findsOneWidget);
    expect(find.byType(DetailCalmButton), findsNWidgets(4));
    expect(find.byType(DetailBarButton), findsNothing);
  });

  testWidgets('stay bar from a trip: Chat instead of WhatsApp', (t) async {
    var chats = 0;
    await t.pumpWidget(_host(_stay(onChat: () => chats++)));
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    await t.tap(find.text('Chat'));
    expect(chats, 1);
  });

  testWidgets('taxi bar: safety line above Call and WhatsApp, then Report', (t) async {
    await t.pumpWidget(_host(_taxi()));
    expect(find.text(TaxiOptionSets.safetyLine), findsOneWidget);
    expect(find.text('Directions'), findsNothing);
    expect(_dy(t, TaxiOptionSets.safetyLine), lessThan(_dy(t, 'Call')));
    expect(_dy(t, 'Call'), closeTo(_dy(t, 'WhatsApp'), 0.01));
    expect(_dy(t, 'Report this listing'), greaterThan(_dy(t, 'Call')));
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
  });

  testWidgets('reported: Reported pill is disabled; owner: no report row', (t) async {
    await t.pumpWidget(_host(_stay(reported: true)));
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Report this listing'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Reported' && w.properties.enabled == false), findsOneWidget);
    await t.pumpWidget(_host(_stay(owner: true)));
    expect(find.text('Report this listing'), findsNothing);
    expect(find.text('Reported'), findsNothing);
  });

  testWidgets('default bar (Job, calm off) still builds the old widgets', (t) async {
    await t.pumpWidget(_host(DetailActionBar(ownerPhone: '9876543210', whatsAppPhone: '9876543210', showDirections: false, onReport: () {}, palette: templateModulePalette)));
    expect(find.byType(DetailBarButton), findsWidgets);
    expect(find.byType(DetailCalmButton), findsNothing);
  });

  testWidgets('taps open the phone and WhatsApp launchers, report fires once', (t) async {
    var reports = 0;
    await t.pumpWidget(_host(_taxi(onReport: () => reports++)));
    await t.tap(find.text('Call'));
    await t.pump();
    await t.tap(find.text('WhatsApp'));
    await t.pump();
    await t.tap(find.text('Report this listing'));
    await t.pump();
    expect(launcher.opened.where((u) => u.startsWith('tel:')), hasLength(1));
    expect(launcher.opened.where((u) => u.contains('wa.me') || u.contains('whatsapp')), hasLength(1));
    expect(reports, 1);
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('bars fit at $w @$scale', (t) async {
        final size = Size(w, 800);
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(_stay(), size: size, scale: scale));
        expect(t.takeException(), isNull);
        await t.pumpWidget(_host(_taxi(), size: size, scale: scale));
        expect(t.takeException(), isNull);
        final h = t.getSize(find.ancestor(of: find.text('Call'), matching: find.byType(DetailCalmButton))).height;
        expect(h, closeTo(DS.s(DetailCalmButton.height), 0.01));
      });
    }
  }
}
