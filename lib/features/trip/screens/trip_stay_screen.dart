import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../stay/models/stay_nearby_model.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_shortlist_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_guide_args.dart';
import '../models/trip_shortlist_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a2.dart';
import '../trip_strings_fin_b1.dart';
import '../trip_strings_v2_easy.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_clock.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_arrange_confirm.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_shortlist_bar.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_status.dart';
import '../widgets/trip_stay_row.dart';
import 'trip_stay_enquiry_sheet.dart';

class TripStayScreen extends StatefulWidget {
  const TripStayScreen({super.key});

  @override
  State<TripStayScreen> createState() => _TripStayScreenState();
}

class _TripStayScreenState extends State<TripStayScreen> with TickerProviderStateMixin {
  static const double _maxWidth = 640;
  static const int _nightPreview = 3;

  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  late final int _leg;
  GuideArgs? _guide;
  final _noReply = <String>{}.obs;
  final _split = false.obs;
  final _expanded = <int>{}.obs;
  List<int> _only = const [];
  Worker? _planWorker;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    _leg = (map['legIndex'] as int?) ?? 1;
    final p = _plan.plan.value;
    final from = p?.legStart(_leg) ?? 1;
    final count = p?.legDayCount(_leg) ?? 1;
    final only = map['onlyDays'];
    if (only is List) {
      _only = [
        for (final d in only.whereType<int>().toSet())
          if (d >= from && d < from + count && !_plan.isDayPast(d)) d,
      ]..sort();
    }
    _guide = GuideArgs.from(map);
    _split.value = _guide == null && (_only.isNotEmpty || (map['split'] == true && count != 1));
    if (_guide != null) {
      final c = TripShortlistController.to;
      c.load().then((_) {
        if (mounted) _noReply.assignAll(c.noReplyIds(_guide!.stepKey));
      });
    }
    _supply.setNear((map['nearLat'] as num?)?.toDouble(), (map['nearLng'] as num?)?.toDouble());
    _supply.ensureStays(_leg);
    _planWorker = ever(_plan.plan, (_) => _supply.ensureStays(_leg));
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _anim.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  TripEasyRowKey get _key => TripEasyRowKey(TripEasyRowKind.stay, _leg);

  int get _firstDay => _plan.plan.value?.legStart(_leg) ?? 1;

  int get _nights => _plan.plan.value?.legDayCount(_leg) ?? 1;

  int get _pastNights {
    final today = TripClock.today();
    var n = 0;
    for (var i = 0; i < _nights - 1; i++) {
      final d = _plan.dateOf(_firstDay + i);
      if (d != null && d.isBefore(today)) n++;
    }
    return n;
  }

  String get _city {
    final p = _plan.plan.value;
    return p == null ? _plan.cityName : p.cityNameOf(_firstDay);
  }

  bool get _noSupply =>
      _plan.stayTabOff.value || (!_plan.supplyAvailableFor(_firstDay) && !_plan.supplyPendingFor(_firstDay));

  void _skip() {
    _plan.skipRow(_key);
    TripNavigation.backToPlan();
  }

  Future<void> _arrange() async {
    if (!await TripArrangeConfirm.show(context, _key) || !mounted) return;
    final res = await TripArrangeConfirm.mark(context, _key);
    if (res == null || !mounted) return;
    if (res is TripMarkBlocked) {
      AppToast.warning(TripStringsV2Find.cancelFirstStay);
      return;
    }
    TripNavigation.backToPlan();
  }

  String _subtitle() {
    if (_only.isNotEmpty) return TripStringsV2Find.nightsLeft(_only.length);
    final p = _plan.plan.value;
    final first = _plan.dateOf(_firstDay);
    String? range;
    if (first != null && p != null) {
      range = TripStringsV2Easy.stayDates(first, DateTime(first.year, first.month, first.day + _nights));
    }
    final people = _plan.settings.peopleCount;
    return TripStringsV2Find.staySubtitle(_nights, range, people > 0 ? TripStrings.peopleText(people) : null);
  }

