import 'package:flutter/widgets.dart';

import '../buddy_error_types.dart';
import '../shared/buddy_format.dart';
import '../shared/buddy_result.dart';
import '../shared/models/person_models.dart';
import '../shared/strings_shared.dart';
import '../shared/widgets/buddy_confirm_box.dart';
import 'controllers/trip_balances_controller.dart';
import 'ledger_deps.dart';
import 'ledger_look.dart';
import 'ledger_rules.dart';
import 'ledger_strings.dart';
import 'models/ledger_models.dart';

abstract final class PaymentFlows {
  static Future<bool> sayPaid(BuildContext context, String tripId, PaymentRow row,
      {required String ownerName, required MoneyPerson receiver, bool payerIsOwner = false}) async {
    final c = TripBalancesController.of(tripId);
    final key = LedgerRules.rowKey(row);
    if (!c.begin(key)) return false;
    try {
      final opId = c.opIdFor(row);
      final to = LedgerRules.plainName(receiver);
      final ok = await BuddyConfirmBox.ask(
        context,
        art: LedgerLook.alarm,
        title: LedgerStrings.paidTitle(row.amount),
        body: payerIsOwner ? LedgerStrings.paidBodyOwner(to) : LedgerStrings.paidBody(to, ownerName),
        cancelLabel: LedgerStrings.notYet,
        confirmLabel: LedgerStrings.yesIPaid,
      );
      if (!ok) return false;
      final r = await LedgerDeps.api.saidPaid(tripId, opId: opId, toUserId: row.toUserId, amount: row.amount);
      if (r is BuddyOffline) {
        LedgerDeps.offline();
        return false;
      }
      switch (r) {
        case BuddyOk():
          c.dropOpId(row);
          c.clearMarks();
        case BuddyRefused(:final type):
          c.dropOpId(row);
          if (type == BuddyErrorTypes.balancesChanged) {
            c.markRace(LedgerRace.amountChanged);
          } else if (type == BuddyErrorTypes.nothingToPay) {
            c.markRace(LedgerRace.nothingLeft);
          } else {
            _refused(r);
          }
        default:
          LedgerDeps.toast(BuddySharedStrings.somethingWrong);
      }
      await c.reloadFresh();
      return r is BuddyOk;
    } finally {
      c.end(key);
    }
  }

  static Future<bool> withdraw(BuildContext context, String tripId, PaymentRow row, {required String ownerName}) async {
    final c = TripBalancesController.of(tripId);
    final key = LedgerRules.rowKey(row);
    final id = row.paymentId;
    if (id == null || !c.begin(key)) return false;
    try {
      final ok = await BuddyConfirmBox.ask(
        context,
        art: LedgerLook.moneyBag,
        title: LedgerStrings.notPaidTitle,
        body: LedgerStrings.notPaidBody(ownerName),
        cancelLabel: LedgerStrings.keepIt,
        confirmLabel: LedgerStrings.notPaid,
        confirmKind: ConfirmKind.danger,
      );
      if (!ok) return false;
      final r = await LedgerDeps.api.withdraw(tripId, id);
      if (r is BuddyOffline) {
        LedgerDeps.offline();
        return false;
      }
      switch (r) {
        case BuddyOk():
          c.clearMarks();
        case BuddyRefused(:final type):
          if (type == BuddyErrorTypes.paymentStateChanged) {
            LedgerDeps.toast(LedgerStrings.alreadyReceived(ownerName));
          } else if (type != BuddyErrorTypes.notYourDebt) {
            _refused(r);
          }
        default:
          LedgerDeps.toast(BuddySharedStrings.somethingWrong);
      }
      await c.reloadFresh();
      return r is BuddyOk;
    } finally {
      c.end(key);
    }
  }

