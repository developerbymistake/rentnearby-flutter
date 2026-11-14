import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
import '../../../models/place_result_model.dart';
import '../../../widgets/listing_contact_actions.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/controllers/trip_shortlist_controller.dart';
import '../../trip/models/trip_guide_args.dart';
import '../../trip/models/trip_shortlist_model.dart';
import '../../trip/trip_strings_shortlist.dart';
import '../../trip/widgets/trip_shortlist_bar.dart';
import '../../trip/trip_strings_final_aa.dart';
import '../../trip/trip_strings_guide.dart';
import '../../trip/widgets/trip_journey_card.dart';
import '../../trip/widgets/trip_list_look.dart';
import '../journeys/journey_models.dart';
import '../journeys/journeys_controller.dart';
import 'destination_section.dart';
import 'widgets/journey_driver_card.dart';
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
  const TaxiWaysFeedScreen({super.key, this.debugController, this.debugGuide});

  @visibleForTesting
  final TaxiWaysController? debugController;
  @visibleForTesting
  final GuideArgs? debugGuide;

  static String planOnlyText(int cars) =>
      '${cars >= 3 ? TaxiWaysStrings.noDirect3 : TaxiWaysStrings.noDirect2} ${TaxiWaysStrings.askEachCar}';

  @override
  State<TaxiWaysFeedScreen> createState() => _TaxiWaysFeedScreenState();
}

