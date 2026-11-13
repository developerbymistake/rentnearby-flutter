import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/listing_contact_actions.dart';
import '../../taxi/guest/taxi_navigation.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_shortlist_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_guide_args.dart';
import '../models/trip_shortlist_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_city.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_arrange_confirm.dart';
import '../widgets/trip_driver_row.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_list_look.dart';
import '../widgets/trip_shortlist_bar.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import 'trip_taxi_enquiry_sheet.dart';

class TripTaxiScreen extends StatefulWidget {
  const TripTaxiScreen({super.key});

  @override
  State<TripTaxiScreen> createState() => _TripTaxiScreenState();
}

class _TripTaxiScreenState extends State<TripTaxiScreen> with TickerProviderStateMixin {
  static const double _maxWidth = 640;

  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  Widget _enter(Widget child, int i, [int count = 6]) => TemplateEntrance(
        animation: templateInterval(_anim, i.clamp(0, count - 1), count),
        animationController: _anim,
        child: child,
      );

  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  final _scroll = ScrollController();
  final _days = <int>{}.obs;
  Worker? _planWorker;
  Worker? _daysWorker;
  GuideArgs? _guide;
  final _noReply = <String>{}.obs;

  TripEasyRowKey get _key => const TripEasyRowKey(TripEasyRowKind.taxi);

  List<int> get _sorted => _days.toList()..sort();

  int get _firstDay => _days.isEmpty ? 1 : _sorted.first;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _plan =TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    _guide = GuideArgs.from(args);
    if (_guide != null) {
      final c = TripShortlistController.to;
      c.load().then((_) {
        if (mounted) _noReply.assignAll(c.noReplyIds(_guide!.stepKey));
      });
    }
    final asked = args is Map ? (args['days'] as List?)?.whereType<int>().toList() : null;
    final all = [for (final d in _plan.plan.value?.days ?? const <TripDay>[]) d.day];
    final start = asked == null || asked.isEmpty ? all : asked.where(all.contains).toList();
    final picked = start.isEmpty ? all : start;
    final coming = picked.where((d) => !_plan.isDayPast(d)).toList();
    _days.assignAll(coming.isEmpty ? picked : coming);
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
    _ensure();
    _planWorker = ever(_plan.plan, (_) => _ensure());
    _daysWorker = ever(_days, (_) => _ensure());
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _daysWorker?.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _anim.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  void _ensure() {
    final p = _plan.plan.value;
    if (p == null) return;
    final day = _firstDay;
    _supply.ensureTaxis(p.legIndexOf(day), day: day);
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _supply.loadMoreTaxis();
  }

  void _toggle(int day) {
    if (_days.contains(day)) {
      if (_days.length == 1) {
        AppToast.warning(TripStringsV2Find.pickDay);
        return;
      }
      _days.remove(day);
    } else {
      _days.add(day);
    }
  }

  String get _cities {
    final p = _plan.plan.value;
    if (p == null) return _plan.cityName;
    final names = <String>[];
    for (final d in _sorted) {
      final n = p.cityNameOf(d);
      if (!names.contains(n)) names.add(n);
    }
    return names.isEmpty ? _plan.cityName : names.join(' + ');
  }

  void _skip() {
    if (_plan.openRowsOf(_key).isNotEmpty || _plan.confirmedRowOf(_key) != null) {
      AppToast.warning(TripStringsV2Find.cancelFirstTaxi);
      return;
    }
    _plan.skipRow(_key);
    TripNavigation.backToPlan();
  }

  Future<void> _arrange() async {
    if (!await TripArrangeConfirm.show(context, _key) || !mounted) return;
    final res = await TripArrangeConfirm.mark(context, _key);
    if (res == null || !mounted) return;
    if (res is TripMarkBlocked) {
      AppToast.warning(TripStringsV2Find.cancelFirstTaxi);
      return;
    }
    TripNavigation.backToPlan();
  }

  void _open(TaxiBrowseItem t) => TaxiNavigation.openDetail(
        t.id,
        whatsAppMessage: _plan.whatsAppMessage(_firstDay, t.driverName),
      );

