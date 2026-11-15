import 'package:bakhli/config/module_palette.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/widgets/detail_action_bar.dart';
import 'package:bakhli/widgets/scroll_reveal_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({required this.contentHeight, required this.bar});
  final double contentHeight;
  final Widget bar;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final scroll = ScrollController();
  final reveal = RevealBarController();

  @override
  void initState() {
    super.initState();
    reveal.attach(scroll);
  }

  @override
  void dispose() {
    reveal.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          reveal.wrap(CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: widget.contentHeight, key: const Key('content'))),
              RevealBarPad(reveal),
            ],
          )),
          Positioned(left: 0, right: 0, bottom: 0, child: ScrollRevealBar(controller: reveal, child: widget.bar)),
        ]),
      );
}

DetailActionBar _bar({bool chat = false, bool directions = true, String? whatsApp, ModulePalette? palette}) => DetailActionBar(
      ownerPhone: '9999999999',
      showDirections: directions,
      onChat: chat ? () {} : null,
      whatsAppPhone: whatsApp,
      palette: palette,
      onReport: () {},
    );

Future<void> _pump(WidgetTester t, Widget host, {bool reduce = false}) async {
  await t.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(size: const Size(360, 800), disableAnimations: reduce), child: host)));
  await t.pump();
  await t.pump();
}

double _barTop(WidgetTester t) => t.getTopLeft(find.text('Call').first).dy;

ScrollPosition _pos(WidgetTester t) => t.state<ScrollableState>(find.byType(Scrollable)).position;

void main() {
  testWidgets('bar is hidden at the top, shown at the end, hidden again after scrolling up', (t) async {
    await _pump(t, _Host(contentHeight: 2000, bar: _bar(chat: true)));
    expect(find.text('Call'), findsNothing);
    final pos = _pos(t);

    pos.jumpTo(pos.maxScrollExtent);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final mid = _barTop(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(_barTop(t), lessThan(mid));
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Report this listing'), findsOneWidget);

    pos.jumpTo(pos.maxScrollExtent - 300);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Call'), findsNothing);
  });

  testWidgets('bar is shown immediately when the content is short', (t) async {
    await _pump(t, _Host(contentHeight: 200, bar: _bar()));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('scroll extent keeps room so the last content clears the bar', (t) async {
    await _pump(t, _Host(contentHeight: 2000, bar: _bar()));
    final pos = _pos(t);
    pos.jumpTo(pos.maxScrollExtent);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final contentBottom = t.getBottomLeft(find.byKey(const Key('content'))).dy;
    expect(contentBottom, lessThanOrEqualTo(t.getTopLeft(find.text('Call')).dy));
  });

  testWidgets('reduce motion shows the bar without animation', (t) async {
    await _pump(t, _Host(contentHeight: 2000, bar: _bar()), reduce: true);
    final pos = _pos(t);
    pos.jumpTo(pos.maxScrollExtent);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('scroll ticks do not rebuild the bar content', (t) async {
    var builds = 0;
    await _pump(
      t,
      _Host(
        contentHeight: 3000,
        bar: Builder(builder: (_) {
          builds++;
          return _bar();
        }),
      ),
    );
    final before = builds;
    final pos = _pos(t);
    for (var i = 1; i <= 5; i++) {
      pos.jumpTo(i * 200.0);
      await t.pump();
    }
    expect(builds, before);
  });

  group('button rows', () {
    testWidgets('stay: Directions, Call, Chat in one row, then Report; no WhatsApp', (t) async {
      await _pump(t, _Host(contentHeight: 100, bar: _bar(chat: true, palette: templateModulePalette)));
      await t.pump(const Duration(milliseconds: 500));
      for (final l in ['Directions', 'Call', 'Chat', 'Report this listing']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Call Owner'), findsNothing);
      final d = t.getCenter(find.text('Directions'));
      final c = t.getCenter(find.text('Call'));
      final h = t.getCenter(find.text('Chat'));
      expect(c.dy, closeTo(d.dy, 0.01));
      expect(h.dy, closeTo(d.dy, 0.01));
      expect(d.dx, lessThan(c.dx));
      expect(c.dx, lessThan(h.dx));
      expect(t.getCenter(find.text('Report this listing')).dy, greaterThan(d.dy));
    });

    testWidgets('taxi: Call and WhatsApp in one row, no Chat or Directions', (t) async {
      await _pump(t, _Host(contentHeight: 100, bar: _bar(directions: false, whatsApp: '9999999999', palette: templateTaxiPalette)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
      expect(find.text('Directions'), findsNothing);
      expect(find.text('Call Driver'), findsNothing);
      expect(t.getCenter(find.text('Call')).dy, t.getCenter(find.text('WhatsApp')).dy);
      expect(find.text('Report this listing'), findsOneWidget);
    });

    testWidgets('owner view has no Report or Chat', (t) async {
      await _pump(t, const _Host(contentHeight: 100, bar: DetailActionBar(isOwner: true, latitude: 1, longitude: 1)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Report this listing'), findsNothing);
      expect(find.text('Chat'), findsNothing);
    });
  });
}
