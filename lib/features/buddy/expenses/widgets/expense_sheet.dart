import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../buddy_limits.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../../shared/widgets/check_line.dart';
import '../../shared/widgets/money_name.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/expense_sheet_controller.dart';
import '../data/expense_write_gateway.dart';
import '../data/expenses_api.dart';
import '../expense_look.dart';
import '../expense_rules.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'amount_pad.dart';
import 'expense_form_parts.dart';
import 'payments_made_dialog.dart';
import 'split_editor.dart';

class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({super.key, required this.setup, this.api, this.gateway});

  static const Key closeKey = ValueKey('expense_sheet_close');
  static const Key amountKey = ValueKey('expense_sheet_amount');
  static const Key titleKey = ValueKey('expense_sheet_title');
  static const Key noteKey = ValueKey('expense_sheet_note');
  static const Key payerKey = ValueKey('expense_sheet_payer');
  static const Key saveKey = ValueKey('expense_sheet_save');
  static const Key refreshKey = ValueKey('expense_sheet_refresh');
  static Key categoryKey(String c) => ValueKey('expense_cat_$c');
  static Key dayKey(int d) => ValueKey('expense_day_$d');
  static Key linkKey(String id) => ValueKey('expense_link_$id');

  final ExpenseSheetSetup setup;
  final ExpensesApi? api;
  final ExpenseWriteGateway? gateway;

  @visibleForTesting
  static ExpenseSheetController? debugLast;

  static Future<SheetSaveEnd?> show(BuildContext context, ExpenseSheetSetup setup, {ExpensesApi? api, ExpenseWriteGateway? gateway}) =>
      showModalBottomSheet<SheetSaveEnd>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        barrierColor: DesignColors.scrim,
        builder: (_) => ExpenseSheet(setup: setup, api: api, gateway: gateway),
      );

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  late final String _tag = 'expense_sheet_${identityHashCode(this)}';
  late final ExpenseSheetController c;
  final GlobalKey _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    c = Get.put(ExpenseSheetController(widget.setup, api: widget.api, gateway: widget.gateway), tag: _tag);
    ExpenseSheet.debugLast = c;
    _scroll();
    _workers = [ever(c.link, (_) => _scroll()), ever(c.padOpen, (_) => _scroll()), ever(c.typed, (_) => _scroll())];
  }

  late final List<Worker> _workers;

  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) => _showSelected());

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    Get.delete<ExpenseSheetController>(tag: _tag);
    super.dispose();
  }

  void _showSelected() {
    final ctx = _selectedChip.currentContext;
    if (ctx == null || !mounted) return;
    final ro = ctx.findRenderObject();
    if (ro != null) Scrollable.maybeOf(ctx)?.position.ensureVisible(ro);
  }

  Future<void> _close() async {
    if (!c.isEdit && c.hasTyped) {
      final discard = await BuddyConfirmBox.ask(
        context,
        art: ExpenseLook.warning,
        title: ExpenseStrings.discardTitle,
        cancelLabel: ExpenseStrings.discardKeep,
        confirmLabel: ExpenseStrings.discard,
        confirmKind: ConfirmKind.danger,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save({bool ack = false}) async {
    final end = await c.save(ack: ack);
    if (!mounted) return;
    switch (end) {
      case SheetSaveEnd.none:
        return;
      case SheetSaveEnd.needsAck:
        final ok = await PaymentsMadeDialog.ask(context, c.ackNames);
        if (ok && mounted) await _save(ack: true);
      default:
        Navigator.of(context).pop(end);
    }
  }

  Future<void> _pickPayer() async {
    c.blurPad();
    final people = [for (final p in c.people) if ((!p.isFormer && !p.isDeleted) || p.userId == c.payer.value) p];
    final picked = await BuddySheet.show<String>(
      context,
      title: ExpenseStrings.choosePayer,
      tone: BuddyLook.rose,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in people)
            CheckLine(
              key: ValueKey('payer_${p.userId}'),
              leading: BuddyAvatar(initial: p.initial, seed: p.userId, size: BuddyAvatarSize.sm),
              title: p.name,
              titleWidget: MoneyName(person: p, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              checked: p.userId == c.payer.value,
              round: true,
              onTap: () => Navigator.of(ctx).pop(p.userId),
            ),
        ],
      ),
    );
    if (picked != null) c.pickPayer(picked);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = mq.size.height - mq.padding.top - DS.s(56);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: height - mq.viewInsets.bottom > DS.s(200) ? height - mq.viewInsets.bottom : height,
        child: Material(
          color: DesignColors.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
          child: Obx(() {
            final padUp = c.padOpen.value;
            final amountPad = padUp && c.focus.value == ExpenseSheetController.amountFocus;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: padUp ? c.blurPad : null,
                    child: SingleChildScrollView(
                      padding: DS.insets(l: 20, r: 20, b: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _body(hideLower: amountPad)),
                    ),
                  ),
                ),
                _bar(withInset: !padUp),
                if (padUp) AmountPad(onKey: c.key),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: DS.insets(l: 20, t: 18, r: 12, b: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(c.isEdit ? ExpenseStrings.editTitle : ExpenseStrings.addTitle,
                        style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0)),
                  ),
                  Obx(() => Text(c.subtitle, style: Ink3D.text(12.5, FontWeight.w400, ExpenseLook.copy, height: 1.5, letterSpacing: 0))),
                ],
              ),
            ),
            Tap3D(
              tapKey: ExpenseSheet.closeKey,
              onTap: _close,
              label: ExpenseStrings.close,
              exclude: true,
              child: SizedBox(
                width: DS.s(44),
                height: DS.s(44),
                child: Center(
                  child: Container(
                    width: DS.s(30),
                    height: DS.s(30),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: BuddyLook.closeBg, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: DS.s(18), color: BuddyLook.closeX),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  List<Widget> _body({required bool hideLower}) {
    final amountErr = c.errorOf(ExpenseField.amount);
    final titleErr = c.errorOf(ExpenseField.title);
    final catErr = c.errorOf(ExpenseField.category);
    final focus = c.focus.value;
    final top = c.topError.value;
    final typed = c.typed.value;
    return [
      if (c.conflict.value)
        ExpenseStrip(
          action: SmallPill(key: ExpenseSheet.refreshKey, label: ExpenseStrings.refresh, onTap: c.refreshAfterConflict, kind: SmallPillKind.rose, busy: c.refreshing.value),
          child: Text(ExpenseStrings.conflict, style: Ink3D.text(13, FontWeight.w700, BuddyLook.dangerText, height: 1.35, letterSpacing: 0)),
        ),
      if (typed != null)
        ExpenseStrip(
          amber: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ExpenseStrings.youTyped, style: Ink3D.text(12, FontWeight.w700, ExpenseLook.amberText, letterSpacing: 0.3)),
              Text(typed, style: Ink3D.text(13, FontWeight.w600, ExpenseLook.amberText, height: 1.4, letterSpacing: 0)),
            ],
          ),
        ),
      if (top != null) ExpenseStrip(child: Text(top, style: Ink3D.text(13, FontWeight.w700, BuddyLook.dangerText, height: 1.35, letterSpacing: 0))),
      const ExpenseFieldLabel(ExpenseStrings.amount, hint: ExpenseStrings.wholeRupees),
      ExpenseFieldBox(
        tapKey: ExpenseSheet.amountKey,
        tall: true,
        label: ExpenseStrings.amount,
        tone: amountErr != null ? FieldTone.bad : (focus == ExpenseSheetController.amountFocus ? FieldTone.on : FieldTone.normal),
        onTap: c.tapAmount,
        child: Text(ExpenseStrings.amountBox(c.amount), style: Ink3D.text(24, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
      ),
      if (amountErr != null) ExpenseLine(amountErr),
      const ExpenseFieldLabel(ExpenseStrings.whatFor),
      ExpenseFieldBox(
        tone: titleErr != null ? FieldTone.bad : FieldTone.normal,
        child: TextField(
          key: ExpenseSheet.titleKey,
          controller: c.titleCtl,
          onChanged: c.onTitle,
          onTap: c.titleFocused,
          maxLength: BuddyLimits.titleMax,
          inputFormatters: noEmojiInputFormatters,
          textCapitalization: TextCapitalization.sentences,
          style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0),
          decoration: _input(ExpenseStrings.titleHint),
        ),
      ),
      if (titleErr != null) ExpenseLine(titleErr),
      const ExpenseFieldLabel(ExpenseStrings.category),
      _categories(),
      if (catErr != null) ExpenseLine(catErr),
      if (!hideLower) ...[
        const ExpenseFieldLabel(ExpenseStrings.linkedTo),
        _links(),
        const ExpenseFieldLabel(ExpenseStrings.paidByLabel),
        _payer(),
        const ExpenseFieldLabel(ExpenseStrings.splitAmong),
        SplitEditor(c: c),
        Gap.v(12),
        ExpenseFieldBox(
          child: TextField(
            key: ExpenseSheet.noteKey,
            controller: c.noteCtl,
            onTap: c.titleFocused,
            maxLength: BuddyLimits.noteMax,
            inputFormatters: noEmojiInputFormatters,
            textCapitalization: TextCapitalization.sentences,
            style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0),
            decoration: _input(ExpenseStrings.note),
          ),
        ),
      ],
    ];
  }

  InputDecoration _input(String hint) => InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        counterText: '',
        contentPadding: DS.sym(v: 10),
        hintText: hint,
        hintStyle: Ink3D.text(15, FontWeight.w400, ExpenseLook.placeholder, letterSpacing: 0),
      );

  Widget _categories() {
    final cats = ExpenseCategory.all;
    Widget chip(String cat) {
      final on = c.category.value == cat;
      return Tap3D(
        tapKey: ExpenseSheet.categoryKey(cat),
        onTap: () => c.pickCategory(cat),
        selected: on,
        label: cat,
        exclude: true,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(38)),
          padding: DS.sym(h: 10),
          decoration: BoxDecoration(
            color: on ? null : DesignColors.surface,
            gradient: on ? BuddyLook.rose.gradient : null,
            borderRadius: ExpenseShape.corner(20),
            boxShadow: [
              on
                  ? BoxShadow(color: BuddyLook.roseGlow.withValues(alpha: Alpha.v40), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))
                  : BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.tint), offset: DS.shadowOffset(const Offset(0, 2)), blurRadius: DS.shadowBlur(6)),
            ],
          ),
          child: Row(
            children: [
              Image.asset(ExpenseLook.categoryArt(cat), width: DS.s(24), height: DS.s(24)),
              Gap.h(6),
              Flexible(
                child: Text(cat,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, on ? DesignColors.onPrimary : BuddyLook.subText, letterSpacing: 0)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) Gap.v(8),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) Gap.h(8), Expanded(child: chip(cats[r * 3 + i]))],
          ]),
        ],
      ],
    );
  }

  Widget _chip({required String label, String? art, required bool on, required VoidCallback onTap, required Key tapKey, bool anchor = false}) {
    final chip = Container(
      constraints: BoxConstraints(minHeight: DS.s(40)),
      padding: DS.sym(h: 14),
      decoration: BoxDecoration(
        color: on ? ExpenseLook.roseTint : DesignColors.surface,
        borderRadius: DS.circular(20),
        border: Border.all(color: on ? ExpenseLook.roseDot : ExpenseLook.fieldBorder, width: DS.s(1.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null) ...[Image.asset(art, width: DS.s(22), height: DS.s(22)), Gap.h(6)],
          Text(label, style: Ink3D.text(12.5, FontWeight.w700, on ? BuddyLook.roseEnd : BuddyLook.subText, letterSpacing: 0)),
        ],
      ),
    );
    return Padding(
      key: anchor ? _selectedChip : null,
      padding: DS.insets(r: 8),
      child: Tap3D(tapKey: tapKey, onTap: onTap, selected: on, label: label, exclude: true, child: chip),
    );
  }

  Widget _links() {
    final setup = c.setup;
    final selected = c.link.value;
    final links = [for (final l in setup.links) if (!l.cancelled || l.id == selected?.id) l]
      ..sort((a, b) => a.kind == b.kind ? 0 : (a.kind == ExpenseLinkKind.taxi ? -1 : 1));
    final stays = links.where((l) => l.kind == ExpenseLinkKind.stay).length;
    final linkChips = <Widget>[
      for (final l in links)
        _chip(
          tapKey: ExpenseSheet.linkKey(l.id),
          label: l.kind == ExpenseLinkKind.taxi
              ? ExpenseStrings.bookedTaxi
              : (stays > 1 ? ExpenseStrings.bookedStayNamed(l.label) : ExpenseStrings.bookedStay),
          art: ExpenseLook.linkArt(l.kind),
          on: selected?.id == l.id,
          onTap: () => c.pickLink(l),
        ),
    ];
    final dayChips = <Widget>[
      for (var d = 1; d <= setup.dayCount; d++)
        _chip(
          tapKey: ExpenseSheet.dayKey(d),
          label: _dayLabel(d, on: selected == null && c.day.value == d),
          on: selected == null && c.day.value == d,
          onTap: () => c.pickDay(d),
          anchor: c.day.value == d,
        ),
    ];
    final days = SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: dayChips));
    if (linkChips.length > 2) {
      return SingleChildScrollView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, child: Row(children: [...linkChips, ...dayChips]));
    }
    return Row(children: [...linkChips, Expanded(child: days)]);
  }

  String _dayLabel(int d, {required bool on}) {
    if (!on) return ExpenseStrings.dayChip(d);
    if (d == c.setup.dayToday) return ExpenseStrings.dayChipToday(d);
    final date = c.dateOf(d);
    return date == null ? ExpenseStrings.dayChip(d) : ExpenseStrings.dayDate(d, date);
  }

  Widget _payer() {
    final p = c.person(c.payer.value);
    return ExpenseFieldBox(
      tapKey: ExpenseSheet.payerKey,
      label: ExpenseStrings.paidByLabel,
      onTap: _pickPayer,
      child: Row(
        children: [
          if (p != null) ...[BuddyAvatar(initial: p.initial, seed: p.userId, size: BuddyAvatarSize.sm), Gap.h(10)],
          Expanded(
            child: Text(p == null ? '' : (p.isMe ? ExpenseStrings.you(p.name) : p.name),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: DS.s(22), color: ExpenseLook.fieldOn),
        ],
      ),
    );
  }

  Widget _bar({required bool withInset}) {
    final valid = c.valid;
    final pill = GradientPillButton(
      key: ExpenseSheet.saveKey,
      tone: BuddyLook.rose,
      label: c.isEdit ? ExpenseStrings.saveChanges : ExpenseStrings.saveExpense,
      enabled: valid,
      loading: c.saving.value,
      offColor: ExpenseLook.pillDisabled,
      onTap: _save,
    );
    final child = valid ? pill : GestureDetector(behavior: HitTestBehavior.opaque, onTap: c.attemptOnOff, child: pill);
    final bar = BuddyBottomBar(children: [child]);
    if (withInset) return bar;
    return MediaQuery.removePadding(context: context, removeBottom: true, child: bar);
  }
}