  Future<void> _pickPrice() async {
    final picked = await TripSheetFrame.show<int>(context, _PriceBody(current: _supply.maxPrice.value));
    if (picked == null) return;
    _supply.maxPrice.value = picked == 0 ? null : picked;
  }

  List<TripFilterChip> _chips() {
    final max = _supply.maxPrice.value;
    final canSplit = _guide == null && _only.isEmpty && _nights - _pastNights > 1 && !_plan.isReadOnly;
    return [
      if (canSplit)
        TripFilterChip(
          label: TripStringsV2Find.nightByNight,
          selected: _split.value,
          iconAsset: TravelIcon.calendar,
          onTap: () => _split.value = !_split.value,
        ),
      TripFilterChip(
        label: max == null ? TripStringsA2.maxPrice : TripStringsA2.underPrice(BrowseItem.inr(max)),
        selected: max != null,
        iconAsset: TravelIcon.money,
        onTap: _pickPrice,
      ),
      TripFilterChip(
        label: TripStringsA2.homestay,
        selected: _supply.onlyHomestay.value,
        onTap: () => _supply.onlyHomestay.toggle(),
      ),
      if (_supply.hostelAvailable.value)
        TripFilterChip(
          label: TripStringsA2.hostel,
          selected: _supply.onlyHostel.value,
          onTap: () => _supply.onlyHostel.toggle(),
        ),
      if (_supply.hasStayFilters)
        TripFilterChip(
          label: TripStringsA2.clearFilters,
          selected: false,
          icon: Icons.filter_alt_off_rounded,
          onTap: _supply.clearStayFilters,
        ),
    ];
  }

  Widget _enter(Widget child, int i, [int count = 7]) => TemplateEntrance(
        animation: templateInterval(_anim, i.clamp(0, count - 1), count),
        animationController: _anim,
        child: child,
      );

