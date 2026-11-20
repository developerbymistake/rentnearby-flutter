import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/money_name.dart';
import '../../shared/widgets/segment_tabs.dart';
import '../controllers/expense_sheet_controller.dart';
import '../expense_look.dart';
import '../expense_rules.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';

class SplitEditor extends StatelessWidget {
  const SplitEditor({super.key, required this.c});

  static Key rowKey(String userId) => ValueKey('split_row_$userId');
  static Key boxKey(String userId) => ValueKey('split_box_$userId');
  static const List<String> modes = [SplitMode.all, SplitMode.chosen, SplitMode.custom];

  final ExpenseSheetController c;

  @override
  Widget build(BuildContext context) => Obx(() {
        final mode = c.mode.value;
        c.amountDigits.value;
        c.chosen.length;
        c.customDigits.length;
        c.payer.value;
        c.lastCustom.value;
        c.people.length;
        final err = c.errorOf(ExpenseField.sharers);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentTabs(
              labels: const [ExpenseStrings.splitAll, ExpenseStrings.splitChosen, ExpenseStrings.splitCustom],
              selected: modes.indexOf(mode),
              onTap: (i) => c.pickMode(modes[i]),
              tone: BuddyLook.rose,
              margin: EdgeInsets.zero,
            ),
            if (mode == SplitMode.all) _allBox(),
            if (mode == SplitMode.chosen) ...[
              Gap.v(12),
              ..._chosenRows(),
              if (err != null) ExpenseLine(err) else ?_summary(),
            ],
            if (mode == SplitMode.custom) ...[
              Gap.v(12),
              ..._customRows(),
              _customLine(),
            ],
          ],
        );
      });

  String _name(MoneyPerson p) => c.isEdit ? BuddyFormat.moneyName(p) : p.name;

  Widget _nameText(MoneyPerson p, {bool you = true}) {
    final base = Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0);
    if (c.isEdit) return Text.rich(TextSpan(children: MoneyName.spans(p, base, showYou: you)), maxLines: 1, overflow: TextOverflow.ellipsis);
    return Text(p.isMe && you ? ExpenseStrings.you(p.name) : p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
  }

  Widget? _summary() {
    final e = c.equal;
    if (e == null) return null;
    final n = e.shares.length;
    final text = e.leftover == 0
        ? ExpenseStrings.each(e.each, n)
        : c.mode.value == SplitMode.chosen
            ? ExpenseStrings.sharedBy(n)
            : ExpenseStrings.leftover(e.leftover, c.person(e.leftoverUserId ?? '')?.name ?? '');
    return ExpenseLine(text, tone: FieldLineTone.rose);
  }

  Widget _allBox() {
    final people = c.currentPeople;
    final e = c.equal;
    final cells = [
      for (final p in people) _cell(p, c.shareOf(p.userId)),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 3) {
      final chunk = cells.sublist(i, i + 3 > cells.length ? cells.length : i + 3);
      rows.add(Padding(
        padding: DS.insets(t: i == 0 ? 0 : 8),
        child: Row(children: [
          for (var j = 0; j < 3; j++) ...[if (j > 0) Gap.h(8), Expanded(child: j < chunk.length ? chunk[j] : const SizedBox.shrink())],
        ]),
      ));
    }
    String? line;
    if (e != null) {
      line = e.leftover == 0 ? ExpenseStrings.each(e.each, e.shares.length) : ExpenseStrings.leftover(e.leftover, c.person(e.leftoverUserId ?? '')?.name ?? '');
    }
    return Container(
      margin: DS.insets(t: 10),
      padding: DS.sym(h: 12, v: 10),
      decoration: BoxDecoration(color: ExpenseLook.roseTint, borderRadius: ExpenseShape.corner(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          if (line != null)
            Padding(
              padding: DS.insets(t: 8),
              child: Text(line, style: Ink3D.text(12, FontWeight.w600, BuddyLook.roseEnd, letterSpacing: 0)),
            ),
        ],
      ),
    );
  }

  Widget _cell(MoneyPerson p, int share) => Container(
        padding: DS.sym(h: 8, v: 6),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: ExpenseShape.corner(16)),
        child: Row(
          children: [
            BuddyAvatar(initial: p.initial, seed: p.userId, size: BuddyAvatarSize.sm),
            Gap.h(8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, height: 1.2, letterSpacing: 0)),
                  Text(BuddyFormat.rupees(share), maxLines: 1, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0)),
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _chosenRows() {
    final rows = c.rows;
    final anyTicked = rows.any((r) => r.ticked);
    return [
      for (var i = 0; i < rows.length; i++) _chosenRow(rows[i], first: i == 0, anyTicked: anyTicked),
    ];
  }

  Widget _chosenRow(SplitRow r, {required bool first, required bool anyTicked}) {
    final p = r.person;
    Widget? sub;
    if (r.locked) {
      sub = Text(ExpenseStrings.leftCannotAdd, style: Ink3D.text(12, FontWeight.w600, ExpenseLook.leftText, letterSpacing: 0));
    } else if (r.ticked && r.former) {
      sub = Text(ExpenseStrings.leftTrip(r.share), style: Ink3D.text(12, FontWeight.w600, ExpenseLook.leftText, letterSpacing: 0));
    } else if (r.ticked) {
      sub = Text(BuddyFormat.rupees(r.share), style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0));
    } else if (anyTicked) {
      sub = Text(ExpenseStrings.notInThis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0));
    }
    final box = Container(
      width: DS.s(26),
      height: DS.s(26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: DS.circular(8),
        gradient: r.ticked ? BuddyLook.rose.gradient : null,
        color: r.locked ? ExpenseLook.offFill : null,
        border: r.ticked ? null : Border.all(color: r.locked ? ExpenseLook.offEdge : BuddyLook.checkOff, width: DS.s(2)),
      ),
      child: r.ticked ? Icon(Icons.check_rounded, size: DS.s(18), color: DesignColors.onPrimary) : null,
    );
    final dim = r.locked || (!r.ticked && anyTicked);
    final row = Container(
      constraints: BoxConstraints(minHeight: DS.s(50)),
      padding: DS.sym(v: 6),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
      child: Row(
        children: [
          BuddyAvatar(initial: p.initial, seed: p.userId, size: BuddyAvatarSize.sm),
          Gap.h(12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_nameText(p), ?sub])),
          Gap.h(12),
          box,
        ],
      ),
    );
    return Opacity(
      opacity: dim ? Alpha.v55 : Alpha.full,
      child: Tap3D(tapKey: rowKey(p.userId), onTap: r.locked ? null : () => c.toggle(p), toggled: r.ticked, label: _name(p), child: row),
    );
  }

  List<Widget> _customRows() {
    final people = [for (final p in c.listPeople) if (!c.lockedOut(p)) p];
    final check = c.custom;
    return [
      for (var i = 0; i < people.length; i++) _customRow(people[i], first: i == 0, difference: check.difference, amountOk: (c.amount ?? 0) > 0),
    ];
  }

  Widget _customRow(MoneyPerson p, {required bool first, required int difference, required bool amountOk}) {
    final digits = c.customDigits[p.userId] ?? '';
    final value = ExpenseRules.parse(digits);
    final focused = c.focus.value == ExpenseSheetController.customFocus(p.userId);
    final tone = difference == 0 && amountOk
        ? FieldTone.ok
        : c.lastCustom.value == p.userId
            ? FieldTone.bad
            : focused
                ? FieldTone.on
                : FieldTone.normal;
    final box = Tap3D(
      tapKey: boxKey(p.userId),
      onTap: () => c.tapCustom(p.userId),
      label: _name(p),
      exclude: true,
      child: Container(
        width: DS.s(118),
        constraints: BoxConstraints(minHeight: DS.s(44)),
        padding: DS.sym(h: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(borderRadius: ExpenseShape.corner(18), border: Border.all(color: ExpenseShape.border(tone), width: DS.s(2))),
        child: Text(ExpenseStrings.amountBox(value),
            style: Ink3D.text(15, FontWeight.w700, tone == FieldTone.bad ? BuddyLook.dangerText : (tone == FieldTone.ok ? ExpenseLook.okText : Ink3D.title), letterSpacing: 0)),
      ),
    );
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(50)),
      padding: DS.sym(v: 6),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
      child: Row(children: [
        BuddyAvatar(initial: p.initial, seed: p.userId, size: BuddyAvatarSize.sm),
        Gap.h(12),
        Expanded(child: _nameText(p)),
        Gap.h(12),
        box,
      ]),
    );
  }

  Widget _customLine() {
    final check = c.custom;
    if ((c.amount ?? 0) < 1) return const SizedBox.shrink();
    if (check.difference > 0) return ExpenseLine(ExpenseStrings.leftToAssign(check.difference));
    if (check.difference < 0) return ExpenseLine(ExpenseStrings.moreThanAmount(-check.difference));
    return const ExpenseLine(ExpenseStrings.allAssigned, tone: FieldLineTone.ok);
  }
}
