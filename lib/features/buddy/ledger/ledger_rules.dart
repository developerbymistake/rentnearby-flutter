import '../shared/buddy_format.dart';
import '../shared/models/person_models.dart';
import 'ledger_strings.dart';
import 'models/ledger_models.dart';

enum ViewerHeroKind { youOwe, oweSeveral, paidWaiting, paidSquare, nothingToPay, owedToYou }

enum ViewerBanner { none, amountChanged, nothingLeft, waiting, notGotIt, gotIt }

enum NetTone { getsBack, owes, square }

enum LedgerRace { none, amountChanged, nothingLeft }

class ViewerHero {
  const ViewerHero({required this.kind, required this.label, required this.amount, this.row, this.banner = ViewerBanner.none, this.bannerText});

  final ViewerHeroKind kind;
  final String label;
  final int amount;
  final PaymentRow? row;
  final ViewerBanner banner;
  final String? bannerText;

  bool get showPaid => kind == ViewerHeroKind.youOwe && (row?.canSayPaid ?? false);
  bool get showNotPaid => kind == ViewerHeroKind.paidWaiting && (row?.canWithdraw ?? false);
}

abstract final class LedgerRules {
  static String rowKey(PaymentRow r) => '${r.fromUserId}>${r.toUserId}';

  static NetTone netTone(int net) => net > 0 ? NetTone.getsBack : (net < 0 ? NetTone.owes : NetTone.square);

  static String netLabel(int net) => switch (netTone(net)) {
        NetTone.getsBack => LedgerStrings.getsBack(net),
        NetTone.owes => LedgerStrings.owes(-net),
        NetTone.square => LedgerStrings.allSquare,
      };

  static String? meId(TripBalances b) {
    for (final p in b.people) {
      if (p.person.isMe) return p.person.userId;
    }
    return null;
  }

  static MoneyPerson personOr(TripBalances b, String userId) =>
      b.person(userId) ?? MoneyPerson(userId: userId, name: BuddyFormat.deletedName, last4: '', initial: '?', isMe: false, status: MoneyPersonStatus.deleted);

  static String plainName(MoneyPerson p) => p.isDeleted ? BuddyFormat.deletedName : p.name;

  static ViewerHero viewerHero(TripBalances b, {LedgerRace race = LedgerRace.none, int? changedAmount}) {
    final me = meId(b);
    final mine = [for (final r in b.payments) if (r.fromUserId == me) r];
    final pending = [for (final r in mine) if (!r.isReceived) r];
    final owner = b.ownerName;
    if (pending.length > 1) {
      return ViewerHero(kind: ViewerHeroKind.oweSeveral, label: LedgerStrings.youOweTotal, amount: pending.fold(0, (a, r) => a + r.amount));
    }
    if (pending.length == 1) {
      final r = pending.first;
      final to = personOr(b, r.toUserId);
      if (r.isSaidPaid) {
        return ViewerHero(
          kind: ViewerHeroKind.paidWaiting,
          label: LedgerStrings.paidTo(plainName(to)),
          amount: r.amount,
          row: r,
          banner: ViewerBanner.waiting,
          bannerText: LedgerStrings.waitingConfirm(owner),
        );
      }
      if (race == LedgerRace.amountChanged) {
        return ViewerHero(
          kind: ViewerHeroKind.youOwe,
          label: LedgerStrings.youOwe(BuddyFormat.moneyName(to)),
          amount: r.amount,
          row: r,
          banner: ViewerBanner.amountChanged,
          bannerText: LedgerStrings.amountChanged(r.amount),
        );
      }
      final notGot = r.afterNotReceivedAt != null;
      return ViewerHero(
        kind: ViewerHeroKind.youOwe,
        label: LedgerStrings.youOwe(BuddyFormat.moneyName(to)),
        amount: r.amount,
        row: r,
        banner: notGot ? ViewerBanner.notGotIt : ViewerBanner.none,
        bannerText: notGot ? LedgerStrings.notGotIt(owner) : null,
      );
    }
    if (b.me.net > 0) return ViewerHero(kind: ViewerHeroKind.owedToYou, label: LedgerStrings.owedToYou, amount: b.me.net);
    if (mine.isNotEmpty && race != LedgerRace.nothingLeft) {
      final r = mine.last;
      final to = plainName(personOr(b, r.toUserId));
      return ViewerHero(
        kind: ViewerHeroKind.paidSquare,
        label: LedgerStrings.paidTo(to),
        amount: r.amount,
        row: r,
        banner: ViewerBanner.gotIt,
        bannerText: LedgerStrings.gotIt(to),
      );
    }
    final race0 = race == LedgerRace.nothingLeft;
    return ViewerHero(
      kind: ViewerHeroKind.nothingToPay,
      label: LedgerStrings.nothingToPay,
      amount: 0,
      banner: race0 ? ViewerBanner.nothingLeft : ViewerBanner.none,
      bannerText: race0 ? LedgerStrings.nothingLeft : null,
    );
  }

  static String shortTitle(String? title) {
    final t = (title ?? '').trim();
    if (t.isEmpty) return LedgerStrings.expensesTitle;
    final cut = t.indexOf(',');
    return cut > 0 ? t.substring(0, cut).trim() : t;
  }

  static String subtitle(PaymentRow r, ReopenedInfo? reopened) {
    if (r.isOpen) {
      final at = reopened?.at;
      if (r.afterEdit && at != null) return LedgerStrings.changedOn(shortTitle(reopened?.expenseTitle), at);
      return LedgerStrings.notPaidYet;
    }
    final at = r.saidPaidAt ?? r.receivedAt;
    return at == null ? LedgerStrings.saysPaid : LedgerStrings.paidOn(at);
  }

  static String? markedLine(TripBalances b, PaymentRow r) {
    final at = r.receivedAt;
    if (!r.isReceived || at == null) return null;
    final by = r.receivedByUserId;
    if (by != null && by == meId(b)) return LedgerStrings.markedByYou(at);
    return LedgerStrings.markedBy(by == null ? b.ownerName : plainName(personOr(b, by)), at);
  }

  static int toSettle(TripBalances b) => b.payments.where((r) => !r.isReceived).length;

  static int openAgain(TripBalances b) => b.payments.where((r) => r.afterEdit && !r.isReceived).length;

  static bool reopenedNow(TripBalances b) => b.reopened != null && openAgain(b) > 0;

  static bool nothingYet(TripBalances b) => b.payments.isEmpty && b.people.every((p) => p.paid == 0 && p.share == 0);

  static bool allSettled(TripBalances b) => !nothingYet(b) && b.payments.every((r) => r.isReceived);

  static String settleHeroLabel(int net) => switch (netTone(net)) {
        NetTone.getsBack => LedgerStrings.youGetBack,
        NetTone.owes => LedgerStrings.youOweHero,
        NetTone.square => LedgerStrings.allSquare,
      };

  static String receiverFirstName(TripBalances b, PaymentRow r) => plainName(personOr(b, r.toUserId));

  static String payerFirstName(TripBalances b, PaymentRow r) => plainName(personOr(b, r.fromUserId));
}
