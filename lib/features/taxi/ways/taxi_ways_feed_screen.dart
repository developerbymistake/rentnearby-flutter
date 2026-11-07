import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/module_palette.dart';
import '../../../models/place_result_model.dart';
import '../../../config/app_insets.dart';
import '../../../widgets/empty_state_view.dart';
import '../../trip/controllers/trip_plan_controller.dart';
import '../../trip/trip_colors.dart';
import '../../trip/trip_strings_final_aa.dart';
import '../../trip/trip_strings_steps_a3.dart';
import '../../trip/trip_strings_v2_find.dart';
import '../../trip/widgets/trip_journey_card.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../journeys/journey_models.dart';
import '../journeys/journeys_controller.dart';
import '../taxi_option_sets.dart';
import 'destination_section.dart';
import 'widgets/journey_driver_card.dart';
import 'journey_plan_screen.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_controller.dart';
import 'taxi_ways_navigation.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';
import 'trip_strings_mcb_a2.dart';
import 'widgets/journey_total_bar.dart';
import 'widgets/way_driver_row.dart';
import 'widgets/way_plan_ribbon_card.dart';
import 'widgets/ways_sort_chips.dart';

class TaxiWaysFeedScreen extends StatefulWidget {
  const TaxiWaysFeedScreen({super.key});

  @override
  State<TaxiWaysFeedScreen> createState() => _TaxiWaysFeedScreenState();
}

class _TaxiWaysFeedScreenState extends State<TaxiWaysFeedScreen> {
  static const double _maxWidth = 720;

