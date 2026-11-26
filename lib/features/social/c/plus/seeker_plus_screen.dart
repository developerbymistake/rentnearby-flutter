import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_plans.dart';
import '../../../../design/extra/page_header_3d.dart';
import '../../../../models/plan_purchase_result.dart';
import '../../../../widgets/plan_compare_table.dart';
import '../../../../widgets/plan_subscription_card.dart';
import '../../../../widgets/purchase_status_sheet.dart';
import '../../../buddy/shared/buddy_format.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../shared/social_strings.dart';
import '../social_strings_c.dart';
import 'seeker_plus_controller.dart';

class SeekerPlusScreen extends StatefulWidget {
  const SeekerPlusScreen({super.key, this.from, this.controller});

  final String? from;
  final SeekerPlusController? controller;

  @override
  State<SeekerPlusScreen> createState() => _SeekerPlusScreenState();
}

class _SeekerPlusScreenState extends State<SeekerPlusScreen> {
  static int _seq = 0;
  late final String _tag = 'seeker_plus_${_seq++}';
  late final SeekerPlusController _c;
  Worker? _purchaseWorker;
  bool _sheetOpen = false;

  ListingTone get _tone => ListingTone.indigo;

  @override
  void initState() {
    super.initState();
    _c = Get.put(widget.controller ?? SeekerPlusController(from: widget.from), tag: _tag);
    _purchaseWorker = ever<PurchaseStatus?>(_c.plans.activePurchase, (v) {
      if (v == null) {
        if (_sheetOpen && mounted) Navigator.of(context).pop();
        return;
      }
      _showStatus();
    });
  }

  @override
  void dispose() {
    _purchaseWorker?.dispose();
    Get.delete<SeekerPlusController>(tag: _tag, force: true);
    super.dispose();
  }

