import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../buddy_navigation.dart';
import '../../expenses/data/expenses_api.dart';
import '../../expenses/models/expense_models.dart';
import '../../ledger/data/ledger_api.dart';
import '../../ledger/models/ledger_models.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/money_hero.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/small_pill.dart';
import '../../shared/widgets/who_pays_row_frame.dart';
import '../controllers/former_share_controller.dart';
import '../viewer_look.dart';
import '../viewer_strings.dart';

class FormerShareScreen extends StatefulWidget {
  const FormerShareScreen({super.key, required this.tripId, this.expenses, this.ledger});

  final String tripId;
  final ExpensesApi? expenses;
  final LedgerApi? ledger;

  static String artOf(String category) => switch (category) {
        ExpenseCategory.stay => ListingArt.hotelBuilding,
        ExpenseCategory.taxi => ListingArt.taxi,
        ExpenseCategory.food => ListingArt.potOfFood,
        ExpenseCategory.fuel => ViewerLook.automobileArt,
        ExpenseCategory.tickets => BuddyArt.camera,
        _ => ListingArt.backpack,
      };

  @override
  State<FormerShareScreen> createState() => _FormerShareScreenState();
}

class _FormerShareScreenState extends State<FormerShareScreen> {
  late final FormerShareController _c;
  late final String _tag = 'former:${widget.tripId}';
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<FormerShareController>(tag: _tag)) Get.delete<FormerShareController>(tag: _tag, force: true);
    _c = Get.put(FormerShareController(widget.tripId, expenses: widget.expenses, ledger: widget.ledger), tag: _tag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<FormerShareController>(tag: _tag) && identical(Get.find<FormerShareController>(tag: _tag), _c)) Get.delete<FormerShareController>(tag: _tag, force: true);
    super.dispose();
  }

  void _gone() {
    if (_redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => BuddyNavigation.openTripView(widget.tripId, deleted: true, replace: true));
  }

  String _name(String userId) {
    final p = _c.person(userId);
    return p == null ? BuddySharedStrings.someone : BuddyFormat.moneyName(p);
  }

  Future<void> _sayPaid(PaymentRow row) async {
    final ok = await BuddyConfirmBox.ask(
      context,
      art: BuddyArt.moneyBag,
      title: ViewerStrings.havePaidTitle(row.amount),
      body: ViewerStrings.havePaidBody(_name(row.toUserId)),
      cancelLabel: ViewerStrings.notYet,
      confirmLabel: ViewerStrings.yesPaid,
      confirmKind: ConfirmKind.rose,
    );
    if (ok) await _c.sayPaid(row);
  }

  Future<void> _withdraw(PaymentRow row) async {
    final ok = await BuddyConfirmBox.ask(
      context,
      art: BuddyArt.moneyBag,
      title: ViewerStrings.notPaidTitle,
      body: ViewerStrings.notPaidBody(_name(row.toUserId)),
      cancelLabel: ViewerStrings.keepIt,
      confirmLabel: ViewerStrings.notPaid,
      confirmKind: ConfirmKind.danger,
    );
    if (ok) await _c.withdraw(row);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final s = _c.state.value;
        final list = _c.list.value;
        final bal = _c.balances.value;
        if (s == FormerShareState.gone) _gone();
        final title = list?.tripTitle ?? bal?.tripTitle ?? '';
        final owner = list?.ownerName ?? bal?.ownerName ?? '';
        if (list == null || bal == null) {
          return BuddyPage(
            title: ViewerStrings.myShareTitle,
            onBack: Get.back,
            body: s == FormerShareState.failed
                ? StateCard3D(
                    tone: BuddyLook.rose,
                    art: BuddyArt.antenna,
                    title: BuddySharedStrings.couldNotLoad,
                    message: BuddySharedStrings.couldNotLoadLine,
                    actionLabel: BuddySharedStrings.retry,
                    onAction: _c.load,
                    layout: StateLayout.tall,
                  )
                : Padding(padding: DS.all(40), child: const Center(child: CircularProgressIndicator())),
          );
        }
        final rows = _c.myRows;
        final shared = [for (final e in list.items) if (e.myShare > 0) e];
        final children = <Widget>[
          const _GoneBanner(),
          _hero(bal, rows),
          if (rows.isNotEmpty) SectionLabel(ViewerStrings.yourPayment, padding: DS.insets(l: 22, t: 20, r: 22)),
          for (final r in rows) ..._payment(r),
          SectionLabel(ViewerStrings.sharedExpenses(shared.length), padding: DS.insets(l: 22, t: 20, r: 22)),
          if (shared.isNotEmpty)
            Container(
              key: const ValueKey('former_expenses'),
              margin: DS.insets(l: 18, t: 16, r: 18),
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: DS.br(CardRadius.tile),
                boxShadow: BuddyLook.cardShadows(DS.size),
              ),
              child: Column(children: [for (var i = 0; i < shared.length; i++) _ExpenseLine(item: shared[i], payer: _name(shared[i].paidByUserId), first: i == 0)]),
            ),
        ];
        return BuddyPage(
          title: ViewerStrings.myShareTitle,
          subtitle: title.isEmpty ? null : ViewerStrings.myShareSub(title, owner),
          onBack: Get.back,
          scroll: false,
          body: RefreshIndicator(
            color: BuddyLook.roseEnd,
            onRefresh: _c.load,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.only(bottom: DS.s(28)), children: children),
          ),
        );
      });

  Widget _hero(TripBalances bal, List<PaymentRow> rows) {
    final me = _c.myId;
    final pay = [for (final r in rows) if (r.fromUserId == me) r];
    final get = [for (final r in rows) if (r.toUserId == me) r];
    late final String label;
    late final int amount;
    if (pay.isNotEmpty && pay.every((r) => r.isReceived)) {
      label = ViewerStrings.paidTo(_name(pay.first.toUserId));
      amount = pay.fold(0, (a, r) => a + r.amount);
    } else if (pay.isNotEmpty) {
      label = ViewerStrings.youOweName(_name(pay.first.toUserId));
      amount = pay.where((r) => !r.isReceived).fold(0, (a, r) => a + r.amount);
    } else if (get.isNotEmpty) {
      label = ViewerStrings.owedToYou;
      amount = get.where((r) => !r.isReceived).fold(0, (a, r) => a + r.amount);
    } else {
      label = ViewerStrings.nothingToPay;
      amount = 0;
    }
    return MoneyHero(
      key: const ValueKey('former_hero'),
      label: label,
      amount: BuddyFormat.rupees(amount),
      cells: [(BuddyFormat.rupees(bal.me.share), ViewerStrings.yourShare), (BuddyFormat.rupees(bal.me.paid), ViewerStrings.youPaid)],
    );
  }

  List<Widget> _payment(PaymentRow r) {
    final me = _c.myId;
    final iPay = r.fromUserId == me;
    final from = _c.person(r.fromUserId);
    final to = _c.person(r.toUserId);
    final other = _name(iPay ? r.toUserId : r.fromUserId);
    final key = FormerShareController.rowKey(r);
    final (badge, tone) = r.isReceived
        ? (ViewerStrings.receivedBadge, BuddyBadgeTone.ok)
        : r.isSaidPaid
            ? (ViewerStrings.saysPaidBadge, BuddyBadgeTone.pending)
            : (ViewerStrings.openBadge, BuddyBadgeTone.grey);
    final sub = r.isReceived ? ViewerStrings.receivedLine : (r.isSaidPaid && iPay ? ViewerStrings.waitingFor(other) : ViewerStrings.notPaidYet);
    return [
      WhoPaysRowFrame(
        key: ValueKey('former_pay_$key'),
        fromAvatar: _avatar(from, r.fromUserId),
        toAvatar: _avatar(to, r.toUserId),
        title: Text(iPay ? ViewerStrings.youPay(other) : ViewerStrings.paysYou(other),
            maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
        amount: BuddyFormat.rupees(r.amount),
        footerLeft: BuddyBadge(badge, tone: tone),
        footerRight: [
          if (iPay && r.isSaidPaid && r.canWithdraw)
            SmallPill(key: ValueKey('former_not_paid_$key'), label: ViewerStrings.notPaid, kind: SmallPillKind.dangerOutline, busy: _c.busy.contains(key), onTap: () => _withdraw(r)),
        ],
      ),
      if (iPay && r.isOpen && r.canSayPaid)
        Padding(
          padding: DS.insets(l: 18, t: 16, r: 18),
          child: GradientPillButton(
            key: ValueKey('former_say_paid_$key'),
            tone: BuddyLook.rose,
            label: ViewerStrings.iHavePaid,
            loading: _c.busy.contains(key),
            onTap: () => _sayPaid(r),
          ),
        ),
    ];
  }

  static Widget _avatar(MoneyPerson? p, String id) =>
      BuddyAvatar(initial: p?.initial ?? '', seed: id, size: BuddyAvatarSize.xs, photoUrl: p?.photoUrl);
}

