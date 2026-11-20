import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_avatar.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_badge.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_bottom_bar.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_confirm_box.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_page.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_sheet.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/features/buddy/shared/widgets/check_line.dart';
import 'package:bakhli/features/buddy/shared/widgets/menu_row.dart';
import 'package:bakhli/features/buddy/shared/widgets/money_hero.dart';
import 'package:bakhli/features/buddy/shared/widgets/money_name.dart';
import 'package:bakhli/features/buddy/shared/widgets/note_banner.dart';
import 'package:bakhli/features/buddy/shared/widgets/person_row.dart';
import 'package:bakhli/features/buddy/shared/widgets/section_label.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:bakhli/features/buddy/shared/widgets/small_pill.dart';
import 'package:bakhli/features/buddy/shared/widgets/view_only_chip.dart';
import 'package:bakhli/features/buddy/shared/widgets/who_pays_row_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/buddy_render.dart';
import '../../../support/five_sizes.dart';

const _neha = '44444444-4444-4444-8444-444444444444';
const _vikram = '55555555-5555-4555-8555-555555555555';
const _karan = '66666666-6666-4666-8666-666666666666';
const _aman = '22222222-2222-4222-8222-222222222222';
const _rahul = '11111111-1111-4111-8111-111111111111';

const _rahulMoney = MoneyPerson(userId: _rahul, name: 'Rahul', last4: '1736', initial: 'R', isMe: true, status: 'Owner');
const _amanMoney = MoneyPerson(userId: _aman, name: 'Aman', last4: '8275', initial: 'A', isMe: false, status: 'Left');

Widget _requestsPage({int tab = 1}) => BuddyPage(
      title: 'Buddies',
      subtitle: 'Friends you travel with',
      onBack: () {},
      trailing: const [ViewOnlyChip()],
      top: SegmentTabs(labels: const ['My buddies', 'Requests', 'Find'], selected: tab, onTap: (_) {}, tone: BuddyLook.teal, counts: const {1: 1}),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Received'),
          PersonListCard(children: [
            PersonRow(
              avatar: const BuddyAvatar(initial: 'N', seed: _neha),
              title: 'Neha',
              subtitle: 'Bakhli#73019462',
              trailing: Text('2 h ago', style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey)),
            ),
            Padding(
              padding: DS.insets(l: 16, r: 16, b: 14),
              child: Row(children: [
                Expanded(child: SmallPill(label: 'Decline', onTap: () {}, tall: true)),
                Gap.h(12),
                Expanded(child: SmallPill(label: 'Accept', onTap: () {}, kind: SmallPillKind.teal, tall: true)),
              ]),
            ),
          ]),
          const SectionLabel('Sent, waiting'),
          PersonListCard(children: [
            PersonRow(
              avatar: const BuddyAvatar(initial: 'V', seed: _vikram),
              title: 'Vikram',
              subtitle: 'Bakhli#29583047',
              line2: 'Expires in 14 days',
              trailing: SmallPill(label: 'Cancel', onTap: () {}, kind: SmallPillKind.dangerOutline),
            ),
            const PersonRow(
              avatar: BuddyAvatar(initial: 'K', seed: _karan),
              title: 'Karan',
              subtitle: 'Bakhli#35196843',
              line2: 'You can send again later',
              line2Tone: PersonLineTone.grey,
              trailing: BuddyBadge('Ended'),
            ),
          ]),
        ],
      ),
    );

