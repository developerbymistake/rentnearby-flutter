import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/design/extra/ext_notifications.dart';
import 'package:bakhli/models/listing_report_model.dart';
import 'package:bakhli/utils/notification_visuals.dart';
import 'package:bakhli/widgets/report_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

const _notif = ValueKey('row_notification');
const _chat = ValueKey('row_chat');
const _report = ValueKey('row_report');

class _List extends StatelessWidget {
  const _List({required this.push});

  final ValueNotifier<bool> push;

  void _tap(BuildContext context) {
    if (!push.value) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('Detail')))));
  }

  @override
  Widget build(BuildContext context) {
    final kind = NotificationVisuals.kind('trip_update', 'Pine Ridge Stay sent an offer').name;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          EntranceOnce(
            key: _notif,
            index: 0,
            child: NotificationCard3D(
              tone: NotificationTone.of(kind),
              art: NotificationLook.of(kind).asset,
              title: 'Pine Ridge Stay sent an offer',
              body: 'Rs 4,800 for 13 Nov to 15 Nov. Valid 24 h.',
              time: '10:42',
              unit: 'AM',
              tag: 'STAY',
              isNew: true,
              onTap: () => _tap(context),
            ),
          ),
          EntranceOnce(
            key: _chat,
            index: 1,
            child: ChatThreadCard(
              tone: ChatLook3D.toneFor('Stay'),
              initial: ChatLook3D.initialOf('Anita Rao'),
              sticker: ChatLook3D.artFor('Stay'),
              tag: 'STAY',
              title: 'Anita Rao',
              subtitle: 'Pine Ridge Stay · Mall Road',
              time: '2m',
              unread: '3',
              preview: 'Is the room free on 13 Nov?',
              onTap: () => _tap(context),
            ),
          ),
          EntranceOnce(
            key: _report,
            index: 2,
            child: ReportRow(
              report: ListingReportModel(
                id: 'r1',
                listingId: 'l1',
                listingType: 'Stay',
                reasonName: 'Asked for advance',
                details: '',
                status: 'Pending',
                createdAt: DateTime(2026, 11, 12),
                resolvedAt: null,
              ),
              onTap: () => _tap(context),
            ),
          ),
        ],
      ),
    );
  }
}

Rect _painted(WidgetTester t, Key key) {
  final inner = find.descendant(of: find.byKey(key), matching: find.byType(GestureDetector)).first;
  final b = t.renderObject<RenderBox>(inner);
  return MatrixUtils.transformRect(b.getTransformTo(null), Offset.zero & b.size);
}

Size _laid(WidgetTester t, Key key) => t.getSize(find.byKey(key));

Future<void> _pump(WidgetTester t, ValueNotifier<bool> push, {required bool animate, double scale = 1.0}) async {
  await loadRealFonts();
  const dpr = 3.0;
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = Size(phoneSize.width * dpr, phoneSize.height * dpr);
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: !animate),
      child: c!,
    ),
    home: _List(push: push),
  ));
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadRealFonts);

  for (final animate in [true, false]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('rows keep their size after 20 taps and a push and pop (animate $animate, scale $scale)', (t) async {
        final push = ValueNotifier(false);
        await _pump(t, push, animate: animate, scale: scale);
        const keys = [_notif, _chat, _report];
        final size0 = {for (final k in keys) k: _laid(t, k)};
        final rect0 = {for (final k in keys) k: _painted(t, k)};

        void same(String when) {
          for (final k in keys) {
            expect(_laid(t, k), size0[k], reason: '$k layout size $when');
            final r = _painted(t, k);
            expect(r.width, moreOrLessEquals(rect0[k]!.width, epsilon: 0.01), reason: '$k painted width $when');
            expect(r.height, moreOrLessEquals(rect0[k]!.height, epsilon: 0.01), reason: '$k painted height $when');
          }
        }

        for (final k in keys) {
          for (var i = 0; i < 20; i++) {
            await t.tap(find.byKey(k));
            await t.pump(Duration(milliseconds: i.isEven ? 30 : 120));
          }
          await t.pump(const Duration(milliseconds: 600));
          same('after 20 taps on $k');
        }

        push.value = true;
        for (final k in keys) {
          await t.tap(find.byKey(k));
          await t.pump();
          await t.pump(const Duration(milliseconds: 700));
          expect(find.text('Detail'), findsOneWidget);
          t.state<NavigatorState>(find.byType(Navigator)).pop();
          await t.pump();
          await t.pump(const Duration(milliseconds: 700));
          same('after push and pop from $k');
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
