import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/money_name.dart';
import '../../shared/widgets/small_pill.dart';
import '../../shared/widgets/who_pays_row_frame.dart';
import '../../shared/buddy_format.dart';
import '../controllers/trip_balances_controller.dart';
import '../ledger_rules.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';
import '../payment_flows.dart';

class WhoPaysCard extends StatelessWidget {
  const WhoPaysCard({super.key, required this.tripId, required this.balances, required this.row, this.margin});

  final String tripId;
  final TripBalances balances;
  final PaymentRow row;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  static Key keyOf(PaymentRow r) => ValueKey('who_pays_${LedgerRules.rowKey(r)}');

  @override
  Widget build(BuildContext context) {
    final c = TripBalancesController.maybeOf(tripId);
    if (c == null) return _card(context, null);
    return Obx(() {
      c.busy.length;
      c.reminded.length;
      c.changed.length;
      return _card(context, c);
    });
  }

  Widget _card(BuildContext context, TripBalancesController? c) {
    final b = balances;
    final from = LedgerRules.personOr(b, row.fromUserId);
    final to = LedgerRules.personOr(b, row.toUserId);
    final paysMe = to.isMe && !b.isOwner;
    final changed = c?.changed.contains(LedgerRules.rowKey(row)) ?? false;
    final titleStyle = Ink3D.text(14.5, FontWeight.w700, Ink3D.title, letterSpacing: 0);
    final title = paysMe
        ? Text(LedgerStrings.paysYou(LedgerRules.plainName(from), row.amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)
        : Text.rich(
            TextSpan(children: [
              ...MoneyName.spans(from, titleStyle, showYou: false),
              TextSpan(text: ' ${LedgerStrings.pays} ', style: titleStyle),
              ...MoneyName.spans(to, titleStyle, showYou: false),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    final waitLine = paysMe && row.isSaidPaid ? LedgerStrings.saysPaidWait(LedgerRules.plainName(from), b.ownerName) : null;
    return Container(
      key: keyOf(row),
      margin: margin ?? DS.insets(l: 18, t: 12, r: 18),
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              BuddyAvatar(initial: from.initial, seed: from.userId, size: BuddyAvatarSize.sm, photoUrl: from.photoUrl),
              Gap.h(10),
              Text(WhoPaysRowFrame.arrow, style: Ink3D.text(18, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
              Gap.h(10),
              BuddyAvatar(initial: to.initial, seed: to.userId, size: BuddyAvatarSize.sm, photoUrl: to.photoUrl),
              Gap.h(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    Text(LedgerRules.subtitle(row, b.reopened), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              if (!paysMe) ...[
                Gap.h(10),
                Text(BuddyFormat.rupees(row.amount), maxLines: 1, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              ],
            ],
          ),
          if (changed) _line(LedgerStrings.paymentChanged, BuddyLook.dangerText),
          if (waitLine != null) _line(waitLine, BuddyLook.amberText),
          Container(
            margin: EdgeInsets.only(top: DS.s(12)),
            padding: EdgeInsets.only(top: DS.s(12)),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
            child: Row(children: _footer(context, c, from, to)),
          ),
        ],
      ),
    );
  }

  Widget _line(String text, Color color) => Padding(
        padding: EdgeInsets.only(top: DS.s(10)),
        child: Text(text, style: Ink3D.text(12.5, FontWeight.w700, color, height: 1.4, letterSpacing: 0)),
      );

  List<Widget> _footer(BuildContext context, TripBalancesController? c, MoneyPerson from, MoneyPerson to) {
    final b = balances;
    final busy = c?.isBusy(row) ?? false;
    if (row.isReceived) {
      final marked = LedgerRules.markedLine(b, row);
      return [
        const ReceivedBadge(),
        Gap.h(10),
        Expanded(
          child: Text(marked ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
        ),
      ];
    }
    final buttons = <Widget>[];
    if (row.isSaidPaid) {
      if (row.canMarkNotReceived) {
        buttons.add(SmallPill(
          key: ValueKey('not_received_${LedgerRules.rowKey(row)}'),
          label: LedgerStrings.notReceived,
          kind: SmallPillKind.dangerOutline,
          onTap: busy ? null : () => PaymentFlows.markNotReceived(context, tripId, row, payer: from),
        ));
      }
      if (row.canWithdraw) {
        buttons.add(SmallPill(
          key: ValueKey('not_paid_${LedgerRules.rowKey(row)}'),
          label: LedgerStrings.notPaid,
          kind: SmallPillKind.dangerOutline,
          onTap: busy ? null : () => PaymentFlows.withdraw(context, tripId, row, ownerName: _ownerFor(b, to)),
        ));
      }
      if (row.canMarkReceived) {
        buttons.add(SmallPill(
          key: ValueKey('mark_received_${LedgerRules.rowKey(row)}'),
          label: LedgerStrings.markAsReceived,
          kind: SmallPillKind.green,
          onTap: busy ? null : () => PaymentFlows.markReceived(context, tripId, row, payer: from, receiver: to),
        ));
      }
    } else {
      if (row.canSayPaid) {
        buttons.add(SmallPill(
          key: ValueKey('say_paid_${LedgerRules.rowKey(row)}'),
          label: LedgerStrings.iHavePaid,
          kind: SmallPillKind.rose,
          onTap: busy ? null : () => PaymentFlows.sayPaid(context, tripId, row, ownerName: b.ownerName, receiver: to, payerIsOwner: b.isOwner),
        ));
      }
      if (row.canRemind) {
        final off = c?.reminderOff(row) ?? row.reminderSentToday;
        buttons.add(RemindPill(
          key: ValueKey('remind_${LedgerRules.rowKey(row)}'),
          sent: off,
          busy: busy,
          onTap: () => PaymentFlows.remind(context, tripId, row, payer: from),
        ));
      }
    }
    return [
      BuddyBadge(row.isSaidPaid ? LedgerStrings.saysPaid : LedgerStrings.open, tone: row.isSaidPaid ? BuddyBadgeTone.pending : BuddyBadgeTone.grey),
      Gap.h(10),
      Expanded(
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DS.gh(8),
          runSpacing: DS.gv(8),
          children: [for (final b in buttons) IntrinsicWidth(child: b)],
        ),
      ),
    ];
  }

  static String _ownerFor(TripBalances b, MoneyPerson receiver) => b.isOwner ? LedgerRules.plainName(receiver) : b.ownerName;
}

class RemindPill extends StatelessWidget {
  const RemindPill({super.key, required this.sent, required this.busy, required this.onTap});

  final bool sent;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (sent) return SmallPill(label: LedgerStrings.reminderSent, kind: SmallPillKind.off, onTap: null);
    final h = DS.s(40);
    return Tap3D(
      onTap: busy ? null : onTap,
      label: LedgerStrings.sendReminder,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: h),
        padding: DS.sym(h: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(h / 2)),
          boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v18), offset: DS.shadowOffset(const Offset(2, 4)), blurRadius: DS.shadowBlur(8))],
        ),
        child: busy
            ? SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: BuddyLook.roseEnd))
            : Text(LedgerStrings.sendReminder, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
      ),
    );
  }
}

class ReceivedBadge extends StatelessWidget {
  const ReceivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = BuddyLook.badge[BuddyBadgeColor.ok]!;
    return Semantics(
      label: LedgerStrings.received,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(24)),
        padding: DS.sym(h: 10),
        decoration: BoxDecoration(color: bg, borderRadius: DS.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: DS.s(13), color: fg),
            Gap.h(3),
            Text(LedgerStrings.receivedWord, maxLines: 1, style: Ink3D.text(11.5, FontWeight.w700, fg, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}