  static Future<bool> markReceived(BuildContext context, String tripId, PaymentRow row,
      {required MoneyPerson payer, required MoneyPerson receiver}) async {
    final c = TripBalancesController.of(tripId);
    final key = LedgerRules.rowKey(row);
    final id = row.paymentId;
    if (id == null || !c.begin(key)) return false;
    try {
      final from = LedgerRules.plainName(payer);
      final to = LedgerRules.plainName(receiver);
      final ok = await BuddyConfirmBox.ask(
        context,
        art: LedgerLook.alarm,
        title: receiver.isMe ? LedgerStrings.receivedTitle(row.amount) : LedgerStrings.receivedByTitle(row.amount, to),
        body: receiver.isMe ? LedgerStrings.receivedBody(from) : LedgerStrings.receivedByBody(to, from),
        cancelLabel: LedgerStrings.notYet,
        confirmLabel: LedgerStrings.yesReceived,
      );
      if (!ok) return false;
      final r = await LedgerDeps.api.received(tripId, id);
      if (r is BuddyOffline) {
        LedgerDeps.offline();
        return false;
      }
      _ownerAnswer(c, row, r);
      if (r is BuddyOk && context.mounted) LedgerDeps.snack(context, LedgerStrings.receivedSnack(from));
      await c.reloadFresh();
      return r is BuddyOk;
    } finally {
      c.end(key);
    }
  }

  static Future<bool> markNotReceived(BuildContext context, String tripId, PaymentRow row, {required MoneyPerson payer}) async {
    final c = TripBalancesController.of(tripId);
    final key = LedgerRules.rowKey(row);
    final id = row.paymentId;
    if (id == null || !c.begin(key)) return false;
    try {
      final ok = await BuddyConfirmBox.ask(
        context,
        art: LedgerLook.warning,
        title: LedgerStrings.notReceivedTitle,
        body: LedgerStrings.notReceivedBody(BuddyFormat.moneyName(payer), row.amount, LedgerRules.plainName(payer)),
        cancelLabel: LedgerStrings.cancel,
        confirmLabel: LedgerStrings.notReceived,
        confirmKind: ConfirmKind.danger,
      );
      if (!ok) return false;
      final r = await LedgerDeps.api.notReceived(tripId, id);
      if (r is BuddyOffline) {
        LedgerDeps.offline();
        return false;
      }
      _ownerAnswer(c, row, r);
      await c.reloadFresh();
      return r is BuddyOk;
    } finally {
      c.end(key);
    }
  }

  static Future<bool> remind(BuildContext context, String tripId, PaymentRow row, {required MoneyPerson payer}) async {
    final c = TripBalancesController.of(tripId);
    final key = LedgerRules.rowKey(row);
    if (c.reminderOff(row) || !c.begin(key)) return false;
    try {
      final r = await LedgerDeps.api.remind(tripId, row.fromUserId);
      switch (r) {
        case BuddyOffline():
          LedgerDeps.offline();
          return false;
        case BuddyOk():
          c.reminded.add(key);
          if (context.mounted) LedgerDeps.snack(context, LedgerStrings.reminderSnack(LedgerRules.plainName(payer)));
        case BuddyRefused(:final type):
          if (type == BuddyErrorTypes.reminderAlreadySent) {
            c.reminded.add(key);
          } else if (type != BuddyErrorTypes.nothingToPay) {
            _refused(r);
          }
        case BuddyFailed():
          LedgerDeps.toast(BuddySharedStrings.somethingWrong);
      }
      await c.reloadFresh();
      return r is BuddyOk;
    } finally {
      c.end(key);
    }
  }

  static void _ownerAnswer(TripBalancesController c, PaymentRow row, BuddyResult<Object?> r) {
    switch (r) {
      case BuddyOk():
        c.clearMarks();
      case BuddyRefused(:final type):
        if (type == BuddyErrorTypes.paymentStateChanged || type == BuddyErrorTypes.paymentNotFound) {
          c.markChanged(row);
        } else if (type != BuddyErrorTypes.notTripOwner) {
          _refused(r);
        }
      default:
        LedgerDeps.toast(BuddySharedStrings.somethingWrong);
    }
  }

  static void _refused(BuddyRefused<Object?> r) =>
      LedgerDeps.toast(r.rateLimited ? BuddySharedStrings.tooManyTries : (r.message ?? BuddySharedStrings.somethingWrong));
}
