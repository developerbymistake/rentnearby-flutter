import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/widgets/role_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

const _desc = {
  UserRoleKeys.seeker: 'Plan trips, find stays and book local taxis.',
  UserRoleKeys.stayOwner: 'List your homestay or hotel, receive enquiries and post jobs for your staff and your guests.',
  UserRoleKeys.taxiDriver: 'Offer local rides and long trips.',
};

RoleModel _role(String k) => RoleModel(key: k, name: RoleVisuals.displayName(k), description: _desc[k]!, sortOrder: 1);

Widget _host(Widget child, {required double width, required double scale, bool reduce = false}) => MaterialApp(
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 760), textScaler: TextScaler.linear(scale), disableAnimations: reduce),
        child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
      ),
    );

double _opacityOf(WidgetTester t, Finder f) {
  var v = 1.0;
  for (final e in find.ancestor(of: f, matching: find.byType(Opacity)).evaluate()) {
    v *= (e.widget as Opacity).opacity;
  }
  return v;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  group('RoleOptionCard equal heights', () {
    for (final width in [300.0, 360.0, 560.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('width $width scale $scale', (t) async {
          setGoldenView(t, Size(width, 760));
          await t.pumpWidget(_host(
            Column(children: [
              RoleOptionCard(role: _role(UserRoleKeys.seeker), isCurrent: true, onTap: () {}),
              const SizedBox(height: 12),
              RoleOptionCard(role: _role(UserRoleKeys.stayOwner), selected: true, onTap: () {}),
              const SizedBox(height: 12),
              RoleOptionCard(role: _role(UserRoleKeys.taxiDriver), onTap: () {}),
            ]),
            width: width,
            scale: scale,
          ));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
          final h = find.byType(RoleOptionCard).evaluate().map((e) => (e.renderObject as RenderBox).size.height).toList();
          expect(h.length, 3);
          expect(h[1], h[0]);
          expect(h[2], h[0]);
        });
      }
    }
  });

  group('entrance wrappers first frame', () {
    const card = Key('card');
    Widget content() => const SizedBox(key: card, width: 100, height: 40);

    Future<void> run(WidgetTester t, Widget w, {required bool reduce}) async {
      setGoldenView(t);
      await t.pumpWidget(_host(w, width: 360, scale: 1.0, reduce: reduce));
    }

    for (final reduce in [false, true]) {
      testWidgets('EntranceOnce reduce=$reduce', (t) async {
        await run(t, EntranceOnce(child: content()), reduce: reduce);
        if (reduce) {
          expect(_opacityOf(t, find.byKey(card)), 1.0);
        } else {
          await t.pump(const Duration(milliseconds: 600));
          expect(_opacityOf(t, find.byKey(card)), 1.0);
        }
      });

      testWidgets('StaggerItem reduce=$reduce', (t) async {
        await run(t, StaggerColumn(children: [content(), content()]), reduce: reduce);
        if (reduce) {
          expect(_opacityOf(t, find.byKey(card).first), 1.0);
        } else {
          await t.pump(const Duration(milliseconds: 1200));
          expect(_opacityOf(t, find.byKey(card).first), 1.0);
        }
      });

      testWidgets('RailReveal reduce=$reduce', (t) async {
        await run(
          t,
          SizedBox(height: 80, child: RailReveal(itemCount: 3, itemBuilder: (_, i) => SizedBox(key: i == 0 ? card : null, width: 100, height: 40))),
          reduce: reduce,
        );
        if (reduce) {
          expect(_opacityOf(t, find.byKey(card)), 1.0);
        } else {
          await t.pump();
          await t.pump(const Duration(milliseconds: 1000));
          expect(_opacityOf(t, find.byKey(card)), 1.0);
        }
      });
    }

    testWidgets('StaggerItem without a host shows content at once', (t) async {
      await run(t, const StaggerItem(index: 0, child: SizedBox(key: card, width: 10, height: 10)), reduce: false);
      expect(_opacityOf(t, find.byKey(card)), 1.0);
    });
  });

  group('chat header', () {
    for (final width in [300.0, 360.0]) {
      testWidgets('long title and subtitle do not overflow at $width x1.3', (t) async {
        setGoldenView(t, Size(width, 760));
        await t.pumpWidget(_host(
          ModuleHeader(
            title: 'A very long other party name that must be cut',
            tone: KitTone.stay,
            autoHeight: true,
            animate: false,
            leading: const SizedBox(width: 40, height: 40),
            subtitleWidget: const Text('A very long listing title near the lake . Bhimtal Nainital', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded))],
            onBack: () {},
          ),
          width: width,
          scale: 1.3,
        ));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
      });
    }

    test('ChatKindStyle handles every kind main handled', () {
      for (final k in ['Stay', 'Taxi', 'Job', 'Trip', '', null]) {
        expect(ChatKindStyle.of(k).gradient, isNotNull);
      }
      expect(ChatKindStyle.of('Stay').accent, isNot(ChatKindStyle.of('Taxi').accent));
    });
  });
}