  Widget _box(Widget child) => SliverToBoxAdapter(
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child)),
      );

  Widget _skeletons() => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: 4,
          itemBuilder: (_, i) => _enter(
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: const TripStayRowSkeleton(),
              ),
            ),
            i,
            4,
          ),
        ),
      );

  Widget _noSupplyView() {
    final paused = _plan.stayTabOff.value;
    return Padding(
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
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: KitTone.stay.gradient, boxShadow: ShadowTokens.glow(TripUi.stay)),
                child: const Center(child: TravelIcon(TravelIcon.stay, size: 40)),
              ),
              const SizedBox(height: 16),
              Text(paused ? TripStringsV2Find.staysPaused : TripStringsV2Find.noStaysTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: FitnessAppTheme.darkerText)),
              const SizedBox(height: 6),
              Text(TripStringsV2Find.noStaysBody(_city),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w500, color: FitnessAppTheme.lightText)),
              if (!_plan.isReadOnly) ...[
                const SizedBox(height: 16),
                TripButton(
                  onPressed: _arrange,
                  label: TripStringsV2Find.arrangeMyself,
                  height: 48,
                  gradient: KitTone.stay.gradient,
                  shadowColor: TripUi.stay,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _skip,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FitnessAppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: TripUi.good, width: 1.5),
                    ),
                    child: const Text(TripStringsV2Find.skip,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName, fontSize: 14, fontWeight: FontWeight.w700, color: TripUi.good)),
                  ),
                ),
              ],
            ],
          ),
        ),
        2,
      ),
    );
  }

  Widget _top() => Obx(() {
        _plan.plan.value;
        final showChips = !_noSupply && (_supply.stays.isNotEmpty || _supply.hasStayFilters);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showChips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _enter(TripFilterChips(items: _chips(), accent: TripUi.stay), 1),
                  ),
              ],
            ),
          ),
        );
      });

  List<StayNearbyModel> _pinned(List<StayNearbyModel> shown, Map<String, TripEnquiryModel> asked) {
    final seen = {for (final s in shown) s.id};
    final loaded = {for (final s in _supply.stays) s.id: s};
    final out = <StayNearbyModel>[];
    for (final e in asked.values) {
      if (!seen.add(e.listingId)) continue;
      out.add(loaded[e.listingId] ??
          StayNearbyModel(
            id: e.listingId,
            name: e.listingName,
            latitude: e.listingLatitude ?? 0,
            longitude: e.listingLongitude ?? 0,
            distanceKm: 0,
            isActive: true,
          ));
    }
    return out;
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  static String? _askedLine(TripEnquiryModel? e) {
    if (e == null) return null;
    final offer = e.openOffer;
    return switch (e.display) {
      TripDisplayStatus.asked => TripStringsFinB1.askedWaiting(_ago(e.createdAt)),
      TripDisplayStatus.offered when offer != null => TripStringsFinB1.offeredTotal(BrowseItem.inr(offer.total)),
      _ => null,
    };
  }

  Widget _row(StayNearbyModel s, int day, int nights, TripEnquiryModel? asked) {
    final rawPhone = s.ownerPhone;
    final phone = (rawPhone == null || ContactLauncher.tenDigits(rawPhone).isEmpty) ? null : rawPhone;
    final guide = _guide;
    TripStayRow build({bool shortlisted = false, bool busy = false, bool noReply = false}) => TripStayRow(
          key: ValueKey('${s.id}-$day'),
          stay: s,
          fit: _supply.stayFitOf(s.id),
          status: asked?.display,
          statusLine: _askedLine(asked),
          onOpenChat: asked?.conversationId == null ? null : () => TripNavigation.openChatForEnquiry(asked!),
          readOnly: _plan.isReadOnly,
          onOpen: () => Get.toNamed(AppRoutes.stayDetail, arguments: {'id': s.id, 'distanceKm': s.distanceKm}),
          onCall: phone == null ? null : () => ContactLauncher.call(phone),
          onAsk: () => TripStayEnquirySheet.show(context, stay: s, day: day, nights: nights),
          onShortlist: guide == null
              ? null
              : () => TripShortlistController.to.toggle(
                    step: guide.stepKey,
                    kind: ShortlistKinds.stay,
                    listingId: s.id,
                    name: s.title,
                  ),
          shortlisted: shortlisted,
          shortlistBusy: busy,
          noReply: noReply,
        );
    final c = TripShortlistController.to;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: guide == null
            ? build()
            : Obx(() => build(
                  shortlisted: c.has(guide.stepKey, s.id),
                  busy: c.isBusy(guide.stepKey, s.id),
                  noReply: _noReply.contains(s.id),
                )),
      ),
    );
  }

  List<StayNearbyModel> _ordered(List<StayNearbyModel> rows) {
    final g = _guide;
    if (g == null) return rows;
    return ShortlistOrder.noReplyLast(rows, (s) => s.id, _noReply.toSet());
  }

  Future<void> _done() => TripShortlistFlow.done(
        context,
        step: _guide!.stepKey,
        taxi: false,
        send: () => TripShortlistController.to.sendStays(
          step: _guide!.stepKey,
          day: _firstDay + _pastNights,
          nights: _nights - _pastNights,
        ),
      );

  Map<String, TripEnquiryModel> _askedOf(List<TripEnquiryModel> rows) => {
        for (final e in rows.reversed)
          if (e.isOpen) e.listingId: e,
      };

  Widget? _emptyView(List<StayNearbyModel> all, List<StayNearbyModel> items) {
    if (all.isEmpty) {
      if (_supply.stayFailed.value) {
        return TripEmpty(
          asset: TravelIcon.stay,
          tone: KitTone.stay,
          error: true,
          title: TripStringsV2Find.staysFailed,
          subtitle: TripStringsV2Find.checkConnection,
          onRetry: () => _supply.loadStays(),
          retryLabel: TripStringsV2Find.retry,
        );
      }
      return _noSupplyView();
    }
    if (items.isEmpty) {
      return TripEmpty(
        asset: TravelIcon.stay,
        tone: KitTone.stay,
        title: TripStringsV2Find.noMatch,
        subtitle: TripStringsA2.noMatchBody,
        onRetry: _supply.clearStayFilters,
        retryLabel: TripStringsV2Find.clearFilters,
      );
    }
    return null;
  }

  Widget _buildBody() => Obx(() {
        _plan.plan.value;
        _plan.enquiryList.length;
        if (_noSupply) return _box(_noSupplyView());
        if (_plan.supplyPendingFor(_firstDay) || _supply.stayLoading.value || _supply.staysOutOfDate) return _skeletons();
        final all = _supply.stays;
        final items = _supply.filteredStays;
        if (_split.value) return _splitBody(all, items);
        final asked = _askedOf(_plan.stayEnquiriesOf(_leg));
        final pinned = _pinned(items, asked);
        final empty = pinned.isEmpty ? _emptyView(all, items) : null;
        if (empty != null) return _box(empty);
        final rows = _ordered([...pinned, ...items]);
        final past = _pastNights;
        final day = _firstDay + past;
        final nights = _nights - past;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: rows.length + 1,
            itemBuilder: (_, i) => i == rows.length
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(TripStringsV2Find.askNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText)),
                  )
                : _enter(_row(rows[i], day, nights, asked[rows[i].id]), i + 2),
          ),
        );
      });

  Widget _splitBody(List<StayNearbyModel> all, List<StayNearbyModel> items) {
    final empty = _emptyView(all, items);
    if (empty != null) return _box(empty);
    final past = _pastNights;
    final first = _firstDay + past;
    final nightDays = _only.isNotEmpty ? _only : [for (var i = 0; i < _nights - past; i++) first + i];
    final n = nightDays.length;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: n + 1,
        itemBuilder: (_, i) {
          if (i == n) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(TripStringsV2Find.splitNote,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText)),
                    ),
                  ],
                ),
              ),
            );
          }
          final day = nightDays[i];
          final date = _plan.dateOf(day);
          final asked = _askedOf(_plan.enquiriesForNight(day));
          final shown = _pinned(items, asked);
          final rows = [...shown, ...items];
          final open = _expanded.contains(day);
          final visible = open ? rows : rows.take(_nightPreview).toList();
          return _enter(Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(TripStringsV2Find.nightLabel(day - _firstDay + 1, date == null ? null : TripFormat.shortDate(date)),
                        style: const TextStyle(
                            fontFamily: FitnessAppTheme.fontName, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: -0.4, color: FitnessAppTheme.darkerText)),
                  ),
                  for (final s in visible) _row(s, day, 1, asked[s.id]),
                  if (rows.length > _nightPreview)
                    TextLink(label: open ? TripStringsV2Find.showLess : TripStringsV2Find.showAll(rows.length), onTap: () => open ? _expanded.remove(day) : _expanded.add(day), tone: KitTone.trip),
                ],
              ),
            ),
          ), i + 2);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) TripNavigation.backToPlan();
      },
      child: Scaffold(
        backgroundColor: FitnessAppTheme.background,
        bottomNavigationBar: _guide == null ? null : TripShortlistBar(step: _guide!.stepKey, onDone: _done),
        body: Column(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(parent: _anim, curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn))),
              child: Obx(() {
              _plan.plan.value;
              return TripPageHeader(
                title: TripStringsV2Find.stayIn(_city),
                subtitle: _subtitle(),
                onBack: TripNavigation.backToPlan,
                tone: KitTone.stay,
                trailing: _guide != null || _plan.isReadOnly || _only.isNotEmpty || _plan.openRowsOf(_key).isNotEmpty || _plan.confirmedRowOf(_key) != null
                    ? null
                    : TripHeaderAction(label: TripStringsV2Find.skip, onTap: _skip),
              );
            })),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _top()),
                  _buildBody(),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBody extends StatelessWidget {
  const _PriceBody({required this.current});

  final int? current;

  Widget _option(BuildContext context, int value, String label) {
    final on = (current ?? 0) == value;
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? TripUi.stay : FitnessAppTheme.deactivatedText, width: 2),
              ),
              child: on
                  ? Center(
                      child: Container(
                          width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: TripUi.stay)))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: FitnessAppTheme.darkerText)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: TripStringsA2.priceSheetTitle,
      children: [
        TemplateStagger(children: [
          _option(context, 0, TripStringsA2.anyPrice),
          for (final p in TripSupplyController.pricePresets)
            _option(context, p, TripStringsA2.underPrice(BrowseItem.inr(p))),
        ]),
      ],
    );
  }
}
