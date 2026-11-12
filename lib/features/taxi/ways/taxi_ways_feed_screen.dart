import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
import '../../../models/place_result_model.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/controllers/trip_shortlist_controller.dart';
import '../../trip/models/trip_guide_args.dart';
import '../../trip/models/trip_shortlist_model.dart';
import '../../trip/widgets/trip_shortlist_bar.dart';
import '../../trip/trip_strings_final_aa.dart';
import '../../trip/trip_strings_guide.dart';
import '../../trip/widgets/trip_journey_card.dart';
import '../journeys/journey_models.dart';
import '../journeys/journeys_controller.dart';
import 'destination_section.dart';
import 'widgets/journey_driver_card.dart';
import 'journey_plan_screen.dart';
import 'models/ask_models.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_controller.dart';
import 'taxi_ways_navigation.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';
import 'trip_strings_mcb_a2.dart';
import 'widgets/journey_total_bar.dart';
import 'widgets/ways_arrange_bar.dart';
import 'widgets/way_driver_row.dart';
import 'widgets/way_plan_ribbon_card.dart';
import 'widgets/ways_sort_chips.dart';

class TaxiWaysFeedScreen extends StatefulWidget {
  const TaxiWaysFeedScreen({super.key});

  static const String planOnlyNote = 'This journey needs more than one car. Open an option and ask for each car.';

  @override
  State<TaxiWaysFeedScreen> createState() => _TaxiWaysFeedScreenState();
}

class _TaxiWaysFeedScreenState extends State<TaxiWaysFeedScreen> with TickerProviderStateMixin {
  static const double _maxWidth = 720;