  void _showStatus() {
    if (!mounted || _sheetOpen || _c.plans.activePurchase.value == null) return;
    _sheetOpen = true;
    showDockSheet<void>(
      context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      barrierColor: PlanInk.scrim,
      builder: (_) => PurchaseStatusSheet(accent: _tone.g2, tone: _tone),
    ).whenComplete(() {
      _sheetOpen = false;
      _c.plans.dismissPurchase();
      _c.afterPurchase();
    });
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final plans = _c.plans;
        final loading = plans.isLoadingCatalog.value && plans.catalog.value == null;
        final plus = _c.plusPlan;
        final isPlus = _c.isPlus;
        return BuddyPage(
          title: SocialStringsC.plusTitle,
          header: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: PageHeader3D(key: const ValueKey('plus_page_header'), tone: ListingTone.cF, title: SocialStringsC.plusTitle, art: ListingArt.moneyBag, onBack: () => Get.back()),
            ),
          ),
          body: loading
              ? _skeleton()
              : plus == null
                  ? Padding(
                      padding: DS.gapInsets(t: 24),
                      child: StateCard.error(title: SocialStringsC.plansLoadFailed, actionLabel: SocialStrings.retry, onAction: () => _c.load(force: true)),
                    )
                  : _content(isPlus),
          bottomBar: plus == null || loading ? null : (isPlus ? _subscribedBar() : _buyBar()),
        );
      });

  Widget _skeleton() => Padding(
        padding: DS.gapInsets(l: 18, t: 16, r: 18),
        child: Column(children: [
          for (var i = 0; i < 3; i++) ...[SkeletonBox(height: DS.s(84), radius: DS.radius(16)), Gap.v(16)],
        ]),
      );

  Widget _content(bool isPlus) {
    final cycles = _c.cycles;
    final selected = _c.selected.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: DS.gapInsets(l: 22, t: 4, r: 22, b: 12),
          child: Text(SocialStringsC.autoRenew, style: Ink3D.text(14, FontWeight.w400, BuddyLook.subText, letterSpacing: 0)),
        ),
        if (_c.pausedCount > 0)
          Padding(
            padding: DS.gapInsets(l: 22, r: 22, b: 12),
            child: Text(SocialStringsC.pausedLine(_c.pausedCount),
                key: const ValueKey('plus_paused_line'), style: Ink3D.text(14, FontWeight.w400, BuddyLook.subText, letterSpacing: 0)),
          ),
        if (_c.seekerPlan case final me? when me.play != null)
          PlanSubscriptionCard(
            key: const ValueKey('plus_lifecycle_card'),
            me: me,
            accent: PlanAccent.of(me.featureKey),
            state: _c.state,
            onSubscribeAgain: _c.canBuy ? _c.subscribe : null,
          ),
        if (!isPlus)
          for (final m in cycles) _planCard(m, selected == m),
        _perksCard(),
        Gap.v(14),
      ],
    );
  }

  static String _cycleLabel(int m) => switch (m) {
        12 => SocialStringsC.months12,
        3 => SocialStringsC.months3,
        _ => SocialStringsC.month1,
      };

  static String _priceLine(int m, String price) => switch (m) {
        12 => SocialStringsC.priceYear(price),
        3 => SocialStringsC.priceFor3(price),
        _ => SocialStringsC.priceMonth(price),
      };

  static String _art(int m) => switch (m) {
        12 => ListingArt.star,
        3 => ListingArt.alarmClock,
        _ => ListingArt.calendar,
      };

  static BorderRadius get _cardRadius => DS.br(CardRadius.card);

  static BorderRadius get _ringRadius => DS.br(const BorderRadius.all(Radius.circular(CardRadius.uniformValue + 5)));

  Widget _planCard(int months, bool on) {
    final c = _c.cycle(months);
    if (c == null) return const SizedBox.shrink();
    final ink = on ? DesignColors.onPrimary : Ink3D.title;
    final best = months == SeekerPlusController.cycleOrder.first;
    return Padding(
      padding: DS.gapInsets(l: 13, t: best ? 12 : 0, r: 13, b: 11),
      child: Tap3D(
        key: ValueKey('plus_cycle_$months'),
        onTap: () => _c.select(months),
        selected: on,
        label: '${_cycleLabel(months)}, ${_priceLine(months, c.price)}',
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              key: ValueKey('plus_ring_$months'),
              padding: DS.all(3),
              decoration: BoxDecoration(
                borderRadius: _ringRadius,
                border: Border.all(color: on ? _tone.g2.withValues(alpha: Alpha.half) : Colors.transparent, width: DS.s(2)),
              ),
              child: Container(
              padding: DS.insets(l: 18, t: 16, r: 18, b: 16),
              decoration: BoxDecoration(
                gradient: on ? _tone.gradient : null,
                color: on ? null : DesignColors.surface,
                borderRadius: _cardRadius,
                border: on ? Border.all(color: DesignColors.surface, width: DS.s(3)) : null,
                boxShadow: on ? _tone.glow(dy: 8, blur: 14) : BuddyLook.cardShadows(DS.size),
              ),
              child: Row(
                children: [
                  Image.asset(_art(months), width: DS.s(48), height: DS.s(48)),
                  Gap.h(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_cycleLabel(months), style: Ink3D.text(14, FontWeight.w600, ink, letterSpacing: 0)),
                        Text(_priceLine(months, c.price), key: ValueKey('plus_price_$months'), style: Ink3D.text(22, FontWeight.w700, ink, height: 1.25, letterSpacing: 0)),
                        if (c.perMonth != null)
                          Text(SocialStringsC.perMonthAbout(c.perMonth!),
                              key: ValueKey('plus_per_month_$months'), style: Ink3D.text(12.5, FontWeight.w400, on ? DesignColors.onPrimary : BuddyLook.greyText, letterSpacing: 0)),
                      ],
                    ),
                  ),
                  Gap.h(10),
                  Container(
                    width: DS.s(26),
                    height: DS.s(26),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? DesignColors.surface : null,
                      border: on ? null : Border.all(color: BuddyLook.checkOff, width: DS.s(2)),
                    ),
                    child: on ? Icon(Icons.check_rounded, size: DS.s(16), color: _tone.g2) : null,
                  ),
                ],
              ),
            ),
            ),
            if (best)
              Positioned(
                right: DS.s(18),
                top: -DS.s(11),
                child: Container(
                  padding: DS.sym(h: 10, v: 2),
                  decoration: BoxDecoration(color: ListingTone.cF.g2, borderRadius: DS.circular(8)),
                  child: Text(SocialStringsC.bestValue, style: Ink3D.text(11.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _perksCard() {
    final perks = _c.perks();
    return Container(
      margin: DS.gapInsets(l: 18, t: 2, r: 18),
      padding: DS.insets(l: 18, t: 16, r: 18, b: 16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(16), boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SocialStringsC.whatYouGet, style: Ink3D.text(16, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
          Gap.v(4),
          for (var i = 0; i < perks.length; i++)
            Container(
              padding: DS.sym(v: 9),
              decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: BuddyLook.hairline))),
              child: Row(children: [
                Image.asset(perks[i].art, width: DS.s(34), height: DS.s(34)),
                Gap.h(12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(perks[i].title, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    if (perks[i].subtitle case final sub?) Text(sub, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                  ]),
                ),
              ]),
            ),
          Gap.v(8),
          Text(SocialStringsC.alwaysFree, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.subText, letterSpacing: 0, height: 1.5)),
        ],
      ),
    );
  }

  Widget _bar({required List<Widget> children}) => Container(
        padding: DS.insets(l: 18, t: 16, r: 18, b: 16) + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))),
          boxShadow: BuddyLook.cardShadows(DS.size),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  static String _renew(int m, String price) => switch (m) {
        12 => SocialStringsC.renewYear(price),
        3 => SocialStringsC.renew3(price),
        _ => SocialStringsC.renewMonth(price),
      };

  Widget _buyBar() {
    final m = _c.selected.value;
    final c = _c.cycle(m);
    final canBuy = _c.canBuy && c != null;
    return _bar(children: [
      if (c != null) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(SocialStringsC.footerTitle(_cycleLabel(m)), style: Ink3D.text(14, FontWeight.w500, BuddyLook.subText, letterSpacing: 0))),
            Text(SocialStringsC.footerToday(c.price), key: const ValueKey('plus_footer_price'), style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ],
        ),
        Padding(
          padding: DS.insets(t: 2, b: 12),
          child: Text(_renew(m, c.price), style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
        ),
      ],
      if (!_c.plans.paymentEnabled)
        Padding(
          padding: DS.insets(b: 10),
          child: Text(SocialStringsC.plusUnavailable, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w500, BuddyLook.subText, letterSpacing: 0)),
        ),
      GradientPillButton(
        key: const ValueKey('plus_subscribe'),
        tone: _tone,
        label: SocialStringsC.subscribe,
        loading: _c.plans.isPurchasing.value,
        enabled: canBuy,
        onTap: canBuy ? _c.subscribe : null,
      ),
    ]);
  }

  Widget _subscribedBar() {
    final ends = _c.plans.myPlan.value.endsAt;
    return _bar(children: [
      Text(SocialStringsC.youArePlus, key: const ValueKey('plus_subscribed'), textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
      if (ends != null)
        Padding(
          padding: DS.insets(t: 2),
          child: Text(SocialStringsC.plusUntil(BuddyFormat.dayMonth(ends)), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
        ),
      Gap.v(12),
      GradientPillButton(key: const ValueKey('plus_manage'), tone: _tone, label: SocialStringsC.manage, onTap: _c.manage),
      Tap3D(
        onTap: _c.plans.isRestoring.value ? null : _c.restore,
        label: SocialStringsC.restore,
        exclude: true,
        child: Padding(
          padding: DS.sym(v: 10),
          child: Text(SocialStringsC.restore, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0)),
        ),
      ),
    ]);
  }
}

