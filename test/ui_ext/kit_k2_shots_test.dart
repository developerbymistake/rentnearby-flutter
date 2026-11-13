import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

final _configs = <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0)];

String _tag(double w, double s) => '${w.toInt()}_${s == 1.0 ? '10' : '13'}';

Future<void> _pump(WidgetTester t, Widget page, double w, double s, {double h = 800}) async {
  debugDisableShadows = false;
  await pumpPhone(t, page, size: Size(w, h), devicePixelRatio: 1.5, textScale: s);
  await settlePhone(t);
}

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

Widget _page(Color bg, List<Widget> kids) => Scaffold(
  backgroundColor: bg,
  body: ListView(padding: const EdgeInsets.fromLTRB(0, 36, 0, 40), children: kids),
);

Widget _backdrop(ListingTone tone, Widget over, {bool scrim = true}) => Scaffold(
  backgroundColor: const Color(0xFFF2F3F8),
  body: Stack(
    fit: StackFit.expand,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 150),
        child: WorkoutCard(tone: tone, art: ListingArt.luggage, eyebrow: 'Make it easy', title: 'Stay, taxi and ways', subtitle: 'We ask a few things', trailing: WorkoutTrailing.arrow, onTap: () {}),
      ),
      if (scrim) const Positioned.fill(child: ColoredBox(color: DesignColors.scrim)),
      Positioned.fill(child: over),
    ],
  ),
);

ReplyCard3D _reply({
  StatusTone3D status = StatusTone3D.waiting,
  String pill = 'Offer received',
  String title = 'Deodar Cottage',
  String line = 'Offered ₹7,200 · valid 23 h',
  bool urgent = false,
  String cap = 'Total',
  String number = '₹7,200',
  String unit = '2 nights',
  String? note = 'Closes in 23 h (14 Nov, 6:00 PM)',
  ReplyAction? primary,
  List<ReplyAction?> secondary = const [null, null],
  VoidCallback? onMenu,
  String art = ListingArt.hotel,
  List<ReplyRow> rows = const [ReplyRow('2 nights · ₹3,600 each', '₹7,200'), ReplyRow('Advance', '₹2,000'), ReplyRow('Balance at check-in', '₹5,200')],
}) => ReplyCard3D(
  status: status,
  art: art,
  pill: pill,
  title: title,
  urgent: urgent,
  statusLine: line,
  cap: cap,
  number: number,
  unit: unit,
  onMenu: onMenu,
  rows: rows,
  note: note,
  noteArt: ListingArt.calendar,
  primary: primary,
  secondary: secondary,
);