Widget _moneyPage() => BuddyPage(
      title: 'Expenses',
      subtitle: 'Uttarakhand Hills Trip · Day 4',
      onBack: () {},
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MoneyHero(label: 'Spent so far', amount: '₹32,300', cells: [('₹11,618', 'Your share'), ('6', 'Expenses')]),
          const NoteBanner(art: BuddyArt.moneyBag, text: 'This trip is closed for changes.', tone: NoteTone.rose),
          const SectionLabel('Day 4 · 19 May', trailing: '₹2,400'),
          WhoPaysRowFrame(
            fromAvatar: const BuddyAvatar(initial: 'A', seed: _aman, size: BuddyAvatarSize.sm),
            toAvatar: const BuddyAvatar(initial: 'R', seed: _rahul, size: BuddyAvatarSize.sm),
            title: const MoneyName(person: _amanMoney),
            subtitle: const MoneyName(person: _rahulMoney),
            amount: '₹11,816',
            footerLeft: const BuddyBadge('Says paid', tone: BuddyBadgeTone.pending),
            footerRight: [SmallPill(label: 'Mark as received', onTap: () {}, kind: SmallPillKind.green)],
          ),
          Padding(
            padding: DS.sym(h: 18),
            child: Column(children: [
              MenuRow(art: BuddyArt.panda, title: 'Invite to a trip', subtitle: 'Pick one of your trips', onTap: () {}),
              MenuRow(art: BuddyArt.shield, title: 'Block', danger: true, onTap: () {}),
              CheckLine(leading: const BuddyAvatar(initial: 'R', seed: _rahul, size: BuddyAvatarSize.sm), title: 'Rahul', checked: true, onTap: () {}),
              CheckLine(title: 'Aman', checked: false, enabled: false, trailingBadge: const BuddyBadge('Viewer', tone: BuddyBadgeTone.view)),
            ]),
          ),
          Center(
            child: BuddyAvatarStack(people: const [(initial: 'R', seed: _rahul), (initial: 'A', seed: _aman), (initial: 'P', seed: 'p')], extra: 2),
          ),
        ],
      ),
      bottomBar: BuddyBottomBar(line: 'This trip is full', children: [
        GradientPillButton(tone: BuddyLook.rose, label: '+ Add expense', onTap: () {}),
      ]),
    );

void main() {
  group('shared widgets', () {
    useBuddyRenderScale();

    testWidgets('requests look renders without errors and writes the render file', (tester) async {
      final file = await renderFrame(tester, 'f.requests', _requestsPage());
      expect(tester.takeException(), isNull);
      expect(file.existsSync(), isTrue);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('money look renders', (tester) async {
      final file = await renderFrame(tester, 'f.money', _moneyPage());
      expect(tester.takeException(), isNull);
      expect(file.existsSync(), isTrue);
      expect(find.text('₹32,300'), findsOneWidget);
      expect(find.text('This trip is full'), findsOneWidget);
    });

    testWidgets('confirm box returns true only on the confirm tap', (tester) async {
      bool? answer;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answer = await BuddyConfirmBox.ask(
                context,
                art: BuddyArt.shield,
                title: 'Block Vikas?',
                body: 'They cannot find you or send you requests.',
                dangerNote: 'This cannot be undone.',
                confirmLabel: 'Block',
                confirmKind: ConfirmKind.danger,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Block Vikas?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });

    testWidgets('sheet shell shows title and content, snack shows and hides', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(children: [
              TextButton(
                onPressed: () => BuddySheet.show<void>(context, art: BuddyArt.panda, title: 'Invite to a trip', subtitle: 'Pick a trip', builder: (_) => const Text('rows')),
                child: const Text('sheet'),
              ),
              TextButton(onPressed: () => BuddySnack.show(context, 'Neha is now your buddy', actionLabel: 'Open', onAction: () {}), child: const Text('snack')),
            ]),
          ),
        ),
      ));
      await tester.tap(find.text('snack'));
      await tester.pump();
      expect(find.text('Neha is now your buddy'), findsOneWidget);
      await tester.pump(BuddySnack.duration);
      expect(find.text('Neha is now your buddy'), findsNothing);
      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Invite to a trip'), findsOneWidget);
      expect(find.text('rows'), findsOneWidget);
    });

    testWidgets('money name shows last 4, you and left', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Column(children: [MoneyName(person: _rahulMoney), MoneyName(person: _amanMoney)])));
      expect(find.text('Rahul 1736 (you)', findRichText: true), findsOneWidget);
      expect(find.text('Aman 8275 (left)', findRichText: true), findsOneWidget);
    });
  });

  group('five sizes', () {
    useBuddyRenderScale();
    testFiveSizes('requests look', () => _requestsPage());
    testFiveSizes('money look', () => _moneyPage());
  });

  test('render files land in the render folder with the frame names', () {
    expect(frameFile('2.9'), 's2_9');
    expect(frameFile('4.13a'), 's4_13a');
    expect(Directory(buddyRenderDir).parent.existsSync(), isTrue);
  });
}