class _GoneBanner extends StatelessWidget {
  const _GoneBanner();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('former_banner'),
        margin: DS.insets(l: 18, t: 24, r: 18),
        constraints: BoxConstraints(minHeight: DS.s(64)),
        decoration: BoxDecoration(
          color: ViewerLook.greyBadgeBg,
          borderRadius: DS.br(CardRadius.card),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: DS.s(14),
              top: -DS.s(8),
              child: ExcludeSemantics(child: Art3D(asset: BuddyArt.locked, size: 52, shadowBlur: 3, shadowOffset: const Offset(2, 3))),
            ),
            Padding(
              padding: DS.insets(l: 80, t: 14, r: 16, b: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(ViewerStrings.noLongerOnTrip, style: Ink3D.text(13, FontWeight.w600, ViewerLook.greyBadgeInk, height: 1.45, letterSpacing: 0)),
              ),
            ),
          ],
        ),
      );
}

class _ExpenseLine extends StatelessWidget {
  const _ExpenseLine({required this.item, required this.payer, required this.first});

  final ExpenseItem item;
  final String payer;
  final bool first;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('former_expense_${item.id}'),
        constraints: BoxConstraints(minHeight: DS.s(72)),
        padding: DS.sym(h: 16, v: 12),
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: ViewerLook.line))),
        child: Row(
          children: [
            SizedBox(
              width: DS.s(44),
              height: DS.s(44),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: ViewerLook.expenseTile, borderRadius: DS.circular(14)))),
                  Positioned(
                    left: DS.s(4),
                    top: -DS.s(2),
                    child: ExcludeSemantics(child: Art3D(asset: FormerShareScreen.artOf(item.category), size: 38, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
                  ),
                ],
              ),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w600, ViewerLook.ink, letterSpacing: 0)),
                  Text(ViewerStrings.dayPaidBy(item.dayNumber, payer), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, ViewerLook.grey, letterSpacing: 0)),
                ],
              ),
            ),
            Gap.h(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(BuddyFormat.rupees(item.amount), style: Ink3D.text(15, FontWeight.w700, ViewerLook.ink, letterSpacing: 0)),
                Text(ViewerStrings.yourShareAmount(item.myShare), style: Ink3D.text(11.5, FontWeight.w600, ViewerLook.roseText, letterSpacing: 0)),
              ],
            ),
          ],
        ),
      );
}
