import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/buddy_error_types.dart';
import 'package:bakhli/features/buddy/ledger/ledger_deps.dart';
import 'package:bakhli/features/buddy/ledger/screens/money_summary_screen.dart';
import 'package:bakhli/features/buddy/ledger/screens/settle_up_screen.dart';
import 'package:bakhli/features/buddy/ledger/widgets/balances_view.dart';
import 'package:bakhli/features/buddy/ledger/widgets/booking_expense_line.dart';
import 'package:bakhli/features/buddy/ledger/widgets/day_spent_chip.dart';
import 'package:bakhli/features/buddy/ledger/widgets/expense_state_banner.dart';
import 'package:bakhli/features/buddy/ledger/widgets/viewer_money_card.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_badge.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_bottom_bar.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_page.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/features/buddy/shared/widgets/section_label.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/buddy/shared/widgets/view_only_chip.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'ledger_fixtures.dart';

const _dir = 'assets/images/design/travel3d/';

typedef _Ex = (String art, String title, String sub, int amount, int share, bool edited);
typedef _Day = (String head, int total, List<_Ex> rows);

const _d4 = ('DAY 4 · 19 MAY', 2400, [('canoe', 'Rafting in Rishikesh', 'Paid by Rahul · Shared by 2', 2400, 1200, false)]);
const _d3 = ('DAY 3 · 18 MAY', 20000, [
  ('taxi', 'Taxi, Suresh (Dzire), full trip', 'Paid by Rahul · Shared by 3', 18500, 6166, false),
  ('pot_of_food', 'Dinner by the Ganga', 'Paid by Priya · Shared by 3', 1500, 500, false),
]);
const _d2 = ('DAY 2 · 17 MAY', 900, [('camera', 'Naini Lake boating', 'Paid by Rahul · Shared by 2', 900, 450, false)]);
const _d1 = ('DAY 1 · 16 MAY', 9000, [
  ('hotel', 'Snow View Hotel, 3 nights', 'Paid by Rahul · Shared by 2', 8000, 4000, false),
  ('pot_of_food', 'Lunch at Mall Road', 'Paid by you · Shared by 2', 1000, 500, false),
]);
const List<_Day> _all = [_d4, _d3, _d2, _d1];

class _DayList extends StatelessWidget {
  const _DayList(this.days);