  TaxiWaysController? _c;
  String? _tag;
  bool _read = false;

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
      _c = Get.put(
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
      JourneysController.ensure().load();
    }
  }

  @override
  void dispose() {
    if (_tag != null) Get.delete<TaxiWaysController>(tag: _tag);
    super.dispose();
  }

  Widget _centred(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(children: [
          JourneyPlanScreen.header(context, title: TaxiWaysStrings.title),
          Expanded(
            child: ListView(children: [
              EmptyStateView(
                icon: Iconsax.routing_2,
                title: TaxiWaysStrings.noWays,
                subtitle: TripStringsA6.waysGoneBody,
                onRetry: () => Get.back(),
                retryLabel: TripStringsA6.goBack,
                palette: ModulePalette.taxi,
              ),
            ]),
          ),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      bottomNavigationBar: c.forTrip || c.forSegment ? _arrangeBar(context, c) : null,
      body: RefreshIndicator(
        color: TaxiColors.accent,
        onRefresh: c.pullRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context, c)),
            SliverToBoxAdapter(child: _centred(Obx(() => _body(context, c)))),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(TaxiWaysStrings.faresNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
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
        style: TextButton.styleFrom(foregroundColor: TaxiColors.accentDark, minimumSize: const Size(64, 48)),
        child: const Text(TripStringsV2Find.skip,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _arrangeBar(BuildContext context, TaxiWaysController c) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 6, 16, 6 + AppInsets.bottomViewPadding(context)),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => _arrangeMyself(context, c),
                style: TextButton.styleFrom(
                  foregroundColor: TaxiColors.accentDark,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text(
                  TripStringsStepsA3.arrangeMyself,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _skipButton(() => _skipTravel(c)),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TaxiWaysController c) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TaxiColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(8, top + 6, 8, 16),
      child: _centred(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                TaxiWaysStrings.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              if (c.inTrip)
                Obx(() => Text(
                      TripStringsA6.feedSubtitle(c.date.value, c.people.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    )),
            ]),
          ),
          _journeysButton(),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Obx(() => Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _dateChip(context, c),
                  _peopleStepper(c),
                ])),
            if (c.lockedDate)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  TripStringsMcbA2.travelDayOfTrip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            const SizedBox(height: 12),
            Obx(() => _routeCard(c)),
          ]),
        ),
      ])),
    );
  }

  Widget _journeysButton() {
    final j = JourneysController.ensure();
    return Obx(() {
      final alert = j.journeys.any((e) => e.status == JourneyStatus.driverUnavailable);
      return SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          tooltip: TaxiWaysStrings.myJourneys,
          onPressed: () => TaxiWaysNavigation.openMyJourneys(),
          icon: Stack(clipBehavior: Clip.none, children: [
            const Icon(Iconsax.bookmark, color: Colors.white, size: 22),
            if (alert)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }

  Widget _pill({required Widget child, VoidCallback? onTap}) => Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: child),
        ),
      );

  Widget _dateChip(BuildContext context, TaxiWaysController c) {
    final locked = c.lockedDate;
    final chip = _pill(
      onTap: locked ? null : () => _pickDate(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(locked ? Iconsax.lock : Iconsax.calendar_1, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _dateText(c.date.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ]),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: c.date.value,
      firstDate: TaxiWaysController.firstDate(),
      lastDate: TaxiWaysController.lastDate(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: TaxiColors.accentDark, onPrimary: Colors.white),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) c.setDate(picked);
  }

  Widget _peopleStepper(TaxiWaysController c) {
    final n = c.people.value;
    if (c.lockedPeople) {
      return _pill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Iconsax.people, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              TaxiWaysStrings.people(n),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ]),
        ),
      );
    }
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 16, color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4)),
          ),
        );
    return _pill(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Iconsax.minus, n > 1, () => c.setPeople(n - 1)),
        const Icon(Iconsax.people, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          TaxiWaysStrings.people(n),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        btn(Iconsax.add, n < TaxiWaysController.maxPeople, () => c.setPeople(n + 1)),
      ]),
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
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight),
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 4),
                const Icon(Iconsax.lock, size: 11, color: AppColors.textLight),
              ],
            ]),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
            ),
          ],
        );
    final fromLabel = c.fromMyLocation.value ? TaxiWaysStrings.fromMyLocationLabel : TaxiWaysStrings.fromLabel;
    final day = c.segmentDay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: end(fromLabel, fromName, CrossAxisAlignment.start)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: TaxiColors.accent),
          ),
          Expanded(child: end(TaxiWaysStrings.toLabel, toName, CrossAxisAlignment.end)),
        ]),
        if (locked && day != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: TaxiColors.surface, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Iconsax.routing, size: 14, color: TaxiColors.accentDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  TripStringsMcbA2.fromYourTrip(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: TaxiColors.accentDark),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _body(BuildContext context, TaxiWaysController c) {
    final r = c.result.value;
    if (r == null) {
      if (c.isLoading.value) return _skeleton();
      return EmptyStateView(
        icon: c.isOffline.value ? Iconsax.wifi_square : Iconsax.cloud_cross,
        title: c.isOffline.value
            ? TaxiWaysStrings.offlineTitle
            : (c.tabOff.value ? TaxiWaysStrings.taxisOff : TaxiWaysStrings.loadFailed),
        subtitle: c.isOffline.value || c.errorText.value.isEmpty ? TaxiWaysStrings.offlineBody : c.errorText.value,
        onRetry: c.tabOff.value ? null : c.retry,
        retryLabel: TaxiWaysStrings.retry,
        palette: ModulePalette.taxi,
      );
    }
    final rows = c.rows;
    final sort = c.sort.value;
    final children = <Widget>[];
    if (c.isLoading.value) {
      children.add(const LinearProgressIndicator(minHeight: 2, color: TaxiColors.accent, backgroundColor: Colors.transparent));
    }
    if (c.isOffline.value) children.add(_offlineBanner());
    if (rows.length > 1) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: WaysSortChips(value: sort, onChanged: c.setSort),
      ));
    }
    if (!r.hasWays && c.forSegment) {
      children.add(Padding(padding: const EdgeInsets.only(top: 16), child: _gapCard(context, c, r)));
    } else if (!r.hasWays) {
      children.add(EmptyStateView(
        icon: Iconsax.routing_2,
        title: TaxiWaysStrings.noWays,
        subtitle: TaxiWaysStrings.noWaysBody(r.to.name.isNotEmpty ? r.to.name : c.to.value.name),
        palette: ModulePalette.taxi,
      ));
    } else {
      if (r.allTheWay.isEmpty && r.plans.isNotEmpty) {
        children.add(_note(r.plans.first.legs.length >= 3 ? TaxiWaysStrings.noDirect3 : TaxiWaysStrings.noDirect2));
      }
      children.addAll(_rows(context, c, r, rows, sort));
      final ask = _askTheseButton(context, c, r);
      if (ask != null) children.add(ask);
    }
    if (!c.inTrip) {
      children.add(const SizedBox(height: 24));
      children.add(AtDestinationSection(
        cityName: r.to.name.isNotEmpty ? r.to.name : c.to.value.name,
        date: c.date.value,
        people: c.people.value,
        localTaxis: r.localTaxis,
        stays: r.stays,
        reachFirstPlace: r.reachFirstPlace,
        hasWays: r.hasWays,
      ));
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Iconsax.info_circle, size: 15, color: AppColors.textHint),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            '${TaxiWaysStrings.listedFares} ${TaxiWaysStrings.payLine}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
          ),
        ),
      ]),
    ));
    children.add(SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Future<void> _getThereMyself(BuildContext context, TaxiWaysController c) async {
    final k = c.tripLegIndex;
    if (k == null) return;
    if (!Get.isRegistered<TripPlanController>()) return;
    if (await TripJourneyCard.arrangeMyself(context, legIndex: k)) await c.actions.arrangedMyself();
  }

  Widget _gapCard(BuildContext context, TaxiWaysController c, TaxiWaysResult r) {
    final from = r.from.name.isNotEmpty ? r.from.name : c.from.value.name;
    final to = r.to.name.isNotEmpty ? r.to.name : c.to.value.name;
    final hub = c.gapHub;
    final busy = c.isLoading.value;
    final mine = ElevatedButton(
      onPressed: busy ? null : () => _getThereMyself(context, c),
      style: ElevatedButton.styleFrom(
        backgroundColor: TaxiColors.accentDark,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(TripStringsMcbA2.getThereMyself,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
    );
    final again = OutlinedButton(
      onPressed: busy ? null : c.retry,
      style: OutlinedButton.styleFrom(
        foregroundColor: TaxiColors.accentDark,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: TaxiColors.accent.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(TripStringsMcbA2.searchAgain,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TripColors.accent.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Iconsax.driving, size: 20, color: TripColors.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                TripStringsMcbA2.noDriverGoes(from, to),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 2),
              const Text(
                TripStringsMcbA2.nobodyListed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: TripColors.accentDark),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          TripStringsMcbA2.reachHubThen(hub, to),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium, height: 1.35),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 340) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [again, const SizedBox(height: 8), mine]);
          }
          return Row(children: [Expanded(child: mine), const SizedBox(width: 10), Expanded(child: again)]);
        }),
        Align(alignment: Alignment.center, child: _skipButton(() => _skipTravel(c))),
      ]),
    );
  }

  Widget _skeleton() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: [
          TripShimmers.rowBox(height: 44, radius: 22),
          const SizedBox(height: 12),
          TripShimmers.rowBox(),
          const SizedBox(height: 12),
          TripShimmers.rowBox(),
          const SizedBox(height: 12),
          TripShimmers.rowBox(height: 150, radius: 18),
        ]),
      );

  Widget _offlineBanner() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Iconsax.wifi_square, size: 18, color: AppColors.warningText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '${TaxiWaysStrings.offlineTitle} · ${TaxiWaysStrings.offlineBody}',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium),
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
    final people = c.people.value;
    for (final row in rows) {
      final cars = rowCars(row, people);
      if (sort == WaysSort.fewestCars && lastCars != 0 && cars != lastCars) {
        out.add(_groupHeader(r, cars, people));
      }
      lastCars = cars;
      String? reason;
      if (!bestShown) {
        reason = _bestReason(r, row);
        if (reason != null) bestShown = true;
      }
      out.add(const SizedBox(height: 12));
      if (row is WayDriver) {
        out.add(WayDriverRow(
          key: ValueKey('d-${row.taxiId}'),
          driver: row,
          people: people,
          bestReason: reason,
          onTap: () => _openDriver(c, r, row),
          onCall: () => JourneyDriverCard.call(row),
          onUse: canUse ? () => _useDriver(context, c, r, row) : null,
          useBusy: c.busyPlans.isNotEmpty,
        ));
      } else if (row is WayPlan) {
        out.add(WayPlanRibbonCard(
          key: ValueKey('p-${row.planKey}'),
          plan: row,
          planIndex: r.plans.indexOf(row),
          bestReason: reason,
          onOpen: () => TaxiWaysNavigation.openPlan(c.openArgs(row)),
          onUse: canUse ? () => c.actions.useForTrip(row, context: context) : null,
          useBusy: c.busyPlans.contains(row.planKey),
          useNote: canUse && !noteShown && (noteShown = true),
        ));
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          TaxiWaysStrings.orInCars(cars),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        if (sub != null)
          Text(
            sub,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
      ]),
    );
  }

  List<WayDriver> _companions(TaxiWaysResult r, WayDriver first) {
    final rest = _basedHereFirst(r.allTheWay.where((d) => d.taxiId != first.taxiId));
    return [first, ...rest.take(2)];
  }

  static List<WayDriver> _basedHereFirst(Iterable<WayDriver> list) =>
      [...list.where((d) => d.basedHere), ...list.where((d) => !d.basedHere)];

  Future<void> _useDriver(BuildContext context, TaxiWaysController c, TaxiWaysResult r, WayDriver d) =>
      c.actions.useForTrip(c.singlePlan(_companions(r, d)), context: context);

  void _openDriver(TaxiWaysController c, TaxiWaysResult r, WayDriver d) {
    final plan = c.singlePlan(_companions(r, d));
    TaxiWaysNavigation.openPlan(c.openArgs(plan, synthetic: true));
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