class _TaxiWaysFeedScreenState extends State<TaxiWaysFeedScreen>
    with TickerProviderStateMixin {
  static const double _maxWidth = 720;
  static final Color _page = ListingPalette.coral.page;

  final _scroll = ScrollController();
  final _scrolled = ValueNotifier<bool>(false);
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
    _ac = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _scroll.addListener(
      () => _scrolled.value = _scroll.hasClients && _scroll.offset > 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_read) return;
    _read = true;
    if (widget.debugController != null) {
      _c = widget.debugController;
      _guide = widget.debugGuide;
      final g = _guide;
      if (g != null) TripShortlistController.to.load();
      return;
    }
    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;
    if (args is Map &&
        args['from'] is PlaceResult &&
        args['to'] is PlaceResult) {
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
          tripLegIndex: tripLegIndex is int && tripLegIndex >= 2
              ? tripLegIndex
              : null,
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
    _scroll.dispose();
    _scrolled.dispose();
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
    return TemplateEntrance(
      animation: templateInterval(_ac, i, 8),
      animationController: _ac,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: _page,
        body: Column(
          children: [
            WaysTopBar(
              animation: WaysKit.topBar(_ac),
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                child: TopBar3D(tone: ListingTone.coral, title: TaxiWaysStrings.title, onBack: () => Get.back()),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  JourneyEmpty3D(
                    art: ListingArt.compass,
                    title: TaxiWaysStrings.noWays,
                    body: TripStringsA6.waysGoneBody,
                    actionLabel: TripStringsA6.goBack,
                    onAction: () => Get.back(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: _page,
      bottomNavigationBar: _guide != null
          ? Obx(
              () => c.result.value == null
                  ? (c.loadFailed.value && (c.forTrip || c.forSegment)
                        ? _arrangeBar(context, c)
                        : const SizedBox.shrink())
                  : c.result.value!.allTheWay.isEmpty &&
                        (c.forTrip || c.forSegment)
                  ? _arrangeBar(context, c)
                  : TripShortlistBar(
                      step: _guide!.stepKey,
                      onDone: () => _done(context, c),
                      tone: KitTone.taxi,
                      maxWidth: _maxWidth,
                    ),
            )
          : (c.forTrip || c.forSegment ? _arrangeBar(context, c) : null),
      body: Stack(
        children: [
          RefreshIndicator(
            color: ListingPalette.coral.text,
            onRefresh: c.pullRefresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: WaysTopBar(
                    animation: WaysKit.topBar(_ac),
                    child: _header(context, c),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _centred(Obx(() => _body(context, c))),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Obx(
                      () => c.result.value != null
                          ? const SizedBox.shrink()
                          : Text(
                              TaxiWaysStrings.faresNote,
                              textAlign: TextAlign.center,
                              style: FitnessAppTheme.caption.copyWith(fontSize: 12),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _statusCover(context)),
        ],
      ),
    );
  }

  Widget _statusCover(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _scrolled,
    builder: (_, scrolled, _) => IgnorePointer(
      child: Container(
        height: scrolled ? MediaQuery.paddingOf(context).top : 0,
        color: _page,
      ),
    ),
  );

  Future<void> _arrangeMyself(
    BuildContext context,
    TaxiWaysController c,
  ) async {
    final leg = c.forSegment ? c.tripLegIndex : null;
    final role = leg == null ? c.actions.role : null;
    if (leg == null && role == null) return;
    if (!Get.isRegistered<TripPlanController>()) return;
    if (await TripJourneyCard.arrangeMyself(context, role: role, legIndex: leg))
      await c.actions.arrangedMyself();
  }

  Future<void> _skipTravel(TaxiWaysController c) async {
    final leg = c.forSegment ? c.tripLegIndex : null;
    final role = leg == null ? c.actions.role : null;
    if (leg == null && role == null) return;
    if (!Get.isRegistered<TripPlanController>()) return;
    if (TripJourneyCard.skipTravel(role: role, legIndex: leg))
      await c.actions.arrangedMyself();
  }

  Widget _arrangeBar(BuildContext context, TaxiWaysController c) =>
      WaysArrangeBar(
        arrangeLabel: TripStringsGuide.optOwn,
        skipLabel: TripStringsGuide.optSkip,
        onArrange: () => _arrangeMyself(context, c),
        onSkip: () => _skipTravel(c),
        maxWidth: _maxWidth,
      );

  Widget _header(BuildContext context, TaxiWaysController c) {
    final step = TripGuideStepInfo.of(_guide);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: 4),
        child: _centred(
          Obx(() {
            final r = c.result.value;
            final from = c.from.value.name.isNotEmpty ? c.from.value.name : (r?.from.name ?? '');
            final to = r != null && r.to.name.isNotEmpty ? r.to.name : c.to.value.name;
            return TopBar3D(
              tone: ListingTone.coral,
              title: TaxiWaysStrings.title,
              subtitle: from.isEmpty || to.isEmpty ? '' : TaxiWaysStrings.subtitle(from, to),
              stepChip: step?.chip,
              onBack: () => Get.back(),
              trailing: _guide != null ? null : _journeysButton(),
              bottom: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [_dateChip(context, c), _peopleStepper(c)],
                    ),
                    if (c.lockedDate)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          TripStringsMcbA2.travelDayOfTrip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ink3D.text(11, FontWeight.w400, Ink3D.sub, letterSpacing: 0),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _routeCard(c),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _journeysButton() {
    final j = JourneysController.ensure();
    return Obx(() {
      final alert = j.journeys.any(
        (e) => e.status == JourneyStatus.driverUnavailable,
      );
      return Tooltip(
        message: TaxiWaysStrings.myJourneys,
        child: RoundIconButton3D(
          asset: TravelIcon.note,
          onTap: () => TaxiWaysNavigation.openMyJourneys(),
          semanticsLabel: TaxiWaysStrings.myJourneys,
          badge: alert
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: WaysTokens.confirmEnd,
                    shape: BoxShape.circle,
                    border: Border.all(color: DesignColors.surface, width: 1.5),
                  ),
                )
              : null,
        ),
      );
    });
  }

  Widget _pill({required Widget child, VoidCallback? onTap}) => DecoratedBox(
    decoration: const BoxDecoration(
      color: DesignColors.surface,
      borderRadius: WaysKit.pillRadius,
      boxShadow: Ink3D.softShadow,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: WaysKit.pillRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: child,
        ),
      ),
    ),
  );

  TextStyle get _pillText => Ink3D.text(13, FontWeight.w600, Ink3D.body, letterSpacing: 0);

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
                ? Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: ListingTone.coral.text,
                  )
                : const TravelIcon(TravelIcon.calendar, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _dateText(c.date.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pillText,
              ),
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
    if (diff == 0)
      return '${TaxiWaysStrings.today} · ${TaxiWaysStrings.dateChip(d)}';
    if (diff == 1)
      return '${TaxiWaysStrings.tomorrow} · ${TaxiWaysStrings.dateChip(d)}';
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

  static const String _peopleIcon =
      'assets/images/design/travel3d/busts_in_silhouette.png';

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
          color: enabled
              ? ListingTone.coral.text
              : Ink3D.hint,
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
          btn(
            Icons.add_rounded,
            n < TaxiWaysController.maxPeople,
            () => c.setPeople(n + 1),
          ),
        ],
      ),
    );
  }

  Widget _routeCard(TaxiWaysController c) {
    final r = c.result.value;
    final fromName = c.from.value.name.isNotEmpty
        ? c.from.value.name
        : (r?.from.name ?? '');
    final toName = r != null && r.to.name.isNotEmpty
        ? r.to.name
        : c.to.value.name;
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
              const Icon(
                Icons.lock_rounded,
                size: 11,
                color: DesignColors.textSecondary,
              ),
            ],
          ],
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FitnessAppTheme.title.copyWith(
            fontSize: 14,
            color: ListingPalette.coral.text,
          ),
        ),
      ],
    );
    final fromLabel = c.fromMyLocation.value
        ? TaxiWaysStrings.fromMyLocationLabel
        : TaxiWaysStrings.fromLabel;
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
              Expanded(
                child: end(fromLabel, fromName, CrossAxisAlignment.start),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: PickKit.taxi,
                ),
              ),
              Expanded(
                child: end(
                  TaxiWaysStrings.toLabel,
                  toName,
                  CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          if (locked && day != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TripLook.surface,
                borderRadius: BorderRadius.circular(10),
              ),
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
                        color: ListingPalette.coral.text,
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
      final empty = JourneyEmpty3D(
        artSize: MediaQuery.sizeOf(context).height < 700 ? 56 : null,
        compact: MediaQuery.sizeOf(context).height < 700,
        art: c.isOffline.value ? ListingArt.worldMap : ListingArt.taxi,
        title: c.isOffline.value
            ? TaxiWaysStrings.offlineTitle
            : (c.tabOff.value
                  ? TaxiWaysStrings.taxisOff
                  : TaxiWaysStrings.loadFailed),
        body: c.isOffline.value || c.errorText.value.isEmpty
            ? TaxiWaysStrings.offlineBody
            : c.errorText.value,
        actionLabel: c.tabOff.value ? null : TaxiWaysStrings.retry,
        onAction: c.tabOff.value ? null : c.retry,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [empty, _foot(TaxiWaysStrings.faresNote, center: true)],
      );
    }
    final rows = _ordered(c.rows);
    final sort = c.sort.value;
    final children = <Widget>[];
    if (c.isLoading.value) {
      children.add(
        LinearProgressIndicator(
          minHeight: 2,
          color: ListingPalette.coral.text,
          backgroundColor: Colors.transparent,
        ),
      );
    }
    if (c.isOffline.value) children.add(_offlineBanner());
    final planOnly = r.hasWays && r.allTheWay.isEmpty && r.plans.isNotEmpty;
    final fares = DisclaimerBanner(text: '${TaxiWaysStrings.faresNote} ${TaxiWaysStrings.payLine}', margin: _bannerMargin);
    if (r.hasWays && !planOnly) children.add(_enter(fares));
    if (rows.length > 1) {
      children.add(
        _enter(
          Padding(
            padding: const EdgeInsets.fromLTRB(_side, 12, _side, 0),
            child: WaysSortChips(value: sort, onChanged: c.setSort),
          ),
        ),
      );
    }
    if (!r.hasWays && _guide != null) {
      children.add(
        _enter(
          TripPlanEmpty(
            key: const ValueKey('list-empty'),
            image: TravelIcon.route,
            title: TripStringsShortlist.emptyTitle,
            subtitle: TripStringsShortlist.emptyBody,
            onRetry: c.isLoading.value ? null : c.retry,
            retryLabel: TripStringsShortlist.searchAgain,
          ),
        ),
      );
    } else if (!r.hasWays && (c.forSegment || c.forTrip)) {
      children.add(
        _enter(
          Padding(
            padding: EdgeInsets.zero,
            child: _gapCard(context, c, r),
          ),
        ),
      );
    } else if (!r.hasWays) {
      children.add(
        _enter(
          JourneyEmpty3D(
            art: ListingArt.compass,
            compact: true,
            title: TaxiWaysStrings.noWays,
            body: TaxiWaysStrings.noWaysBody(
              r.to.name.isNotEmpty ? r.to.name : c.to.value.name,
            ),
          ),
        ),
      );
    } else {
      if (_guide == null && r.allTheWay.isEmpty && r.plans.isNotEmpty) {
        children.add(
          _enter(
            DisclaimerBanner(
              art: ListingArt.taxi,
              margin: _bannerMargin,
              text: r.plans.first.legs.length >= 3
                  ? TaxiWaysStrings.noDirect3
                  : TaxiWaysStrings.noDirect2,
            ),
          ),
        );
      }
      if (_guide != null && r.allTheWay.isEmpty) {
        children.add(
          _enter(
            DisclaimerBanner(
              key: const ValueKey('plan-only-note'),
              art: ListingArt.taxi,
              margin: _bannerMargin,
              text: TaxiWaysFeedScreen.planOnlyText(r.plans.isEmpty ? 2 : r.plans.first.legs.length),
            ),
          ),
        );
      }
      children.addAll(_rows(context, c, r, rows, sort));
      final ask = _guide != null ? null : _askTheseButton(context, c, r);
      if (ask != null) children.add(_enter(ask));
      if (planOnly) children.add(_enter(fares));
    }
    if (!c.inTrip) {
      children.add(const SizedBox(height: 8));
      children.add(
        AtDestinationSection(
          cityName: r.to.name.isNotEmpty ? r.to.name : c.to.value.name,
          date: c.date.value,
          people: c.people.value,
          localTaxis: r.localTaxis,
          stays: r.stays,
          reachFirstPlace: r.reachFirstPlace,
          hasWays: r.hasWays,
          citiesUnavailable: r.citiesUnavailable,
        ),
      );
    }
    if (!r.hasWays) children.add(_foot('${TaxiWaysStrings.faresNote} ${TaxiWaysStrings.payLine}'));
    children.add(
      SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _foot(String text, {bool center = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
    child: Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.45))),
      ],
    ),
  );

  static const double _side = 16;
  static const EdgeInsets _bannerMargin = EdgeInsets.fromLTRB(18, 12, 18, 0);

  Widget _gapCard(
    BuildContext context,
    TaxiWaysController c,
    TaxiWaysResult r,
  ) {
    final from = c.from.value.name.isNotEmpty ? c.from.value.name : r.from.name;
    final to = r.to.name.isNotEmpty ? r.to.name : c.to.value.name;
    return JourneyGapCard3D(
      title: TripStringsMcbA2.noDriverGoes(from, to),
      tag: TripStringsMcbA2.nobodyListed,
      body: TripStringsMcbA2.reachHubThen(c.gapHub, to),
      actionLabel: TripStringsMcbA2.searchAgain,
      onAction: c.isLoading.value ? null : c.retry,
    );
  }

  Widget _skeleton() => Padding(
    key: const ValueKey('list-loading'),
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_guide != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              TripStringsShortlist.loadingTaxis,
              style: Ink3D.text(13, FontWeight.w500, Ink3D.sub, letterSpacing: 0),
            ),
          ),
        const WideCardSkeleton(),
        const WideCardSkeleton(),
        const WideCardSkeleton(),
      ],
    ),
  );

  Widget _offlineBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(_side, 12, _side, 0),
    child: JourneyBanner3D(
      text: '${TaxiWaysStrings.offlineTitle} · ${TaxiWaysStrings.offlineBody}',
    ),
  );

  String? _bestReason(TaxiWaysResult r, Object row) {
    final b = r.bestWay;
    if (b == null) return null;
    if (row is WayDriver && b.isDriver && b.id == row.taxiId) {
      return row.basedHere
          ? TaxiWaysStrings.bestBasedHereReason
          : TaxiWaysStrings.bestDriverReason;
    }
    if (row is WayPlan && b.isPlan && b.id == row.planKey) {
      if (row.isDirectCover)
        return TripStringsFinalAa.coverReason(row.carHires, row.total);
      return TaxiWaysStrings.bestPlanReason(row.legs.length - 1, row.total);
    }
    return null;
  }

  List<Widget> _rows(
    BuildContext context,
    TaxiWaysController c,
    TaxiWaysResult r,
    List<Object> rows,
    WaysSort sort,
  ) {
    final out = <Widget>[];
    var lastCars = 0;
    var bestShown = false;
    var noteShown = false;
    final canUse = c.inTrip;
    final guide = _guide;
    final shortlist = TripShortlistController.to;
    final people = c.people.value;
    var driverIndex = 0;
    final hasOnTheWay = rows.any((e) => e is WayDriver && e.isOnTheWay);
    var onTheWayShown = false;
    if (hasOnTheWay && rows.first is WayDriver) {
      out.add(_enter(TitleRow3D(title: TaxiWaysStrings.directHeader, tone: ListingTone.coral)));
    }
    for (final row in rows) {
      if (row is WayDriver && row.isOnTheWay && !onTheWayShown) {
        onTheWayShown = true;
        lastCars = 0;
        out.add(_enter(TitleRow3D(title: TaxiWaysStrings.onTheWayHeader, subtitle: TaxiWaysStrings.onTheWayBody, tone: ListingTone.coral)));
      }
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
      if (row is WayDriver) {
        final tone = ListingTone.list(ListingTone.coral, driverIndex++);
        WayDriverRow build() => WayDriverRow(
          tone: tone,
          key: ValueKey('d-${row.taxiId}'),
          driver: row,
          people: people,
          bestReason: reason,
          onTap: () => _openDriver(c, r, row),
          onCall: row.hasContact
              ? () => JourneyDriverCard.call(row)
              : () => ListingContactActions.call(context, kind: ListingKind.taxi, id: row.taxiId),
          callBusy: ListingContactActions.isBusy(ListingKind.taxi, row.taxiId),
          onUse: canUse && guide == null
              ? () => _useDriver(context, c, r, row)
              : null,
          useBusy: c.busyPlans.isNotEmpty,
          onShortlist: guide == null ? null : () => _toggleCar(guide, row),
          shortlisted:
              guide != null && shortlist.has(guide.stepKey, row.taxiId),
          shortlistBusy:
              guide != null && shortlist.isBusy(guide.stepKey, row.taxiId),
          noReply: guide != null && _noReply.contains(row.taxiId),
          startName: guide != null ? c.from.value.name : null,
        );
        out.add(_enter(Obx(build)));
      } else if (row is WayPlan) {
        out.add(
          _enter(
            WayPlanRibbonCard(
              key: ValueKey('p-${row.planKey}'),
              plan: row,
              planIndex: r.plans.indexOf(row),
              bestReason: reason,
              onOpen: () => TaxiWaysNavigation.openPlan(c.openArgs(row)),
              onUse: canUse
                  ? () => c.actions.useForTrip(row, context: context)
                  : null,
              useBusy: c.busyPlans.contains(row.planKey),
              useNote: canUse && !noteShown && (noteShown = true),
              onAsk: () => c.actions.askDrivers(context, row),
              askBusy: c.busyPlans.contains(row.planKey),
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
      final twoCar = r.plans
          .where((p) => p.legs.length == 2 && p.carHires == 2)
          .toList();
      final cheapestDriver = r.allTheWay
          .map((d) => d.groupFare(people))
          .reduce((a, b) => a < b ? a : b);
      if (twoCar.isNotEmpty &&
          twoCar.map((p) => p.total).reduce((a, b) => a < b ? a : b) <
              cheapestDriver) {
        final names = <String>[];
        for (final p in twoCar) {
          final n = p.legs.first.to.name;
          if (n.isNotEmpty && !names.contains(n)) names.add(n);
          if (names.length == 2) break;
        }
        if (names.isNotEmpty)
          sub = TaxiWaysStrings.cheaperOneChange(
            TaxiWaysStrings.orPlaces(names),
          );
      }
    }
    return TitleRow3D(title: TaxiWaysStrings.orInCars(cars), subtitle: sub, tone: ListingTone.coral);
  }

  List<WayDriver> _companions(TaxiWaysResult r, WayDriver first) {
    final rest = _basedHereFirst(
      r.allTheWay.where((d) => d.taxiId != first.taxiId),
    );
    return [first, ...rest.take(2)];
  }

  static List<WayDriver> _basedHereFirst(Iterable<WayDriver> list) => [
    ...list.where((d) => d.basedHere),
    ...list.where((d) => !d.basedHere),
  ];

  Future<void> _useDriver(
    BuildContext context,
    TaxiWaysController c,
    TaxiWaysResult r,
    WayDriver d,
  ) => c.actions.useForTrip(c.singlePlan(_companions(r, d)), context: context);

  void _openDriver(TaxiWaysController c, TaxiWaysResult r, WayDriver d) {
    final plan = c.singlePlan(_companions(r, d));
    TaxiWaysNavigation.openPlan(c.openArgs(plan, synthetic: true));
  }

  List<Object> _ordered(List<Object> rows) {
    final g = _guide;
    if (g == null) return onTheWayLast(rows);
    return onTheWayLast(
      ShortlistOrder.noReplyLast(
        rows,
        (r) => r is WayDriver ? r.taxiId : '',
        _noReply.toSet(),
      ),
    );
  }

  void _toggleCar(GuideArgs g, WayDriver d) =>
      TripShortlistController.to.toggle(
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
          final byId = {
            for (final d in r?.allTheWay ?? const <WayDriver>[]) d.taxiId: d,
          };
          final drivers = [for (final id in ids) ?byId[id]];
          if (drivers.isEmpty)
            return Future.value(
              const AskResult(items: [], skipped: [], veryShortNotice: false),
            );
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

  Widget? _askTheseButton(
    BuildContext context,
    TaxiWaysController c,
    TaxiWaysResult r,
  ) {
    if (!c.fromMyLocation.value || r.allTheWay.isEmpty) return null;
    final drivers = _basedHereFirst(r.allTheWay).take(3).toList();
    final busy = c.busyPlans.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_side, 14, _side, 0),
      child: JourneyAskButton(
        label: JourneyAskButton.labelFor(drivers.length, these: true),
        busy: busy,
        onPressed: () => c.actions.askDrivers(context, c.singlePlan(drivers)),
      ),
    );
  }
}