void main() {
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\kit_k2');

  for (final (w, s) in _configs) {
    final tag = _tag(w, s);

    testWidgets('toasts $tag', (t) async {
      await _pump(
        t,
        _page(const Color(0xFFF2F3F8), const [
          Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Toast3D(kind: ToastKind.success, message: 'Basic details saved')),
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Toast3D(kind: ToastKind.error, message: 'No internet connection')),
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Toast3D(kind: ToastKind.warning, message: 'This role is not available right now.')),
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Toast3D(kind: ToastKind.info, message: 'Session expired. Please log in again.')),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Toast3D(kind: ToastKind.error, message: 'The plate photo could not be uploaded because the connection dropped. Please check and try again in a minute.'),
          ),
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Toast3D(kind: ToastKind.success, message: 'Saved', compact: true)),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: NoDataToast3D(title: 'No stays here yet', subtitle: 'Try a nearby city, or check again soon.', accent: Color(0xFF2E7D32), art: ListingArt.hotel),
          ),
        ]),
        w,
        s,
      );
      await _snap(t, 'toasts_$tag');
    });

    testWidgets('states $tag', (t) async {
      await _pump(
        t,
        _page(const Color(0xFFF2F3F8), [
          StateCard3D(tone: ListingTone.indigo, art: ListingArt.luggage, title: 'No trips in progress', message: 'Plan your first trip', actionLabel: 'Plan a trip', onAction: () {}),
          StateCard3D(tone: ListingTone.indigo, art: ListingArt.worldMap, title: "Couldn't load trips", message: 'Check your connection and try again', actionLabel: 'Retry', onAction: () {}),
          StateCard3D(tone: ListingTone.forest, art: ListingArt.hotel, title: 'No stays listed yet', message: 'New stays are added often. Please check again soon.', reserveAction: true),
          StateCard.error(title: "Couldn't load taxis", message: 'Check your connection and try again', kit: KitTone.taxi, actionLabel: 'Retry', onAction: () {}),
          StateCard3D(tone: ListingTone.forest, art: ListingArt.hotel, title: 'No stay yet', message: 'List your stay in 4 steps', actionLabel: 'Set up your stay', onAction: () {}, layout: StateLayout.tall),
          StateCard3D(
            tone: ListingTone.indigo,
            art: ListingArt.star,
            title: 'Something went wrong',
            message: "Couldn't load notifications. Please try again.",
            actionLabel: 'Retry',
            onAction: () {},
            layout: StateLayout.tall,
            actionBelow: true,
          ),
          StateCard3D(tone: ListingTone.forest, art: ListingArt.worldMap, title: 'No city matches "Kasauli"', layout: StateLayout.plain),
          StateCard3D(tone: ListingTone.coral, art: ListingArt.taxi, title: "Couldn't load vehicle types", actionLabel: 'Retry', onAction: () {}, layout: StateLayout.plain),
        ]),
        w,
        s,
        h: 2700,
      );
      await _snap(t, 'states_$tag');
    });

    testWidgets('sheet list $tag', (t) async {
      final search = TextEditingController();
      addTearDown(search.dispose);
      await _pump(t, _backdrop(ListingTone.forest, SizedBox()), w, s);
      Sheet3D.show<void>(
        t.element(find.byType(Scaffold)),
        builder: (_) => Sheet3D(
          tone: ListingTone.forest,
          art: ListingArt.roundPushpin,
          title: 'Nainital',
          centerTitle: false,
          headerAction: 'Change district',
          onHeaderAction: () {},
          size: SheetSize.list,
          scrollable: false,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SheetSearchField(tone: ListingTone.forest, controller: search, hint: 'Search city', leadingArt: ListingArt.roundPushpin),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetListRow(tone: ListingTone.forest, title: 'Current', art: ListingArt.pushpin, selected: true, divider: false, onTap: () {}),
                    for (final c in ['Bhimtal', 'Bhowali', 'Haldwani'])
                      SheetListRow(tone: ListingTone.forest, title: c, art: ListingArt.roundPushpin, onTap: () {}),
                    SheetListRow(tone: ListingTone.forest, title: 'Mall Road Market', subtitle: 'Locality · Mussoorie, Uttarakhand', art: ListingArt.roundPushpin, onTap: () {}),
                    SheetListRow(tone: ListingTone.forest, title: 'Ramnagar', art: ListingArt.roundPushpin, enabled: false),
                    const SkeletonListRow(twoLines: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await _snap(t, 'sheet_list_$tag');
    });

    testWidgets('sheet confirm $tag', (t) async {
      var told = true;
      await _pump(t, _backdrop(ListingTone.forest, SizedBox()), w, s);
      Sheet3D.show<void>(
        t.element(find.byType(Scaffold)),
        builder: (_) => StatefulBuilder(
          builder: (context, set) => Sheet3D(
            tone: ListingTone.forest,
            art: ListingArt.key,
            title: 'Accept this offer?',
            size: SheetSize.confirm,
            footer: GradientPillButton(tone: ListingTone.forest, label: 'Accept offer', onTap: () {}),
            footnote: 'Payment is between you and the host. Bakhli does not take payment.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KeyValueRow(label: 'Stay', value: 'Deodar Cottage'),
                const KeyValueRow(label: 'Dates', value: '13-15 Nov · 2 nights'),
                const KeyValueRow(label: 'Total', value: '₹7,200', big: true),
                const KeyValueRow(label: 'Advance', value: '₹2,000'),
                const KeyValueRow(label: 'Balance at check-in', value: '₹5,200'),
                CheckRow(tone: ListingTone.forest, value: told, onChanged: (v) => set(() => told = v), label: 'Tell the other stays you booked'),
                SummaryBar3D(tone: ListingTone.forest, label: 'You pay at the stay', value: '₹5,200'),
              ],
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Tell the other stays you booked'));
      await t.pump();
      expect(told, isFalse);
      await t.tap(find.text('Tell the other stays you booked'));
      await t.pump();
      await _snap(t, 'sheet_confirm_$tag');
    });

    testWidgets('sheet frame $tag', (t) async {
      await _pump(t, _backdrop(ListingTone.indigo, SizedBox()), w, s);
      SheetFrame.show<void>(
        t.element(find.byType(Scaffold)),
        builder: (_) => SheetFrame(
          title: 'Add photo',
          subtitle: 'Pick where the photo comes from',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetOptionCard(tone: ListingTone.cB, art: ListingArt.camera, title: 'Take Photo', subtitle: 'Use the camera', onTap: () {}),
              SheetOptionCard(tone: ListingTone.cE, art: ListingArt.sunrise, title: 'Choose from Gallery', onTap: () {}),
              SheetOptionCard(tone: ListingTone.cA, art: ListingArt.pushpin, title: 'Remove photo', danger: true, onTap: () {}),
            ],
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await _snap(t, 'sheet_frame_$tag');
    });

    testWidgets('dialogs $tag', (t) async {
      var later = 0;
      await _pump(
        t,
        _backdrop(
          ListingTone.indigo,
          GateDialog(
            title: 'Update Available',
            body: 'Bakhli 1.0.1 is available with improvements and fixes.',
            asset: TravelIcon.airplane,
            horizontalActions: true,
            actions: [
              GateOutlineButton(label: 'Later', height: 48, onPressed: () => later++),
              GateButton(label: 'Update', height: 48, onPressed: () {}),
            ],
          ),
        ),
        w,
        s,
      );
      await t.tap(find.text('Later'));
      expect(later, 1);
      await _snap(t, 'dialog_soft_$tag');

      await _pump(
        t,
        _backdrop(
          ListingTone.forest,
          GateDialog(
            tone: ListingTone.forest,
            title: 'Not open here yet',
            body: "We can't take new listings in this area right now.",
            asset: TravelIcon.map,
            horizontalActions: true,
            actions: [
              GateTextButton(label: 'Change role', color: PickKit.bad, onPressed: () {}),
              GateButton(label: 'OK', height: 44, onPressed: () {}),
            ],
          ),
        ),
        w,
        s,
      );
      await _snap(t, 'dialog_onb_role_$tag');

      await _pump(
        t,
        _backdrop(
          ListingTone.forest,
          SetupDialog(title: 'Discard changes?', body: 'Unsaved changes will be lost.', cancelLabel: 'Keep Editing', confirmLabel: 'Discard', destructive: true, onCancel: () {}, onConfirm: () {}),
        ),
        w,
        s,
      );
      await _snap(t, 'dialog_discard_$tag');

      await _pump(
        t,
        _backdrop(
          ListingTone.indigo,
          Dialog3D(
            tone: ListingTone.indigo,
            art: ListingArt.worldMap,
            title: 'Remove Almora?',
            body: '1 booking and 1 enquiry are on these days. Cancel them now?',
            note: '1 host and 1 driver are told.',
            lines: const [DialogLine('Deodar Cottage · Confirmed by both sides', art: ListingArt.hotel), DialogLine('Rakesh Singh · Asked · waiting', art: ListingArt.taxi)],
            stacked: true,
            primaryDanger: true,
            primaryLabel: 'Cancel and remove',
            onPrimary: () {},
            secondaryLabel: 'Remove, keep bookings',
            onSecondary: () {},
            tertiaryLabel: 'Keep city',
            onTertiary: () {},
          ),
        ),
        w,
        s,
      );
      await _snap(t, 'dialog_leg_$tag');
    });

    testWidgets('gates $tag', (t) async {
      await _pump(
        t,
        GateStatusPage(
          asset: TravelIcon.map,
          title: 'No Internet',
          body: "Please check your internet connection. App will resume automatically when you're back online.",
          secondary: WhitePillButton(tone: ListingTone.indigo, label: 'Open my trips (offline copy)', onTap: () {}, height: 52),
        ),
        w,
        s,
      );
      await _snap(t, 'gate_offline_$tag');
      await _pump(
        t,
        GateStatusPage(
          asset: TravelIcon.place,
          title: 'Location Required',
          body: 'Bakhli uses your location to show stays and taxis near you. Please enable GPS to continue.',
          primary: GradientPillButton(tone: ListingTone.indigo, label: 'Enable Location', onTap: () {}, height: 52),
          secondary: WhitePillButton(tone: ListingTone.indigo, label: 'Check Again', onTap: () {}, height: 52),
        ),
        w,
        s,
      );
      await _snap(t, 'gate_gps_$tag');
    });

    testWidgets('pickers $tag', (t) async {
      final today = DateTime.now();
      final first = DateTime(today.year, today.month, today.day);
      await _pump(t, _backdrop(ListingTone.indigo, const SizedBox(), scrim: false), w, s);
      DateTime? picked;
      TemplateCalendarPopup.pickDate(t.element(find.byType(Scaffold)), initial: first.add(const Duration(days: 1)), first: first, label: 'Start date').then((v) => picked = v);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await settlePhone(t);
      await shot(t, 'cal_$tag');
      await t.tap(find.text('Apply'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(picked, first.add(const Duration(days: 1)));

      TimeOfDay? time;
      TemplateTimePopup.pick(t.element(find.byType(Scaffold)), initial: const TimeOfDay(hour: 9, minute: 30), label: 'Pickup time', art: ListingArt.taxi).then((v) => time = v);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await settlePhone(t);
      await shot(t, 'time_$tag');
      await t.tap(find.text('PM'));
      await t.pump(const Duration(milliseconds: 250));
      await t.tap(find.text('Apply'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(time, const TimeOfDay(hour: 21, minute: 30));
      final e = t.takeException();
      debugDisableShadows = true;
      expect(e, isNull);
    });

    testWidgets('busy $tag', (t) async {
      await _pump(
        t,
        Scaffold(
          backgroundColor: const Color(0xFFD8EEDA),
          body: Stack(children: const [SetupBusy(message: 'Saving your stay...')]),
        ),
        w,
        s,
      );
      await _snap(t, 'busy_saving_$tag');
      await _pump(
        t,
        Scaffold(
          backgroundColor: const Color(0xFFD8EEDA),
          body: Stack(children: const [SetupBusy(message: 'Uploading Photos', art: ListingArt.airplane, progress: 0.6, caption: '3 of 5 uploaded')]),
        ),
        w,
        s,
      );
      await _snap(t, 'busy_upload_$tag');
    });

    testWidgets('replies $tag', (t) async {
      var accepted = 0, menu = 0, call = 0;
      await _pump(
        t,
        _page(const Color(0xFFD8EEDA), [
          _reply(
            primary: ReplyAction(label: 'Accept offer · ₹7,200', onTap: () => accepted++),
            secondary: [ReplyAction(label: 'Call host', onTap: () => call++), ReplyAction(label: 'Propose a price', onTap: () {})],
            onMenu: () => menu++,
          ),
          _reply(
            pill: 'Asked · waiting',
            urgent: true,
            title: 'Lakeside Rooms and Cottages by the Naini Lake',
            line: 'Asked 2 h ago · no reply',
            cap: 'Listed',
            number: '₹3,000',
            unit: '/night',
            art: ListingArt.bed,
            rows: const [ReplyRow('Dates', '13-15 Nov · 2 nights'), ReplyRow('Guests', '2 adults')],
            note: null,
            primary: const ReplyAction(label: 'Waiting for the host'),
            secondary: [ReplyAction(label: 'Call host', onTap: () {}), null],
            onMenu: () {},
          ),
          _reply(
            status: StatusTone3D.both,
            pill: 'Confirmed by both sides',
            title: 'Deodar Cottage',
            line: 'Advance sent · host confirmed',
            rows: const [ReplyRow('Advance sent', '₹2,000', done: true), ReplyRow('Host confirmed', '12 Nov', done: true), ReplyRow('Balance at check-in', '₹5,200', done: false)],
            note: 'Check-in 13 Nov, 12:00 PM',
            primary: ReplyAction(label: 'Open chat', onTap: () {}, busy: true),
            secondary: [ReplyAction(label: 'Call host', onTap: () {}), ReplyAction(label: 'Directions', onTap: () {}, busy: true)],
          ),
          _reply(status: StatusTone3D.red, pill: 'Not available', line: 'The host is full on these dates', number: '₹3,000', unit: '/night', cap: 'Listed', note: null, rows: const []),
          const ReplyCardSkeleton(),
        ]),
        w,
        s,
        h: 2600,
      );
      await t.tap(find.text('Accept offer · ₹7,200'));
      await t.tap(find.text('Call host').first);
      await t.tap(find.byTooltip('More').first);
      expect([accepted, call, menu], [1, 1, 1]);
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'replies_$tag');
    });

    testWidgets('menu and legend $tag', (t) async {
      var picked = '';
      const names = ['shortlisted', 'asked', 'offered', 'fareSent', 'confirmedByYou', 'confirmedByBoth', 'bookedByYou', 'own', 'notAvailable', 'expired', 'declined', 'cancelled', 'notMe', 'holdExpired', 'closed', 'none'];
      await _pump(
        t,
        _page(const Color(0xFFF2F3F8), [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in names)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: StatusTone3D.of(n).tone.gradient, borderRadius: BorderRadius.circular(10)),
                    child: StatusPill3D(label: n, status: StatusTone3D.of(n)),
                  ),
                for (final n in ['asked', 'confirmedByBoth', 'declined']) StatusPill3D(label: n, status: StatusTone3D.of(n), onGradient: false, dot: true),
                const UrgentPill3D(),
                const TagPill3D(label: 'LIVE', color: Color(0xFF2E7D32)),
                const TagPill3D(label: 'NEW', filled: false),
                const TagPill3D(label: 'STAY', art: ListingArt.hotel, color: Color(0xFF17501B)),
              ],
            ),
          ),
          _reply(primary: ReplyAction(label: 'Accept offer', onTap: () {}), onMenu: () {}),
        ]),
        w,
        s,
      );
      showMenu3D(
        t.element(find.byType(Scaffold)),
        anchor: t.getRect(find.byTooltip('More')),
        items: [
          MenuItem3D(label: 'Decline', art: ListingArt.bed, danger: true, onTap: () => picked = 'decline'),
          MenuItem3D(label: 'Withdraw', art: ListingArt.clipboard, danger: true, onTap: () => picked = 'withdraw'),
          MenuItem3D(label: 'Report', art: ListingArt.roundPushpin, danger: true, onTap: () {}),
          MenuItem3D(label: 'Mark complete', icon: Icons.check_circle_rounded, positive: true, onTap: () {}),
        ],
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await settlePhone(t);
      await shot(t, 'menu_legend_$tag');
      await t.tap(find.text('Withdraw'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(picked, 'withdraw');
      expect(find.byType(MenuPopup3D), findsNothing);
      final e = t.takeException();
      debugDisableShadows = true;
      expect(e, isNull);
    });

    testWidgets('chat $tag', (t) async {
      var confirm = 0, ask = 0, answer = 0;
      final tone = ListingTone.forest;
      await _pump(
        t,
        Scaffold(
          backgroundColor: const Color(0xFFD8EEDA),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 40, 18, 30),
            children: [
              const ChatSystemNote('Today'),
              ChatBubble3D(tone: tone, text: 'What food is served?', mine: false),
              const SizedBox(height: 8),
              ChatBubble3D(tone: tone, text: 'Veg and non-veg', mine: true, ticks: ChatTicks.read),
              const SizedBox(height: 8),
              ChatBubble3D(tone: tone, text: 'Is parking available near the cottage for a large car, and how far is the walk from the road?', mine: true, ticks: ChatTicks.sent),
              const SizedBox(height: 8),
              ChatAnswerPill(tone: tone, label: 'Yes, free parking', onTap: () => answer++),
              const SizedBox(height: 8),
              ChatAnswerPill(tone: tone, label: 'No parking', onTap: () {}, negative: true),
              ChatCard3D(
                tone: tone,
                art: ListingArt.calendar,
                title: 'Visit requested',
                mine: false,
                subtitle: 'Select a time, then confirm',
                chips: [ChatChip('Sat 14, 11:00 AM', selected: true, selectable: true, onTap: () {}), ChatChip('Sat 14, 4:00 PM', selectable: true, onTap: () {}), const ChatChip('2 adults')],
                buttons: [
                  ChatCardButton(label: 'Confirm visit', onTap: () => confirm++),
                  ChatCardButton(label: 'Propose different time', onTap: () {}, kind: ChatButtonKind.secondary),
                  ChatCardButton(label: 'Decline', onTap: () {}, kind: ChatButtonKind.danger),
                ],
              ),
              ChatCard3D(tone: tone, art: ListingArt.calendar, title: 'Visit request sent', mine: true, subtitle: 'Sat 14, 11:00 AM', ticks: ChatTicks.delivered, dimmed: true),
              const SizedBox(height: 12),
              ChatAskSlot(tone: tone, label: 'Ask something', onTap: () => ask++),
              const SizedBox(height: 8),
              ChatAskSlot(tone: tone, label: 'Ask something', onTap: null, enabled: false),
            ],
          ),
        ),
        w,
        s,
        h: 1500,
      );
      await t.tap(find.text('Confirm visit'));
      await t.tap(find.text('Ask something').first);
      await t.tap(find.text('Yes, free parking'));
      expect([confirm, ask, answer], [1, 1, 1]);
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'chat_$tag');
    });

    testWidgets('timeline and rows $tag', (t) async {
      var banner = 0;
      final coral = ListingTone.coral;
      await _pump(
        t,
        _page(const Color(0xFFFFE3DA), [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Timeline3D(
              tone: coral,
              items: [
                const TimelineItem(title: 'Haldwani', subtitle: 'You start', dotColor: Color(0xFFFA7D82), state: TimelineState.done),
                TimelineItem(
                  title: '',
                  state: TimelineState.done,
                  child: SheetOptionCard(tone: ListingTone.cA, art: ListingArt.taxi, title: 'Haldwani to Bhowali', subtitle: 'about 32 km · Rakesh Singh', onTap: () {}),
                ),
                const TimelineItem(title: 'Bhowali', subtitle: 'Meet the next driver here · Bhowali taxi stand', dotColor: Color(0xFFF57C00), trailing: TagPill3D(label: 'change car', color: Color(0xFFF57C00))),
                const TimelineItem(title: 'Almora', subtitle: 'You arrive', dotColor: Color(0xFFFA7D82), faded: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Timeline3D(
              tone: ListingTone.indigo,
              dense: true,
              items: [
                TimelineItem(title: 'Advance sent', subtitle: '₹2,000 · 12 Nov', badge: '1', state: TimelineState.done),
                TimelineItem(title: 'Host confirms', subtitle: 'Waiting for the host', badge: '2', state: TimelineState.current),
                TimelineItem(title: 'Pay balance at check-in', badge: '3'),
                TimelineItem(title: 'Naina Devi Temple', subtitle: 'Temple · 45 min', art: ListingArt.mountain),
              ],
            ),
          ),
          RailStop3D(tone: coral, art: ListingArt.roundPushpin, title: 'Haldwani', subtitle: 'Start · 8:00 AM'),
          RailStop3D(tone: coral, art: ListingArt.taxi, title: 'Bhowali', tag: 'change car', subtitle: 'Bhowali taxi stand', connectorBelow: false),
          const DayLabel3D('Today'),
          const InfoFieldCard(
            fields: [
              InfoField(label: 'Message from reporter', value: 'The owner asked me to pay the full amount on UPI before the visit and would not show the room.'),
              InfoField(label: 'Status', child: Align(alignment: Alignment.centerLeft, child: StatusPill3D(label: 'Pending', color: Color(0xFFC26A00), onGradient: false, dot: true))),
              InfoField(label: 'Filed on', value: '12 Nov 2026'),
            ],
          ),
          Banner3D(kind: BannerKind.bad, art: ListingArt.clipboard, title: 'Stay rejected', subtitle: 'Photos are not clear. Add new photos and submit again.', actionLabel: 'Fix', onAction: () => banner++),
          const Banner3D(kind: BannerKind.warn, art: ListingArt.bell, title: 'Notifications are off', subtitle: 'Turn them on to get enquiries', actionLabel: 'Turn on'),
          const Banner3D(kind: BannerKind.good, art: ListingArt.star, title: 'Your stay is live'),
          Banner3D(kind: BannerKind.info, art: ListingArt.key, title: 'Under review', subtitle: 'We check new stays within a day.', tone: ListingTone.forest),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Column(
              children: [
                SummaryRow3D(tone: ListingTone.forest, art: ListingArt.hotel, title: 'Basic details', detail: 'Deodar Cottage · Kausani', actionLabel: 'Edit', onAction: () {}, divider: false),
                SummaryRow3D(tone: ListingTone.forest, art: ListingArt.bed, title: 'Rooms', detail: 'Add at least one room', detailBad: true, actionLabel: 'Add', onAction: () {}),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: ListingTone.forest.gradient, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                OnCardRow(title: 'Enquiries', subtitle: '2 new this week', art: ListingArt.speechBalloon, trailing: OnCardPill(label: 'Open', color: ListingTone.forest.button, onTap: () {}), onTap: () {}),
                const SizedBox(height: 8),
                const OnCardRow(title: 'Share my stay', trailing: OnCardPill(label: 'Share', enabled: false), enabled: false),
                const SizedBox(height: 8),
                OnCardRow(title: '1 report on this stay', art: ListingArt.pushpin, light: true, trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD93A55)), onTap: () {}),
              ],
            ),
          ),
          const PayLine3D('Pay each driver directly. Bakhli does not take payment.', art: ListingArt.moneyBag),
          const SkeletonSlimCard(),
          const SkeletonFormCard(),
          const Padding(padding: EdgeInsets.all(18), child: SkeletonBox(width: 160)),
        ]),
        w,
        s,
        h: 2900,
      );
      await t.tap(find.text('Fix'));
      expect(banner, 1);
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'rows_$tag');
    });
  }

  testWidgets('toast lane: dock wins, slot next, none under a dialog', (t) async {
    await pumpPhone(
      t,
      Scaffold(
        body: Column(children: const [SizedBox(height: 60), ToastSlot(), Expanded(child: SizedBox())]),
        bottomNavigationBar: const Padding(padding: EdgeInsets.all(16), child: ToastDock()),
      ),
    );
    expect(t.getSize(find.byType(ToastDock)).height, 0);
    expect(t.getSize(find.byType(ToastSlot)).height, 0);
    expect(ToastLane.showInHost(ToastKind.success, 'Saved'), isTrue);
    await t.pump();
    expect(find.descendant(of: find.byType(ToastDock), matching: find.text('Saved')), findsOneWidget);
    expect(find.descendant(of: find.byType(ToastSlot), matching: find.byType(Toast3D)), findsNothing);
    expect(ToastLane.showInHost(ToastKind.error, 'Failed'), isTrue);
    await t.pump();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Failed'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(find.byType(Toast3D), findsNothing);

    Dialog3D.show<void>(t.element(find.byType(Scaffold)), builder: (_) => Dialog3D(tone: ListingTone.indigo, title: 'Sure?', primaryLabel: 'OK', onPrimary: () {}));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(ToastLane.showInHost(ToastKind.info, 'Hidden'), isFalse);
    Navigator.of(t.element(find.byType(Dialog3D))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    await pumpPhone(t, Scaffold(body: Column(children: const [SizedBox(height: 60), ToastSlot(), Expanded(child: SizedBox())])));
    expect(ToastLane.showInHost(ToastKind.warning, 'In slot'), isTrue);
    await t.pump();
    expect(find.descendant(of: find.byType(ToastSlot), matching: find.text('In slot')), findsOneWidget);
    expect(t.getTopLeft(find.byType(Toast3D)).dy, greaterThanOrEqualTo(60));
    await t.pump(const Duration(seconds: 5));

    await pumpPhone(t, const Scaffold(body: SizedBox()));
    expect(ToastLane.showInHost(ToastKind.info, 'No host'), isFalse);
    expect(ToastLane.topOffset(t.element(find.byType(Scaffold))), phoneTopInset + 8);
  });
}
