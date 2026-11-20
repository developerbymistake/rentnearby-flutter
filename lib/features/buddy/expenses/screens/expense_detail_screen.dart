import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../../trip/widgets/trip_ui.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/money_name.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/expense_detail_controller.dart';
import '../controllers/expense_sheet_controller.dart';
import '../data/expense_write_gateway.dart';
import '../data/expenses_api.dart';
import '../expense_deps.dart';
import '../expense_look.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';
import '../widgets/expense_delete_dialog.dart';
import '../widgets/expense_form_parts.dart';
import '../widgets/expense_history_list.dart';
import '../widgets/expense_sheet.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, required this.tripId, required this.expenseId, this.api, this.gateway, this.initial, this.context});

  static const Key editKey = ValueKey('expense_detail_edit');
  static const Key menuKey = ValueKey('expense_detail_menu');
  static const Key backKey = ValueKey('expense_detail_back');

  final String tripId;
  final String expenseId;
  final ExpensesApi? api;
  final ExpenseWriteGateway? gateway;
  final ExpenseDetailPage? initial;
  final ExpenseList? context;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late final String _tag = '${widget.tripId}_${widget.expenseId}';
  late final ExpenseDetailController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(
      ExpenseDetailController(widget.tripId, widget.expenseId, api: widget.api, gateway: widget.gateway, initial: widget.initial, context: widget.context),
      tag: _tag,
    );
    c.reload();
  }

  @override
  void dispose() {
    Get.delete<ExpenseDetailController>(tag: _tag);
    super.dispose();
  }

  void _back([Object? result]) => Navigator.of(context).maybePop(result);

  Future<ExpenseList?> _tripContext() async {
    final known = c.trip.value;
    if (known != null) return known;
    final r = await c.api.list(widget.tripId, limit: 1);
    if (r is BuddyOk<ExpenseList>) {
      c.trip.value = r.value;
      return r.value;
    }
    ExpenseDeps.offline();
    return null;
  }

  Future<void> _edit() async {
    final page = c.page.value;
    if (page == null || !c.canEdit) return;
    final trip = await _tripContext();
    if (trip == null || !mounted) return;
    final end = await ExpenseSheet.show(
      context,
      ExpenseSheetSetup.fromList(trip, edit: page.expense, extra: page.people),
      api: widget.api,
      gateway: widget.gateway,
    );
    if (!mounted || end == null) return;
    switch (end) {
      case SheetSaveEnd.saved:
        ExpenseDeps.snack(context, ExpenseStrings.saved);
      case SheetSaveEnd.closeFrozen:
        ExpenseDeps.toast(ExpenseStrings.frozenToast);
      default:
        break;
    }
    BuddyLive.expenses(widget.tripId).value++;
    await c.reload();
  }

  Future<void> _delete() async {
    final end = await ExpenseDeleteDialog.show(context, c);
    if (!mounted || end == null) return;
    switch (end) {
      case DeleteEnd.deleted:
        _back();
        ExpenseDeps.snack(null, ExpenseStrings.deleted);
      case DeleteEnd.queued || DeleteEnd.gone:
        _back();
      case DeleteEnd.frozen:
        ExpenseDeps.toast(ExpenseStrings.frozenToast);
        await c.reload();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final page = c.page.value;
        final status = c.status.value;
        c.trip.value;
        if (status == DetailLoad.gone) {
          return BuddyPage(title: ExpenseStrings.expense, scroll: false, body: _state(ExpenseStrings.gone, back: true));
        }
        if (page == null) {
          return BuddyPage(
            title: ExpenseStrings.expense,
            scroll: false,
            body: status == DetailLoad.failed ? _state(BuddySharedStrings.couldNotLoad, retry: true) : const Center(child: CircularProgressIndicator()),
          );
        }
        final e = page.expense;
        return BuddyPage(
          title: ExpenseStrings.expense,
          subtitle: ExpenseStrings.dayDate(e.dayNumber, e.date),
          trailing: [
            if (c.canEdit) TripHeaderAction(key: ExpenseDetailScreen.editKey, label: ExpenseStrings.edit, onTap: _edit),
            if (c.canDelete) _menu(),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _top(e),
              if (e.deleted)
                Padding(
                  padding: DS.insets(l: 22, t: 10, r: 22),
                  child: Text(ExpenseStrings.deletedLine, style: Ink3D.text(13, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
                ),
              if (page.history.isNotEmpty) ExpenseHistoryList(history: page.history, nameOf: (id) => c.person(id)?.name ?? BuddySharedStrings.someone),
            ],
          ),
        );
      });

  Widget _menu() => PopupMenuButton<int>(
        key: ExpenseDetailScreen.menuKey,
        tooltip: ExpenseStrings.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (_) => _delete(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(value: 0, child: Text(ExpenseStrings.delete, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText))),
        ],
        child: TripMenuDots.box(),
      );

  Widget _top(ExpenseDetail e) {
    final link = e.link;
    final payer = c.person(e.paidByUserId);
    final note = e.note;
    final rowName = Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0);
    return Container(
      margin: DS.insets(l: 18, t: 20, r: 18),
      padding: DS.sym(h: 18, v: 16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: ExpenseShape.corner(54), boxShadow: ExpenseShape.card()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: ExpenseLook.categoryArt(e.category), size: 56, shadowBlur: 4, shadowOffset: const Offset(3, 5))),
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(BuddyFormat.rupees(e.amount), style: Ink3D.text(30, FontWeight.w700, Ink3D.title, height: 1.15, letterSpacing: 0)),
                    Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, ExpenseLook.label, letterSpacing: 0)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: DS.insets(t: 10, b: 6),
            child: Wrap(
              spacing: DS.s(8),
              runSpacing: DS.s(8),
              children: [
                BuddyBadge(e.category, tone: BuddyBadgeTone.owner),
                BuddyBadge(
                  link == null
                      ? ExpenseStrings.dayChip(e.dayNumber)
                      : ExpenseStrings.linkDay(link.kind == ExpenseLinkKind.taxi ? ExpenseStrings.bookedTaxi : ExpenseStrings.bookedStay, e.dayNumber),
                  tone: BuddyBadgeTone.view,
                ),
                if (link?.cancelled ?? false) const BuddyBadge(ExpenseStrings.tagBookingCancelled, tone: BuddyBadgeTone.danger),
                if (e.editedTimes > 0) BuddyBadge(ExpenseStrings.editedTimes(e.editedTimes)),
              ],
            ),
          ),
          _line(
            Row(
              children: [
                Expanded(child: Text(ExpenseStrings.paidByLabel, style: Ink3D.text(13, FontWeight.w400, ExpenseLook.copy, letterSpacing: 0))),
                if (payer != null)
                  MoneyName(person: payer, showYou: false, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0))
                else
                  Text(BuddyFormat.deletedName, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              ],
            ),
            v: 10,
          ),
          for (final s in e.shares)
            _line(
              Row(
                children: [
                  BuddyAvatar(initial: c.person(s.userId)?.initial ?? '?', seed: s.userId, size: BuddyAvatarSize.sm),
                  Gap.h(10),
                  Expanded(child: _personName(c.person(s.userId), rowName)),
                  Text(BuddyFormat.rupees(s.share), style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                ],
              ),
              v: 8,
            ),
          if (note != null && note.isNotEmpty)
            _line(
              Row(
                children: [
                  Container(
                    width: DS.s(52),
                    height: DS.s(52),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [ExpenseLook.thumbTop, ExpenseLook.thumbBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: DS.circular(12),
                      border: Border.all(color: ExpenseLook.thumbEdge, width: DS.s(1)),
                    ),
                    child: Image.asset(ExpenseLook.memo, width: DS.s(32)),
                  ),
                  Gap.h(12),
                  Expanded(child: Text(ExpenseStrings.noteLine(note), style: Ink3D.text(13, FontWeight.w400, BuddyLook.subText, letterSpacing: 0))),
                ],
              ),
              v: 10,
              bottom: 0,
            ),
        ],
      ),
    );
  }

  Widget _personName(MoneyPerson? p, TextStyle style) =>
      p == null ? Text(BuddyFormat.deletedName, style: style) : MoneyName(person: p, showYou: false, style: style);

  Widget _line(Widget child, {required double v, double? bottom}) => Container(
        padding: DS.insets(t: v, b: bottom ?? v),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: BuddyLook.hairline, width: DS.s(1)))),
        child: child,
      );

  Widget _state(String title, {bool back = false, bool retry = false}) => Center(
        child: Padding(
          padding: DS.sym(h: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Art3D(asset: ExpenseLook.moneyBag, size: 72, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
              Gap.v(12),
              Text(title, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Gap.v(14),
              if (back) SmallPill(key: ExpenseDetailScreen.backKey, label: ExpenseStrings.back, onTap: _back),
              if (retry) SmallPill(label: BuddySharedStrings.retry, onTap: c.reload),
            ],
          ),
        ),
      );
}