  TaxiWaysController? _c;
  GuideArgs? _guide;
  final _noReply = <String>{}.obs;
  String? _tag;
  bool _read = false;
  int _n = 0;
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_read) return;
    _read = true;
    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;
    if (args is Map && args['from'] is PlaceResult && args['to'] is PlaceResult) {
      final date = args['date'];
      final people = args['people'];
      final tripId = args['tripId'];
      final tripRole = args['tripRole'];
      final tripLegIndex = args['tripLegIndex'];
      _tag = 'ways-${identityHashCode(route)}';
      final c = Get.put(
        TaxiWaysController(
          from: args['from'] as PlaceResult,
          to: args['to'] as PlaceResult,
          fromMyLocation: args['fromMyLocation'] == true,
          date: date is DateTime ? date : null,
          people: people is int ? people : null,
          tripId: tripId is String ? tripId : null,
          tripRole: tripRole is String ? tripRole : null,
          tripLegIndex: tripLegIndex is int && tripLegIndex >= 2 ? tripLegIndex : null,
          fromTrip: args['fromTrip'] == true || tripId is String,
        ),
        tag: _tag,
      );
      _c = c;
      final guide = GuideArgs.from(args);
      if (guide != null && c.inTrip) {
        _guide = guide;
        final sc = TripShortlistController.to;
        sc.load().then((_) {
          if (mounted) _noReply.assignAll(sc.noReplyIds(guide.stepKey));
        });
      }
      JourneysController.ensure().load();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    if (_tag != null) Get.delete<TaxiWaysController>(tag: _tag);
    super.dispose();
  }

  Widget _centred(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: child,
    ),
  );

  Widget _enter(Widget child) {
    final i = _n < 7 ? _n : 7;
    _n++;
    return TemplateEntrance(animation: templateInterval(_ac, i, 8), animationController: _ac, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: Column(
          children: [
            WaysTopBar(
              animation: WaysKit.topBar(_ac),
              child: JourneyPlanScreen.header(context, title: TaxiWaysStrings.title),
            ),
            Expanded(
              child: ListView(
                children: [
                  TripPlanEmpty(
                    image: TravelIcon.route,
                    title: TaxiWaysStrings.noWays,
                    subtitle: TripStringsA6.waysGoneBody,
                    onRetry: () => Get.back(),
                    retryLabel: TripStringsA6.goBack,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      bottomNavigationBar: _guide != null
          ? Obx(
              () => c.result.value != null && c.result.value!.allTheWay.isEmpty && (c.forTrip || c.forSegment)
                  ? _arrangeBar(context, c)
                  : TripShortlistBar(
                      step: _guide!.stepKey,
                      onDone: () => _done(context, c),
                      tone: KitTone.taxi,
                      maxWidth: _maxWidth,
                    ),
            )
          : (c.forTrip || c.forSegment ? _arrangeBar(context, c) : null),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: c.pullRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: WaysTopBar(animation: WaysKit.topBar(_ac), child: _header(context, c)),
            ),
            SliverToBoxAdapter(child: _centred(Obx(() => _body(context, c)))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  TaxiWaysStrings.faresNote,
                  textAlign: TextAlign.center,
                  style: FitnessAppTheme.caption.copyWith(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _arrangeMyself(BuildContext context, TaxiWaysController c) async {
    final leg = c.forSegment ? c.tripLegIndex : null;
    final role = leg == null ? c.actions.role : null;
    if (leg == null && role == null) return;
    if (!Get.isRegistered<TripPlanController>()) return;
    if (await TripJourneyCard.arrangeMyself(context, role: role, legIndex: leg)) await c.actions.arrangedMyself();
  }

  Future<void> _skipTravel(TaxiWaysController c) async {
    final leg = c.forSegment ? c.tripLegIndex : null;
    final role = leg == null ? c.actions.role : null;
    if (leg == null && role == null) return;
    if (!Get.isRegistered<TripPlanController>()) return;
    if (TripJourneyCard.skipTravel(role: role, legIndex: leg)) await c.actions.arrangedMyself();
  }

  Widget _skipButton(VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: DesignColors.primary, minimumSize: const Size(64, 48)),
    child: Text(
      TripStringsGuide.optSkip,
      style: FitnessAppTheme.title.copyWith(fontSize: 14, color: DesignColors.primary),
    ),
  );

  Widget _arrangeBar(BuildContext context, TaxiWaysController c) => WaysArrangeBar(
    arrangeLabel: TripStringsGuide.optOwn,
    skipLabel: TripStringsGuide.optSkip,
    onArrange: () => _arrangeMyself(context, c),
    onSkip: () => _skipTravel(c),
    maxWidth: _maxWidth,
  );

  Widget _header(BuildContext context, TaxiWaysController c) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ModuleHeader.lightIcons,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          gradient: KitTone.taxi.gradient,
          borderRadius: CardRadius.header,
          boxShadow: ShadowTokens.glow(KitTone.taxi.glow),
        ),
        padding: EdgeInsets.fromLTRB(8, top + 6, 8, 16),
        child: _centred(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignColors.surface, size: 20),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TaxiWaysStrings.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitnessAppTheme.headline.copyWith(
                            fontSize: 20,
                            color: DesignColors.surface,
                            letterSpacing: 0.27,
                          ),
                        ),
                        if (c.inTrip)
                          Obx(
                            () => Text(
                              TripStringsA6.feedSubtitle(c.date.value, c.people.value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FitnessAppTheme.caption.copyWith(
                                fontSize: 12,
                                color: DesignColors.surface.withValues(alpha: Alpha.high),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _journeysButton(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [_dateChip(context, c), _peopleStepper(c)],
                      ),
                    ),
                    if (c.lockedDate)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          TripStringsMcbA2.travelDayOfTrip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitnessAppTheme.caption.copyWith(
                            fontSize: 11,
                            color: DesignColors.surface.withValues(alpha: Alpha.high),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Obx(() => _routeCard(c)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeysButton() {
    final j = JourneysController.ensure();
    return Obx(() {
      final alert = j.journeys.any((e) => e.status == JourneyStatus.driverUnavailable);
      return Tooltip(
        message: TaxiWaysStrings.myJourneys,
        child: InkResponse(
          onTap: () => TaxiWaysNavigation.openMyJourneys(),
          radius: 28,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignColors.surfaceAlt.withValues(alpha: Alpha.soft),
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const TravelIcon(TravelIcon.note, size: 28),
                if (alert)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: WaysTokens.confirmEnd,
                        shape: BoxShape.circle,
                        border: Border.all(color: DesignColors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _pill({required Widget child, VoidCallback? onTap}) => Material(
    color: DesignColors.surface.withValues(alpha: Alpha.soft),
    borderRadius: WaysKit.pillRadius,
    child: InkWell(
      onTap: onTap,
      borderRadius: WaysKit.pillRadius,
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: child),
    ),
  );

  TextStyle get _pillText =>
      FitnessAppTheme.subtitle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: DesignColors.surface);

  Widget _dateChip(BuildContext context, TaxiWaysController c) {
    final locked = c.lockedDate;
    final chip = _pill(
      onTap: locked ? null : () => _pickDate(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            locked
                ? const Icon(Icons.lock_rounded, size: 14, color: DesignColors.surface)
                : const TravelIcon(TravelIcon.calendar, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(_dateText(c.date.value), maxLines: 1, overflow: TextOverflow.ellipsis, style: _pillText),
            ),
          ],
        ),
      ),
    );
    if (!locked) return chip;
    return Tooltip(message: TripStringsMcbA2.travelDayOfTrip, child: chip);
  }

  static String _dateText(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return '${TaxiWaysStrings.today} · ${TaxiWaysStrings.dateChip(d)}';
    if (diff == 1) return '${TaxiWaysStrings.tomorrow} · ${TaxiWaysStrings.dateChip(d)}';
    return TaxiWaysStrings.dateChip(d);
  }

  Future<void> _pickDate(BuildContext context, TaxiWaysController c) async {
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: c.date.value,
      first: TaxiWaysController.firstDate(),
      last: TaxiWaysController.lastDate(),
      tone: KitTone.taxi,
    );
    if (picked != null) c.setDate(picked);
  }

  static const String _peopleIcon = 'assets/images/design/travel3d/backpack.png';

  Widget _peopleStepper(TaxiWaysController c) {
    final n = c.people.value;
    if (c.lockedPeople) {
      return _pill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TravelIcon(_peopleIcon, size: 18),
              const SizedBox(width: 6),
              Text(TaxiWaysStrings.people(n), style: _pillText),
            ],
          ),
        ),
      );
    }
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
      width: 44,
      height: 44,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? DesignColors.surface : DesignColors.surface.withValues(alpha: Alpha.half),
        ),
      ),
    );
    return _pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, n > 1, () => c.setPeople(n - 1)),
          const TravelIcon(_peopleIcon, size: 18),
          const SizedBox(width: 6),
          Text(TaxiWaysStrings.people(n), style: _pillText),
          btn(Icons.add_rounded, n < TaxiWaysController.maxPeople, () => c.setPeople(n + 1)),
        ],
      ),
    );
  }

  Widget _routeCard(TaxiWaysController c) {
    final r = c.result.value;
    final fromName = r != null && r.from.name.isNotEmpty ? r.from.name : c.from.value.name;
    final toName = r != null && r.to.name.isNotEmpty ? r.to.name : c.to.value.name;
    final locked = c.lockedEnds;
    Widget end(String label, String name, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: DesignColors.textSecondary,
                ),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 4),
              const Icon(Icons.lock_rounded, size: 11, color: DesignColors.textSecondary),
            ],
          ],
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FitnessAppTheme.title.copyWith(fontSize: 14, color: DesignColors.primary),
        ),
      ],
    );
    final fromLabel = c.fromMyLocation.value ? TaxiWaysStrings.fromMyLocationLabel : TaxiWaysStrings.fromLabel;
    final day = c.segmentDay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: TripLook.softRadius,
        boxShadow: PickKit.greyShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: end(fromLabel, fromName, CrossAxisAlignment.start)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: PickKit.taxi),
              ),
              Expanded(child: end(TaxiWaysStrings.toLabel, toName, CrossAxisAlignment.end)),
            ],
          ),
          if (locked && day != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: TripLook.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const TravelIcon(TravelIcon.route, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      TripStringsMcbA2.fromYourTrip(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(BuildContext context, TaxiWaysController c) {
    _n = 0;
    final r = c.result.value;
    if (r == null) {
      if (c.isLoading.value) return _skeleton();
      return TripPlanEmpty(
        image: c.isOffline.value ? TravelIcon.map : TravelIcon.route,
        title: c.isOffline.value
            ? TaxiWaysStrings.offlineTitle
            : (c.tabOff.value ? TaxiWaysStrings.taxisOff : TaxiWaysStrings.loadFailed),
        subtitle: c.isOffline.value || c.errorText.value.isEmpty ? TaxiWaysStrings.offlineBody : c.errorText.value,
        onRetry: c.tabOff.value ? null : c.retry,
        retryLabel: TaxiWaysStrings.retry,
      );
    }
    final rows = _ordered(c.rows);
    final sort = c.sort.value;
    final children = <Widget>[];
    if (c.isLoading.value) {
      children.add(
        const LinearProgressIndicator(minHeight: 2, color: DesignColors.primary, backgroundColor: Colors.transparent),
      );
    }
    if (c.isOffline.value) children.add(_offlineBanner());
    if (rows.length > 1) {
      children.add(
        _enter(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: WaysSortChips(value: sort, onChanged: c.setSort),
          ),
        ),
      );
    }
    if (!r.hasWays && (c.forSegment || c.forTrip)) {
      children.add(_enter(Padding(padding: const EdgeInsets.only(top: 16), child: _gapCard(context, c, r))));
    } else if (!r.hasWays) {
      children.add(
        _enter(
          TripPlanEmpty(
            image: TravelIcon.route,
            title: TaxiWaysStrings.noWays,
            subtitle: TaxiWaysStrings.noWaysBody(r.to.name.isNotEmpty ? r.to.name : c.to.value.name),
          ),
        ),
      );
    } else {
      if (r.allTheWay.isEmpty && r.plans.isNotEmpty) {
        children.add(
          _enter(_note(r.plans.first.legs.length >= 3 ? TaxiWaysStrings.noDirect3 : TaxiWaysStrings.noDirect2)),
        );
      }
      if (_guide != null && r.allTheWay.isEmpty) {
        children.add(
          _enter(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: const WaysBanner(icon: Icons.info_outline_rounded, text: TaxiWaysFeedScreen.planOnlyNote, key: ValueKey('plan-only-note')),
            ),
          ),
        );
      }
      children.addAll(_rows(context, c, r, rows, sort));
      final ask = _guide != null ? null : _askTheseButton(context, c, r);
      if (ask != null) children.add(_enter(ask));
    }
    if (!c.inTrip) {
      children.add(const SizedBox(height: 24));
      children.add(
        AtDestinationSection(
          cityName: r.to.name.isNotEmpty ? r.to.name : c.to.value.name,
          date: c.date.value,
          people: c.people.value,
          localTaxis: r.localTaxis,
          stays: r.stays,
          reachFirstPlace: r.reachFirstPlace,
          hasWays: r.hasWays,
        ),
      );
    }
    children.add(
      _enter(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: DesignColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${TaxiWaysStrings.listedFares} ${TaxiWaysStrings.payLine}',
                  style: FitnessAppTheme.caption.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    children.add(SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _gapCard(BuildContext context, TaxiWaysController c, TaxiWaysResult r) {
    final from = r.from.name.isNotEmpty ? r.from.name : c.from.value.name;
    final to = r.to.name.isNotEmpty ? r.to.name : c.to.value.name;
    final hub = c.gapHub;
    final busy = c.isLoading.value;
    final mine = PickButton(
      label: TripStringsGuide.optOwn,
      onPressed: busy ? null : () => _arrangeMyself(context, c),
      height: 48,
      gradient: PickKit.taxiGradient,
      shadowColor: PickKit.taxi,
    );
    final again = SecondaryButton(
      label: TripStringsMcbA2.searchAgain,
      onPressed: busy ? null : c.retry,
      tone: KitTone.taxi,
      height: 48,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TripLook.card(radius: TripLook.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: PickKit.taxiGradient,
                  shape: BoxShape.circle,
                  boxShadow: PickKit.shadow(PickKit.taxi),
                ),
                child: const TravelIcon(TravelIcon.taxi, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TripStringsMcbA2.noDriverGoes(from, to),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.title.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TripStringsMcbA2.nobodyListed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            TripStringsMcbA2.reachHubThen(hub, to),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: FitnessAppTheme.body2.copyWith(fontSize: 12.5, color: DesignColors.textGrey, height: 1.35),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [again, const SizedBox(height: 8), mine],
                );
              }
              return Row(
                children: [
                  Expanded(child: mine),
                  const SizedBox(width: 10),
                  Expanded(child: again),
                ],
              );
            },
          ),
          Align(alignment: Alignment.center, child: _skipButton(() => _skipTravel(c))),
        ],
      ),
    );
  }

  Widget _skeleton() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      children: [
        const TemplatePlaceholder(height: 44, radius: 22),
        const SizedBox(height: 12),
        _skelCard(72),
        const SizedBox(height: 12),
        _skelCard(72),
        const SizedBox(height: 12),
        _skelCard(150),
      ],
    ),
  );

  Widget _skelCard(double h) => Container(
    decoration: TripLook.card(),
    padding: const EdgeInsets.all(12),
    child: TemplatePlaceholder(height: h - 24, radius: 14),
  );

  Widget _offlineBanner() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: WaysBanner(
      icon: Icons.wifi_off_rounded,
      text: '${TaxiWaysStrings.offlineTitle} · ${TaxiWaysStrings.offlineBody}',
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      text,
      style: FitnessAppTheme.body2.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: DesignColors.textGrey),
    ),
  );

  String? _bestReason(TaxiWaysResult r, Object row) {
    final b = r.bestWay;
    if (b == null) return null;
    if (row is WayDriver && b.isDriver && b.id == row.taxiId) {
      return row.basedHere ? TaxiWaysStrings.bestBasedHereReason : TaxiWaysStrings.bestDriverReason;
    }
    if (row is WayPlan && b.isPlan && b.id == row.planKey) {
      if (row.isDirectCover) return TripStringsFinalAa.coverReason(row.carHires, row.total);
      return TaxiWaysStrings.bestPlanReason(row.legs.length - 1, row.total);
    }
    return null;
  }

  List<Widget> _rows(BuildContext context, TaxiWaysController c, TaxiWaysResult r, List<Object> rows, WaysSort sort) {
    final out = <Widget>[];
    var lastCars = 0;
    var bestShown = false;
    var noteShown = false;
    final canUse = c.inTrip;
    final guide = _guide;
    final shortlist = TripShortlistController.to;
    final people = c.people.value;
    for (final row in rows) {
      final cars = rowCars(row, people);
      if (sort == WaysSort.fewestCars && lastCars != 0 && cars != lastCars) {
        out.add(_enter(_groupHeader(r, cars, people)));
      }
      lastCars = cars;
      String? reason;
      if (!bestShown) {
        reason = _bestReason(r, row);
        if (reason != null) bestShown = true;
      }
      out.add(const SizedBox(height: 12));
      if (row is WayDriver) {
        WayDriverRow build() => WayDriverRow(
              key: ValueKey('d-${row.taxiId}'),
              driver: row,
              people: people,
              bestReason: reason,
              onTap: () => _openDriver(c, r, row),
              onCall: () => JourneyDriverCard.call(row),
              onUse: canUse && guide == null ? () => _useDriver(context, c, r, row) : null,
              useBusy: c.busyPlans.isNotEmpty,
              onShortlist: guide == null ? null : () => _toggleCar(guide, row),
              shortlisted: guide != null && shortlist.has(guide.stepKey, row.taxiId),
              shortlistBusy: guide != null && shortlist.isBusy(guide.stepKey, row.taxiId),
              noReply: guide != null && _noReply.contains(row.taxiId),
            );
        out.add(_enter(guide == null ? build() : Obx(build)));
      } else if (row is WayPlan) {
        out.add(
          _enter(
            WayPlanRibbonCard(
              key: ValueKey('p-${row.planKey}'),
              plan: row,
              planIndex: r.plans.indexOf(row),
              bestReason: reason,
              onOpen: () => TaxiWaysNavigation.openPlan(c.openArgs(row)),
              onUse: canUse ? () => c.actions.useForTrip(row, context: context) : null,
              useBusy: c.busyPlans.contains(row.planKey),
              useNote: canUse && !noteShown && (noteShown = true),
            ),
          ),
        );
      }
    }
    return out;
  }

  Widget _groupHeader(TaxiWaysResult r, int cars, int people) {
    String? sub;
    if (cars == 2 && r.allTheWay.isNotEmpty) {
      final twoCar = r.plans.where((p) => p.legs.length == 2 && p.carHires == 2).toList();
      final cheapestDriver = r.allTheWay.map((d) => d.groupFare(people)).reduce((a, b) => a < b ? a : b);
      if (twoCar.isNotEmpty && twoCar.map((p) => p.total).reduce((a, b) => a < b ? a : b) < cheapestDriver) {
        final names = <String>[];
        for (final p in twoCar) {
          final n = p.legs.first.to.name;
          if (n.isNotEmpty && !names.contains(n)) names.add(n);
          if (names.length == 2) break;
        }
        if (names.isNotEmpty) sub = TaxiWaysStrings.cheaperOneChange(TaxiWaysStrings.orPlaces(names));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TaxiWaysStrings.orInCars(cars), style: FitnessAppTheme.title.copyWith(fontSize: 16)),
          if (sub != null) Text(sub, style: FitnessAppTheme.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  List<WayDriver> _companions(TaxiWaysResult r, WayDriver first) {
    final rest = _basedHereFirst(r.allTheWay.where((d) => d.taxiId != first.taxiId));
    return [first, ...rest.take(2)];
  }

  static List<WayDriver> _basedHereFirst(Iterable<WayDriver> list) => [
    ...list.where((d) => d.basedHere),
    ...list.where((d) => !d.basedHere),
  ];

  Future<void> _useDriver(BuildContext context, TaxiWaysController c, TaxiWaysResult r, WayDriver d) =>
      c.actions.useForTrip(c.singlePlan(_companions(r, d)), context: context);

  void _openDriver(TaxiWaysController c, TaxiWaysResult r, WayDriver d) {
    final plan = c.singlePlan(_companions(r, d));
    TaxiWaysNavigation.openPlan(c.openArgs(plan, synthetic: true));
  }

  List<Object> _ordered(List<Object> rows) {
    final g = _guide;
    if (g == null) return rows;
    return ShortlistOrder.noReplyLast(rows, (r) => r is WayDriver ? r.taxiId : '', _noReply.toSet());
  }

  void _toggleCar(GuideArgs g, WayDriver d) => TripShortlistController.to.toggle(
        step: g.stepKey,
        kind: ShortlistKinds.car,
        listingId: d.taxiId,
        name: d.driverName,
      );

  Future<void> _done(BuildContext context, TaxiWaysController c) {
    final g = _guide!;
    return TripShortlistFlow.done(
      context,
      step: g.stepKey,
      taxi: true,
      send: () => TripShortlistController.to.sendCars(
        step: g.stepKey,
        ask: (ids, requestId) {
          final r = c.result.value;
          final byId = {for (final d in r?.allTheWay ?? const <WayDriver>[]) d.taxiId: d};
          final drivers = [for (final id in ids) ?byId[id]];
          if (drivers.isEmpty) return Future.value(const AskResult(items: [], skipped: [], veryShortNotice: false));
          return c.actions.askShortlisted(
            context,
            c.singlePlan(drivers),
            step: g.stepKey,
            requestId: requestId,
            taxiIds: [for (final d in drivers) d.taxiId],
          );
        },
      ),
    );
  }

  Widget? _askTheseButton(BuildContext context, TaxiWaysController c, TaxiWaysResult r) {
    if (!c.fromMyLocation.value || r.allTheWay.isEmpty) return null;
    final drivers = _basedHereFirst(r.allTheWay).take(3).toList();
    final busy = c.busyPlans.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: JourneyAskButton(
        label: JourneyAskButton.labelFor(drivers.length, these: true),
        busy: busy,
        onPressed: () => c.actions.askDrivers(context, c.singlePlan(drivers)),
      ),
    );
  }
}