  Future<void> _call(TaxiBrowseItem t) => ListingContactActions.call(
        context,
        kind: ListingKind.taxi,
        id: t.id,
        detailArguments: {'whatsAppMessage': _plan.whatsAppMessage(_firstDay, t.driverName)},
      );

  TripEnquiryModel? _askedOf(String taxiId) {
    final p = _plan.plan.value;
    if (p == null) return null;
    final leg = p.legIndexOf(_firstDay);
    for (final e in _plan.taxiEnquiries) {
      if (e.listingId != taxiId || !e.isOpen) continue;
      final day = _plan.firstPlanDayOf(e);
      if ((e.cityLeg ?? (day == null ? leg : p.legIndexOf(day))) == leg) return e;
    }
    return null;
  }

  Future<void> _ask(TaxiBrowseItem t) async {
    final asked = _askedOf(t.id);
    if (asked != null) {
      await TripNavigation.openTaxiReplies(_plan.firstPlanDayOf(asked) ?? _firstDay, enquiryId: asked.id);
      return;
    }
    await TripTaxiEnquirySheet.show(context, driver: t, days: _sorted);
  }

  Future<void> _done() => TripShortlistFlow.done(
        context,
        step: _guide!.stepKey,
        taxi: true,
        send: () => TripShortlistController.to.sendTaxis(step: _guide!.stepKey, days: _sorted),
      );

  Future<void> _book(TaxiBrowseItem t) async {
    final e = _askedOf(t.id);
    await TripTaxiBookingSheet.show(context, taxi: t, day: _firstDay, enquiry: e, initialFare: e?.taxi?.driverFare);
  }

  void _clearFilters() {
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
  }

