import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/scan/controllers/scan_controller.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_notifications.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/notices/notice_copy.dart';
import 'package:bakhli/features/buddy/notices/widgets/notice_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/buddy_render.dart';
import 'scan_rules_test.dart';
import 'scan_screen_test.dart';

Widget _row(NoticeView v, String time, String unit, {bool read = true}) => NoticeCard(view: v, time: time, unit: unit, isRead: read);

Widget _inbox(List<Widget> children) => Scaffold(
      backgroundColor: ListingPalette.indigo.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NotificationHeader3D(tone: ListingTone.indigo, title: 'Notifications', art: NotificationLook.bell, onBack: () {}),
            Expanded(child: ListView(padding: EdgeInsets.zero, children: children)),
          ],
        ),
      ),
    );

Notice _stored(String kind, {int? amount, String? ref, String? refTitle, int? travellers, String actor = 'Rahul', String trip = 'Uttarakhand Hills Trip', int count = 1}) => Notice(
      id: 'n',
      kind: kind,
      tripId: 't',
      tripTitle: trip,
      actorName: actor,
      amount: amount,
      refTitle: refTitle,
      travellers: travellers,
      refId: ref,
      count: count,
      isRead: false,
    );

void main() {
  useBuddyRenderScale();

  FakeGate granted() => FakeGate([CameraAccess.granted]);

  testWidgets('render s2_2a', (t) async {
    final file = await renderFrame(t, '2.2a', screenFor(granted(), []));
    expect(file.existsSync(), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('render s2_2b', (t) async {
    await renderFrame(t, '2.2b', screenFor(granted(), []), arrange: (t) async {
      await t.pump();
      await t.pump();
      scanRead('https://example.com');
      await t.pump();
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('render s2_2c', (t) async {
    await renderFrame(t, '2.2c', screenFor(granted(), []), arrange: (t) async {
      await t.pump();
      await t.pump();
      scanRead('Bakhli#11111111');
      await t.pump();
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('render s2_2d', (t) async {
    await renderFrame(t, '2.2d', screenFor(FakeGate([CameraAccess.denied], requests: [CameraAccess.denied]), []));
    expect(t.takeException(), isNull);
  });

  testWidgets('render s2_12', (t) async {
    final screen = _inbox([
      const DayLabel3D('Today'),
      _row(NoticeCopy.of(_stored(NoticeKinds.tripJoined, actor: 'Aman', travellers: 2))!, '5', 'min ago', read: false),
      _row(NoticeCopy.of(_stored(NoticeKinds.newBuddy, actor: 'Neha'))!, '2', 'h ago'),
      const DayLabel3D('Earlier'),
      _row(NoticeCopy.of(_stored(NoticeKinds.buddyAccepted, actor: 'Aman'))!, '3', 'days ago'),
    ]);
    await renderFrame(t, '2.12', screen);
    expect(t.takeException(), isNull);
  });

  testWidgets('render s3_5', (t) async {
    final invite = NoticeCopy.of(_stored(NoticeKinds.tripInvite, ref: 'm'))!;
    final screen = _inbox([
      const DayLabel3D('Today'),
      _row(invite, '2', 'min ago', read: false),
      const DayLabel3D('Earlier'),
      _row(NoticeCopy.of(_stored(NoticeKinds.buddyAccepted))!, '3', 'days ago'),
      _row(NoticeCopy.of(_stored(NoticeKinds.planUpdated, actor: 'Neha', trip: 'Goa Beach Weekend', amount: 2))!, '2', 'weeks ago'),
    ]);
    await renderFrame(t, '3.5', screen);
    expect(t.takeException(), isNull);
  });

  testWidgets('render s4_11', (t) async {
    final settle = NoticeCopy.of(_stored(NoticeKinds.settleReminder, amount: 11816))!;
    final screen = _inbox([
      const DayLabel3D('Today'),
      _row(settle, '1', 'h ago', read: false),
      const DayLabel3D('Earlier'),
      _row(NoticeCopy.of(_stored(NoticeKinds.expenseAdded, amount: 6400, refTitle: 'Taxi'))!, '4', 'days ago'),
      _row(NoticeCopy.of(_stored(NoticeKinds.shareChanged, amount: 6166, refTitle: 'Taxi, Suresh (Dzire)'))!, '4', 'days ago'),
    ]);
    await renderFrame(t, '4.11', screen);
    expect(t.takeException(), isNull);
  });
}