  final List<_Day> days;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in days) ...[
            SectionLabel(d.$1, trailing: '₹${_g(d.$2)}', padding: DS.insets(l: 22, t: 16, r: 22, b: 8)),
            Container(
              margin: DS.sym(h: 18),
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))), boxShadow: BuddyLook.cardShadows(DS.size)),
              child: Column(children: [for (final r in d.$3) _row(r)]),
            ),
          ],
        ],
      );

  Widget _row(_Ex r) => Padding(
        padding: DS.sym(h: 14, v: 12),
        child: Row(
          children: [
            Container(
              width: DS.s(40),
              height: DS.s(40),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: DS.circular(12)),
              child: Center(child: Art3D(asset: '$_dir${r.$1}.png', size: 32, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
            ),
            Gap.h(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                Text(r.$3, maxLines: 1, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                if (r.$6) const BuddyBadge('Edited'),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${_g(r.$4)}', style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Text('Your share ₹${_g(r.$5)}', style: Ink3D.text(11.5, FontWeight.w600, BuddyLook.roseEnd, letterSpacing: 0)),
            ]),
          ],
        ),
      );

  static String _g(int v) {
    final s = '$v';
    return s.length <= 3 ? s : '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
}

Widget _shell({required String subtitle, required bool owner, required int tab, List<_Day> days = const [], bool addBar = true}) => BuddyPage(
      title: 'Expenses',
      subtitle: subtitle,
      trailing: owner ? [TripMenuDots.box()] : const [ViewOnlyChip()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExpenseStateBanner(tripId: tripId),
          if (!owner) const ViewerMoneyCard(tripId: tripId),
          SegmentTabs(labels: const ['By day', 'Balances'], selected: tab, onTap: (_) {}, tone: BuddyLook.rose),
          if (tab == 1) const BalancesView(tripId: tripId) else _DayList(days),
        ],
      ),
      bottomBar: owner && addBar ? BuddyBottomBar(children: [GradientPillButton(tone: BuddyLook.rose, label: '+ Add expense', onTap: () {})]) : null,
    );

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f.first);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _render(WidgetTester t, String id, Widget screen, {Future<void> Function(WidgetTester)? arrange}) async {
  final f = await renderFrame(t, id, screen, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(f.existsSync(), isTrue);
  BuddySnack.hide();
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

const _day4 = 'Uttarakhand Hills Trip · Day 4';
const _byRahul = 'Uttarakhand Hills Trip · by Rahul';

void main() {
  useBuddyRenderScale();
  tearDown(() {
    LedgerDeps.debugReset();
    Get.reset();
  });

  testWidgets('4.9 balances', (t) async {
    registerLedger([BuddyOk(owner49())]);
    await _render(t, '4.9', _shell(subtitle: _day4, owner: true, tab: 1));
  });

  testWidgets('4.9a confirm received', (t) async {
    registerLedger([BuddyOk(owner49())]);
    await _render(t, '4.9a', _shell(subtitle: _day4, owner: true, tab: 1), arrange: (t) => _tap(t, find.text('Mark as received')));
  });

  testWidgets('4.9b payment changed', (t) async {
    final api = registerLedger([BuddyOk(owner49())]);
    api.writeResult = refused(BuddyErrorTypes.paymentStateChanged);
    await _render(t, '4.9b', _shell(subtitle: _day4, owner: true, tab: 1), arrange: (t) async {
      api.answer(BuddyOk(owner49b()));
      await _tap(t, find.text('Mark as received'));
      await _tap(t, find.text('Yes, received'));
    });
  });

  testWidgets('4.9c two Amans', (t) async {
    registerLedger([BuddyOk(owner49(twoAmans: true))]);
    await _render(t, '4.9c', _shell(subtitle: _day4, owner: true, tab: 1));
  });

  testWidgets('4.9d not received box', (t) async {
    registerLedger([BuddyOk(owner49(twoAmans: true))]);
    await _render(t, '4.9d', _shell(subtitle: _day4, owner: true, tab: 1), arrange: (t) => _tap(t, find.text('Not received')));
  });

  testWidgets('4.9e owner owes a viewer', (t) async {
    registerLedger([BuddyOk(owner49e())]);
    await _render(t, '4.9e', _shell(subtitle: 'Uttarakhand Hills Trip · Day 2', owner: true, tab: 1));
  });

  testWidgets('4.9f received by Priya', (t) async {
    registerLedger([BuddyOk(owner49e())]);
    await _render(t, '4.9f', _shell(subtitle: 'Uttarakhand Hills Trip · Day 2', owner: true, tab: 1), arrange: (t) => _tap(t, find.text('Mark as received')));
  });

  testWidgets('4.10 viewer', (t) async {
    registerLedger([BuddyOk(viewer410())]);
    await _render(t, '4.10', _shell(subtitle: _byRahul, owner: false, tab: 0, days: _all));
  });

  testWidgets('4.10a confirm paid', (t) async {
    registerLedger([BuddyOk(viewer410())]);
    await _render(t, '4.10a', _shell(subtitle: _byRahul, owner: false, tab: 0, days: _all), arrange: (t) => _tap(t, find.byKey(ViewerMoneyCard.paidKey)));
  });

  testWidgets('4.10b amount changed', (t) async {
    final api = registerLedger([BuddyOk(viewer410())]);
    api.writeResult = refused(BuddyErrorTypes.balancesChanged);
    const days = [
      _d3,
      ('DAY 2 · 17 MAY', 500, [('camera', 'Naini Lake boating', 'Paid by Rahul · Shared by 2', 500, 250, true)]),
    ];
    await _render(t, '4.10b', _shell(subtitle: _byRahul, owner: false, tab: 0, days: days), arrange: (t) async {
      api.answer(BuddyOk(viewer410(amount: 11616, share: 12616)));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
    });
  });

  testWidgets('4.10c nothing left', (t) async {
    final api = registerLedger([BuddyOk(viewer410())]);
    api.writeResult = refused(BuddyErrorTypes.nothingToPay);
    const days = [
      ('DAY 2 · 17 MAY', 1000, [('camera', 'Naini Lake boating', 'Paid by Rahul · Shared by 2', 1000, 500, false)]),
      ('DAY 1 · 16 MAY', 1000, [('pot_of_food', 'Lunch at Mall Road', 'Paid by you · Shared by 2', 1000, 500, false)]),
    ];
    await _render(t, '4.10c', _shell(subtitle: _byRahul, owner: false, tab: 0, days: days), arrange: (t) async {
      api.answer(BuddyOk(viewer410c()));
      await _tap(t, find.byKey(ViewerMoneyCard.paidKey));
      await _tap(t, find.text('Yes, I paid'));
    });
  });

  testWidgets('4.10e owed viewer', (t) async {
    registerLedger([BuddyOk(viewer410e())]);
    await _render(t, '4.10e', _shell(subtitle: _byRahul, owner: false, tab: 1));
  });

  testWidgets('4.12 after paying', (t) async {
    registerLedger([BuddyOk(viewer410(state: 'SaidPaid'))]);
    await _render(t, '4.12', _shell(subtitle: _byRahul, owner: false, tab: 0, days: const [_d4, _d3, _d2]));
  });

  testWidgets('4.12a waiting with Not paid', (t) async {
    registerLedger([BuddyOk(viewer410(state: 'SaidPaid'))]);
    await _render(t, '4.12a', _shell(subtitle: _byRahul, owner: false, tab: 0, days: const [_d3, _d2]));
  });

  testWidgets('4.12b not paid box', (t) async {
    registerLedger([BuddyOk(viewer410(state: 'SaidPaid'))]);
    await _render(t, '4.12b', _shell(subtitle: _byRahul, owner: false, tab: 0, days: const [_d3, _d2]),
        arrange: (t) => _tap(t, find.byKey(ViewerMoneyCard.notPaidKey)));
  });

  testWidgets('4.12c not got it', (t) async {
    registerLedger([BuddyOk(viewer410(afterNotReceived: '2026-05-20T07:00:00Z'))]);
    await _render(t, '4.12c', _shell(subtitle: _byRahul, owner: false, tab: 0, days: const [_d3, _d2]));
  });

  testWidgets('4.14 settle up', (t) async {
    final api = registerLedger([BuddyOk(owner414(received: false))]);
    await _render(t, '4.14', const SettleUpScreen(tripId: tripId), arrange: (t) async {
      api.answer(BuddyOk(owner414()));
      await _tap(t, find.text('Mark as received'));
      await _tap(t, find.text('Yes, received'));
    });
  });

  testWidgets('4.15 trip summary', (t) async {
    registerLedger([BuddyOk(owner414())]);
    await _render(t, '4.15', const MoneySummaryScreen(tripId: tripId));
  });

  testWidgets('4.15a reopened', (t) async {
    registerLedger([BuddyOk(owner415a())]);
    await _render(t, '4.15a', const SettleUpScreen(tripId: tripId));
  });

  testWidgets('4.15b closed for changes', (t) async {
    registerLedger([BuddyOk(owner415b())]);
    await _render(t, '4.15b', _shell(subtitle: 'Uttarakhand Hills Trip · ended 22 May', owner: true, tab: 1, addBar: false));
  });

  testWidgets('4.16 links to the trip', (t) async {
    registerLedger([BuddyOk(owner49())]);
    await _render(t, '4.16', const _LinksHarness());
  });
}

class _LinksHarness extends StatelessWidget {
  const _LinksHarness();

  @override
  Widget build(BuildContext context) => BuddyPage(
        title: 'Uttarakhand Hills Trip',
        subtitle: '7 days · 16 – 22 May · 3 travellers',
        trailing: [
          Container(
            height: DS.s(36),
            padding: DS.sym(h: 14),
            decoration: BoxDecoration(color: DesignColors.surface.withValues(alpha: Alpha.v25), borderRadius: DS.circular(18)),
            child: Center(widthFactor: 1, child: Text('Map', style: Ink3D.text(13, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0))),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _day(3, 'Day 3 · Mon 18 May', 'Nainital to Rishikesh', const Color(0xFFFFC371), stop: true),
            _day(4, 'Day 4 · Tue 19 May', 'Rishikesh', const Color(0xFF66BB6A)),
            _booking('taxi', 'Taxi · Suresh, Dzire', 'Full trip · from Day 1', 'Taxi', 'd0000000-0000-4000-8000-000000000002'),
            _booking('hotel', 'Snow View Hotel', 'Nainital · 3 nights · Day 1', 'Stay', 'd0000000-0000-4000-8000-000000000001'),
          ],
        ),
      );

  Widget _day(int day, String title, String line, Color dot, {bool stop = false}) => Padding(
        padding: DS.insets(l: 18, t: 40, r: 18),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(kMealsRadius), boxShadow: BuddyLook.cardShadows(DS.size)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: DS.insets(l: 88, t: 14, r: 14, b: 14),
                    decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        SizedBox(height: DS.s(40)),
                        Container(width: DS.s(14), height: DS.s(14), decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: DesignColors.surface, width: DS.s(2.5)))),
                        Gap.h(8),
                        Text(title, style: Ink3D.text(17, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
                      ]),
                      Gap.v(2),
                      Wrap(spacing: DS.gh(10), crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(line, style: Ink3D.text(13, FontWeight.w600, DesignColors.surface, letterSpacing: 0)),
                        DaySpentChip(tripId: tripId, day: day),
                      ]),
                    ]),
                  ),
                  if (stop)
                    Padding(
                      padding: DS.sym(h: 12, v: 10),
                      child: Row(children: [
                        Text('5:00 pm', style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
                        Gap.h(10),
                        Container(width: DS.s(22), height: DS.s(22), decoration: BoxDecoration(color: dot, shape: BoxShape.circle), child: Center(child: Text('1', style: Ink3D.text(12, FontWeight.w700, DesignColors.surface, letterSpacing: 0)))),
                        Gap.h(10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Ram Jhula', style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                            Text('Bridge · 45 m', style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                          ]),
                        ),
                        const Art3D(asset: '${_dir}bridge_at_night.png', size: 28, shadowBlur: 2, shadowOffset: Offset(1, 2)),
                      ]),
                    ),
                ],
              ),
            ),
            Positioned(left: DS.s(10), top: -DS.s(13), child: const Art3D(asset: '${_dir}calendar.png', size: 63)),
          ],
        ),
      );

  Widget _booking(String art, String title, String sub, String kind, String id) => Container(
        margin: DS.insets(l: 18, t: 14, r: 18),
        padding: DS.sym(h: 16, v: 14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))), boxShadow: BuddyLook.cardShadows(DS.size)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Art3D(asset: '$_dir$art.png', size: 46, shadowBlur: 3, shadowOffset: const Offset(2, 4)),
            Gap.h(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text(sub, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.copy, letterSpacing: 0)),
              ]),
            ),
            const BuddyBadge('Booked', tone: BuddyBadgeTone.ok),
          ]),
          BookingExpenseLine(tripId: tripId, kind: kind, id: id),
        ]),
      );
}
