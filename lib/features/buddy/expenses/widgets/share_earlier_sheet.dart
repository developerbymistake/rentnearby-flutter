import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/check_line.dart';
import '../controllers/share_earlier_controller.dart';
import '../data/expenses_api.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import 'expense_form_parts.dart';
import 'payments_made_dialog.dart';

class ShareEarlierSheet extends StatefulWidget {
  const ShareEarlierSheet({super.key, required this.tripId, required this.prompt, required this.travellers, this.api});

  static const Key submitKey = ValueKey('share_earlier_submit');
  static const Key cancelKey = ValueKey('share_earlier_cancel');
  static const Key closeKey = ValueKey('share_earlier_close');
  static Key rowKey(String id) => ValueKey('share_earlier_$id');

  final String tripId;
  final LatePrompt prompt;
  final List<MoneyPerson> travellers;
  final ExpensesApi? api;

  static Future<ShareEnd?> show(BuildContext context, {required String tripId, required LatePrompt prompt, required List<MoneyPerson> travellers, ExpensesApi? api}) =>
      showModalBottomSheet<ShareEnd>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: DesignColors.scrim,
        builder: (_) => ShareEarlierSheet(tripId: tripId, prompt: prompt, travellers: travellers, api: api),
      );

  @override
  State<ShareEarlierSheet> createState() => _ShareEarlierSheetState();
}

class _ShareEarlierSheetState extends State<ShareEarlierSheet> {
  late final String _tag = 'share_earlier_${identityHashCode(this)}';
  late final ShareEarlierController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(ShareEarlierController(tripId: widget.tripId, prompt: widget.prompt, travellers: widget.travellers, api: widget.api), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<ShareEarlierController>(tag: _tag);
    super.dispose();
  }

  Future<void> _submit({bool ack = false}) async {
    final end = await c.submit(ack: ack);
    if (!mounted) return;
    switch (end) {
      case ShareEnd.needsAck:
        final ok = await PaymentsMadeDialog.ask(context, c.noticeNames);
        if (ok && mounted) await _submit(ack: true);
      case ShareEnd.none:
        return;
      default:
        Navigator.of(context).pop(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final name = widget.prompt.name;
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: (mq.size.height - DS.s(300)).clamp(DS.s(360), mq.size.height - mq.padding.top - DS.s(56))),
      child: Material(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
        clipBehavior: Clip.antiAlias,
        child: Obx(() {
          final items = c.items;
          final ticked = c.ticked.toList();
          final preview = c.previewItem;
          final names = c.noticeNames;
          final error = c.error.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: DS.insets(l: 20, t: 18, r: 12, b: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(ExpenseStrings.shareWithTitle(name), style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0))),
                          Text(ExpenseStrings.shareWithSub(name), style: Ink3D.text(12.5, FontWeight.w400, ExpenseLook.copy, height: 1.5, letterSpacing: 0)),
                        ],
                      ),
                    ),
                    Tap3D(
                      tapKey: ShareEarlierSheet.closeKey,
                      onTap: () => Navigator.of(context).pop(),
                      label: ExpenseStrings.close,
                      exclude: true,
                      child: SizedBox(
                        width: DS.s(44),
                        height: DS.s(44),
                        child: Center(
                          child: Container(
                            width: DS.s(30),
                            height: DS.s(30),
                            decoration: const BoxDecoration(color: BuddyLook.closeBg, shape: BoxShape.circle),
                            child: Icon(Icons.close_rounded, size: DS.s(18), color: BuddyLook.closeX),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: DS.insets(l: 20, t: 12, r: 20, b: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        DecoratedBox(
                          decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
                          child: CheckLine(
                            key: ShareEarlierSheet.rowKey(items[i].expenseId),
                            title: items[i].title,
                            subtitle: ExpenseStrings.candidateLine(items[i].dayNumber, items[i].amount, c.nameOf(items[i].paidByUserId)),
                            checked: ticked.contains(items[i].expenseId),
                            onTap: () => c.toggle(items[i].expenseId),
                          ),
                        ),
                      if (preview != null) _preview(preview),
                      if (error != null) ExpenseLine(error),
                      if (names.isNotEmpty) ExpenseLine(ExpenseStrings.willGetNotice(names), tone: FieldLineTone.rose),
                    ],
                  ),
                ),
              ),
              BuddyBottomBar(children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPillButton(
                      key: ShareEarlierSheet.submitKey,
                      tone: BuddyLook.rose,
                      label: ExpenseStrings.shareCount(ticked.isEmpty ? 1 : ticked.length),
                      enabled: ticked.isNotEmpty,
                      loading: c.busy.value,
                      offColor: ExpenseLook.pillDisabled,
                      onTap: _submit,
                    ),
                    Tap3D(
                      tapKey: ShareEarlierSheet.cancelKey,
                      onTap: () => Navigator.of(context).pop(),
                      label: ExpenseStrings.cancel,
                      exclude: true,
                      child: Container(
                        constraints: BoxConstraints(minHeight: DS.s(40)),
                        margin: DS.insets(t: 6),
                        alignment: Alignment.center,
                        child: Text(ExpenseStrings.cancel, style: Ink3D.text(13, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          );
        }),
      ),
    );
  }

  Widget _preview(LateCandidate item) => Container(
        margin: DS.insets(t: 12),
        padding: DS.sym(h: 14, v: 10),
        decoration: BoxDecoration(color: ExpenseLook.roseTint, borderRadius: ExpenseShape.corner(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: DS.insets(b: 2),
              child: Text(ExpenseStrings.newShares(item.title.split(',').first), style: Ink3D.text(13, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
            ),
            for (final r in c.previewOf(item))
              Padding(
                padding: DS.sym(v: 6),
                child: Row(
                  children: [
                    BuddyAvatar(initial: r.person.initial, seed: r.person.userId, size: BuddyAvatarSize.sm, photoUrl: r.person.photoUrl),
                    Gap.h(10),
                    Expanded(child: Text(r.person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                    Text(BuddyFormat.rupees(r.before),
                        style: Ink3D.text(13.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0).copyWith(decoration: TextDecoration.lineThrough)),
                    SizedBox(
                      width: DS.s(76),
                      child: Text(BuddyFormat.rupees(r.after), textAlign: TextAlign.right, style: Ink3D.text(13.5, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