  Widget _narrow(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  Widget _dayChip(int day) {
    final date = _plan.dateOf(day);
    final label = date == null ? TripStrings.dayN(day) : '${TripStrings.dayN(day)} · ${TripFormat.shortDate(date)}';
    final locked = _plan.isDayPast(day);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: TripChoiceChip(
        label: label,
        selected: _days.contains(day),
        muted: locked,
        onTap: () {
          if (!locked) _toggle(day);
        },
        activeColor: TripUi.taxi,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _dayChips() {
    final p = _plan.plan.value;
    if (p == null) return const SizedBox.shrink();
    final groups = <Widget>[];
    for (var k = 1; k <= p.legCount; k++) {
      final days = p.daysOf(k);
      if (days.isEmpty) continue;
      groups.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.isMultiCity)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 6),
              child: Text(p.cityNameOf(days.first.day),
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkText)),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final d in days) _dayChip(d.day)]),
        ],
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(TripStringsV2Find.taxiDays,
          style: TextStyle(
              fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: FitnessAppTheme.darkText)),
      const SizedBox(height: 4),
      ...groups,
      const SizedBox(height: 4),
      const Text(TripStringsV2Find.taxiDayNote,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.darkText)),
    ]);
  }

  Widget _buildTop() => Obx(() {
        _plan.plan.value;
        _days.length;
        final showChips = !_plan.isReadOnly && _supply.taxis.isNotEmpty;
        return _enter(_narrow(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dayChips(),
              if (showChips) ...[
                const SizedBox(height: 12),
                TripFilterChips(accent: TripUi.taxi, items: [
                  TripFilterChip(
                    label: TripStringsA3.seats4,
                    selected: _supply.minSeats.value == 4,
                    onTap: () => _supply.minSeats.value = _supply.minSeats.value == 4 ? null : 4,
                  ),
                  TripFilterChip(
                    label: TripStringsA3.seats6,
                    selected: _supply.minSeats.value == 6,
                    onTap: () => _supply.minSeats.value = _supply.minSeats.value == 6 ? null : 6,
                  ),
                  TripFilterChip(
                    label: TripStringsA3.suv,
                    selected: _supply.onlySuv.value,
                    onTap: () => _supply.onlySuv.value = !_supply.onlySuv.value,
                  ),
                ]),
              ],
            ],
          ),
        )), 0);
      });

  Widget _stateBox({
    IconData? icon,
    String? asset,
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return SliverToBoxAdapter(
      child: _narrow(Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: _enter(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(color: FitnessAppTheme.white, borderRadius: CardRadius.tile, boxShadow: ShadowTokens.elev1),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: KitTone.taxi.gradient, boxShadow: ShadowTokens.glow(TripUi.taxi)),
                  child: Center(child: asset != null ? TravelIcon(asset, size: 40) : Icon(icon, size: 30, color: FitnessAppTheme.white)),
                ),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        color: FitnessAppTheme.darkerText)),
                const SizedBox(height: 6),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w500, color: FitnessAppTheme.lightText)),
                for (final a in actions) ...[const SizedBox(height: 12), a],
              ],
            ),
          ),
          2,
        ),
      )),
    );
  }

  Widget _pill(VoidCallback onTap, Color border, Widget child) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: FitnessAppTheme.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border, width: 1.5),
            boxShadow: ShadowTokens.elev1,
          ),
          child: child,
        ),
      );

  Widget _outlinedAction(String label, Widget icon, VoidCallback onTap) => _pill(
        onTap,
        TripUi.taxi,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: TripUi.taxiDark)),
            ),
          ],
        ),
      );

  Widget _skipButton() => _pill(
        _skip,
        TripUi.good,
        const Text(TripStringsV2Find.skip,
            style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: TripUi.good)),
      );

  Widget _shimmerList() => SliverPadding(
        padding: EdgeInsets.zero,
        sliver: SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemBuilder: (_, i) => _enter(_narrow(const TripDriverRowSkeleton()), i, 4),
        ),
      );

  Widget _buildBody() => Obx(() {
        _plan.plan.value;
        _plan.enquiryList.length;
        _days.length;
        if (_plan.isReadOnly) {
          final hasReplies = _plan.taxiEnquiries.isNotEmpty;
          return _stateBox(
            asset: TravelIcon.calendar,
            title: TripStringsA3.pastTripTitle,
            subtitle: TripStringsA3.readOnlyBody,
            actions: [
              if (hasReplies)
                _outlinedAction(TripStrings.taxiReplies, const TravelIcon(TravelIcon.chat, size: 20), () => TripNavigation.openRepliesForRow(_key)),
            ],
          );
        }
        final items = _supply.taxis;
        if (items.isEmpty && _supply.citiesUnavailable.value && !_plan.taxiTabOff.value) {
          return SliverToBoxAdapter(
            child: TripEmpty(
              asset: TravelIcon.taxi,
              tone: KitTone.taxi,
              error: true,
              title: TripStringsCity.citiesLoadingTitle,
              subtitle: TripStringsCity.citiesLoadingBody,
              onRetry: () => _supply.loadTaxis(),
              retryLabel: TripStringsCity.tryAgain,
            ),
          );
        }
        if (items.isEmpty && _supply.taxiDistrictId == null && !_plan.taxiTabOff.value) {
          if (_plan.trip.value == null) return _shimmerList();
          return _stateBox(
            asset: TravelIcon.taxi,
            title: TripStringsV2Find.noTaxiTitle,
            subtitle: TripStringsV2Find.noTaxiBody,
            actions: [_outlinedAction(TripStringsV2Find.arrangeMyself, const TravelIcon(TravelIcon.taxi, size: 20), _arrange), _skipButton()],
          );
        }
        if (items.isEmpty) {
          if (_supply.taxiLoading.value) return _shimmerList();
          if (_supply.taxiFailed.value) {
            return SliverToBoxAdapter(
              child: TripEmpty(
                asset: TravelIcon.taxi,
                tone: KitTone.taxi,
                error: true,
                title: TripStringsV2Find.taxisFailed,
                subtitle: TripStringsV2Find.checkConnection,
                onRetry: () => _supply.loadTaxis(),
                retryLabel: TripStringsV2Find.retry,
              ),
            );
          }
          return _stateBox(
            asset: TravelIcon.taxi,
            title: _plan.taxiTabOff.value ? TripStringsV2Find.taxisPaused : TripStringsV2Find.noTaxiTitle,
            subtitle: TripStringsV2Find.noTaxiBody,
            actions: [
              _outlinedAction(TripStringsV2Find.arrangeMyself, const TravelIcon(TravelIcon.taxi, size: 20), _arrange),
              _skipButton(),
              if (!_plan.taxiTabOff.value)
                TextLink(label: TripStrings.seeAllTaxis, onTap: () => TaxiNavigation.openList(), tone: KitTone.trip),
            ],
          );
        }
        final guide = _guide;
        final shortlist = TripShortlistController.to;
        final raw = _supply.filteredTaxis;
        final list = guide == null
            ? raw
            : ShortlistOrder.noReplyLast(raw, (t) => t.id, _noReply.toSet());
        if (list.isEmpty) {
          return _stateBox(
            icon: Icons.filter_list_rounded,
            title: TripStringsA3.noMatchTitle,
            subtitle: TripStringsA3.noMatchBody,
            actions: [_outlinedAction(TripStringsA3.clearFilters, const Icon(Icons.close_rounded, size: 20, color: TripUi.taxiDark), _clearFilters)],
          );
        }
        final n = _days.length;
        return SliverPadding(
          padding: EdgeInsets.zero,
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox.shrink(),
            itemBuilder: (_, i) {
              final t = list[i];
              final asked = _askedOf(t.id);
              return _enter(_narrow(Obx(() => TripDriverRow(
                    key: ValueKey('${t.id}-$n'),
                    item: t,
                    tone: ListingTone.list(ListingTone.coral, i),
                    fit: _supply.taxiFitOf(t.id),
                    status: asked?.display,
                    days: n,
                    contactBusy: ListingContactActions.isBusy(ListingKind.taxi, t.id),
                    onOpen: () => _open(t),
                    onCall: () => _call(t),
                    onAsk: () => _ask(t),
                    menuItems: _menu(),
                    onMenu: (v) => v == 1 ? _book(t) : _open(t),
                    onShortlist: guide == null
                        ? null
                        : () => shortlist.toggle(
                              step: guide.stepKey,
                              kind: ShortlistKinds.taxi,
                              listingId: t.id,
                              name: t.driverName,
                              legIndex: _plan.plan.value?.legIndexOf(_firstDay),
                            ),
                    shortlisted: guide != null && shortlist.has(guide.stepKey, t.id),
                    shortlistBusy: guide != null && shortlist.isBusy(guide.stepKey, t.id),
                    noReply: guide != null && _noReply.contains(t.id),
                  ))), i + 1);
            },
          ),
        );
      });

  List<PopupMenuEntry<int>> _menu() {
    PopupMenuItem<int> item(int v, Widget icon, String label) => PopupMenuItem<int>(
          value: v,
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.darkerText)),
              ),
            ],
          ),
        );
    return [
      item(1, const Icon(Icons.receipt_long_outlined, size: 20, color: TripUi.taxiDark), TripStringsA3.iBookedThis),
      item(2, const Icon(Icons.visibility_outlined, size: 20, color: TripUi.taxiDark), TripStringsA3.viewDetails),
    ];
  }

  Widget _buildFooter() => Obx(() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: SizedBox(
          height: 24,
          child: _supply.taxiLoadingMore.value
              ? const Center(child: KitDots(color: TripUi.taxi))
              : null,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) TripNavigation.backToPlan();
      },
      child: Scaffold(
        backgroundColor: ListingPalette.coral.page,
        bottomNavigationBar: _guide == null || _plan.isReadOnly ? null : TripShortlistBar(step: _guide!.stepKey, onDone: _done, tone: KitTone.taxi),
        body: Column(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(parent: _anim, curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn))),
              child: Obx(() {
              _plan.plan.value;
              _days.length;
              return TripListTopBar(
                tone: ListingTone.coral,
                title: TripStringsV2Find.taxiTitle,
                subtitle: TripStringsV2Find.taxiSubtitle(_cities),
                onBack: TripNavigation.backToPlan,
                guide: _guide,
                skipLabel: _plan.isReadOnly || _guide != null ? null : TripStringsV2Find.skip,
                onSkip: _skip,
              );
            })),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _buildTop()),
                  _buildBody(),
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
