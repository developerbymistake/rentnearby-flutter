import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_hero_card.dart';
import '../../buddy_navigation.dart';
import '../../ledger/data/ledger_api.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/view_only_chip.dart';
import '../controllers/viewer_trip_controller.dart';
import '../data/trip_viewer_api.dart';
import '../models/viewer_models.dart';
import '../viewer_deps.dart';
import '../viewer_look.dart';
import '../viewer_rules.dart';
import '../viewer_strings.dart';
import '../widgets/trip_ended_view.dart';
import '../widgets/viewer_booking_sheet.dart';
import '../widgets/viewer_overview_header.dart';

class ViewerTripScreen extends StatefulWidget {
  const ViewerTripScreen({super.key, required this.tripId, this.deleted = false, this.api, this.ledger});

  final String tripId;
  final bool deleted;
  final TripViewerApi? api;
  final LedgerApi? ledger;

  @override
  State<ViewerTripScreen> createState() => _ViewerTripScreenState();
}

class _ViewerTripScreenState extends State<ViewerTripScreen> {
  late final ViewerTripController _c;
  late final AppLifecycleListener _life;
  Worker? _ownerWorker;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ViewerTripController>(tag: widget.tripId)) Get.delete<ViewerTripController>(tag: widget.tripId, force: true);
    _c = Get.put(ViewerTripController(widget.tripId, startDeleted: widget.deleted, api: widget.api, ledger: widget.ledger), tag: widget.tripId);
    _life = AppLifecycleListener(onResume: _c.load);
    _ownerWorker = ever<ViewerTripState>(_c.state, _onState);
    _onState(_c.state.value);
  }

  void _onState(ViewerTripState s) {
    if (s != ViewerTripState.owner || _redirected) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => BuddyNavigation.openOwnerOverview(widget.tripId, replace: true));
  }

  @override
  void dispose() {
    _ownerWorker?.dispose();
    _life.dispose();
    if (identical(ViewerTripController.maybeOf(widget.tripId), _c)) Get.delete<ViewerTripController>(tag: widget.tripId, force: true);
    super.dispose();
  }

  void _back() => Get.back<void>();

  @override
  Widget build(BuildContext context) => Obx(() {
        final s = _c.state.value;
        final t = _c.trip.value;
        switch (s) {
          case ViewerTripState.notOnTrip:
            return _notOnTrip(_c.notOnTrip.value ?? const NotOnTripInfo(hasShare: false), t);
          case ViewerTripState.deleted:
            return _deleted(t);
          case ViewerTripState.ready when t != null:
            return _overview(t);
          case ViewerTripState.failed:
            return _plain(StateCard3D(
              tone: BuddyLook.indigo,
              art: BuddyArt.antenna,
              title: BuddySharedStrings.couldNotLoad,
              message: BuddySharedStrings.couldNotLoadLine,
              actionLabel: BuddySharedStrings.retry,
              onAction: _c.load,
              layout: StateLayout.tall,
            ));
          default:
            return _plain(const _Skeleton());
        }
      });

  Widget _plain(Widget body) => BuddyPage(title: ViewerStrings.overviewTitle, onBack: _back, body: body);

  Widget _overview(ViewerTrip t) {
    final e = t.expenses;
    final cards = <Widget>[
      TripHeroCard(
        key: const ValueKey('viewer_itinerary_card'),
        tone: BuddyLook.indigo,
        asset: ListingArt.compass,
        title: ViewerStrings.itinerary,
        chip: ViewerStrings.savedChip,
        line: ViewerStrings.itineraryLine(t.dayCount, t.spotCount, hasDates: t.startDate != null),
        button: ViewerStrings.view,
        buttonKey: const ValueKey('viewer_itinerary_button'),
        onTap: () => BuddyNavigation.openDayPlan(t.tripId),
        compact: true,
      ),
      _taxiCard(t.taxi),
      _stayCard(t.stay),
      TripHeroCard(
        key: const ValueKey('viewer_travellers_card'),
        tone: BuddyLook.teal,
        asset: BuddyArt.panda,
        title: ViewerStrings.travellers,
        chipWidget: t.firstTravellers.isEmpty
            ? null
            : BuddyAvatarStack(people: [for (final p in t.firstTravellers) (initial: p.initial, seed: p.userId, photoUrl: p.photoUrl)], extra: t.travellerCount - t.firstTravellers.length),
        line: ViewerStrings.joined(t.travellerCount),
        button: ViewerStrings.seeAll,
        buttonKey: const ValueKey('viewer_travellers_button'),
        onTap: () => BuddyNavigation.openTravellers(t.tripId),
        compact: true,
      ),
      TripHeroCard(
        key: const ValueKey('viewer_expenses_card'),
        tone: BuddyLook.rose,
        asset: BuddyArt.moneyBag,
        title: ViewerStrings.expenses,
        chip: e.hasExpenses && (e.dayToday ?? 0) > 0 ? ViewerStrings.dayChip(e.dayToday!) : null,
        line: e.hasExpenses ? ViewerStrings.spentLine(e.spent, e.myShare) : ViewerStrings.noExpenses(t.owner.name),
        button: e.hasExpenses ? ViewerStrings.view : null,
        buttonKey: const ValueKey('viewer_expenses_button'),
        onTap: e.hasExpenses ? () => BuddyNavigation.openMoneyHome(t.tripId, tripEnded: _c.tripEnded, settled: e.settled) : null,
        compact: true,
      ),
    ];
    return BuddyPage(
      title: ViewerStrings.overviewTitle,
      header: ViewerOverviewHeader(
        title: ViewerStrings.overviewTitle,
        subtitle: ViewerStrings.sharedBy(t.owner.name),
        onBack: _back,
        trailing: const [ViewOnlyChip()],
        tripTitle: t.title,
        tripLine: ViewerStrings.tripLine(t.legCities.isEmpty ? t.legs.length : t.legCities.length, t.dayCount, t.travellerCount),
      ),
      top: _c.offline.value
          ? NoteBanner(
              key: const ValueKey('viewer_offline'),
              art: BuddyArt.antenna,
              text: ViewerStrings.offlineCopy,
              tone: NoteTone.amber,
              margin: DS.insets(l: 18, t: 14, r: 18),
            )
          : null,
      scroll: false,
      body: RefreshIndicator(
        color: BuddyLook.indigo.g2,
        onRefresh: _c.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: DS.insets(l: 18, t: 20, r: 18, b: 40),
          children: [
            for (var i = 0; i < cards.length; i++) ...[if (i > 0) Gap.v(12), cards[i]],
          ],
        ),
      ),
    );
  }

  Widget _taxiCard(ViewerTaxi x) {
    final booked = x.state == ViewerBookingState.booked || x.state == ViewerBookingState.completed;
    final chip = switch (x.state) {
      ViewerBookingState.booked => ViewerStrings.bookedChip,
      ViewerBookingState.completed => ViewerStrings.completedChip,
      ViewerBookingState.arranging => ViewerStrings.arrangingChip,
      _ => null,
    };
    return TripHeroCard(
      key: const ValueKey('viewer_taxi_card'),
      tone: ListingTone.sunrise,
      asset: ListingArt.taxi,
      title: ViewerStrings.taxi,
      chip: chip,
      line: booked ? ViewerStrings.taxiLine(x.vehicleType, x.driverFirstName, ViewerRules.taxiWhen(x)) : ViewerStrings.notBookedYet,
      button: booked ? ViewerStrings.viewBooking : null,
      buttonKey: const ValueKey('viewer_taxi_button'),
      onTap: booked ? () => ViewerBookingSheet.taxi(context, x) : null,
      compact: true,
    );
  }

  Widget _stayCard(ViewerStay x) {
    final booked = (x.state == ViewerBookingState.booked || x.state == ViewerBookingState.completed) && x.items.isNotEmpty;
    final chip = switch (x.state) {
      ViewerBookingState.booked || ViewerBookingState.completed => ViewerStrings.bookedChip,
      ViewerBookingState.arranging => ViewerStrings.arrangingChip,
      _ => null,
    };
    final first = x.items.isEmpty ? null : x.items.first;
    return TripHeroCard(
      key: const ValueKey('viewer_stay_card'),
      tone: ListingTone.forest,
      asset: ListingArt.camping,
      title: ViewerStrings.stay,
      chip: chip,
      line: booked && first != null ? ViewerStrings.stayLine(first.stayName, first.nights, x.items.length - 1) : ViewerStrings.notBookedYet,
      button: booked ? ViewerStrings.viewStays : null,
      buttonKey: const ValueKey('viewer_stay_button'),
      onTap: booked ? () => ViewerBookingSheet.stays(context, x) : null,
      compact: true,
    );
  }

  Widget _notOnTrip(NotOnTripInfo info, ViewerTrip? saved) {
    final owner = info.ownerName ?? saved?.owner.name;
    final title = info.title ?? saved?.title;
    final dates = BuddyFormat.dateRange(info.startDate ?? saved?.startDate, info.endDate ?? saved?.endDate);
    return BuddyPage(
      title: ViewerStrings.overviewTitle,
      subtitle: owner == null || owner.isEmpty ? null : ViewerStrings.sharedBy(owner),
      onBack: _back,
      body: TripEndedView(
        key: const ValueKey('viewer_not_on_trip'),
        art: BuddyArt.locked,
        haloColor: ViewerLook.indigoHalo,
        title: ViewerStrings.noLongerOnTrip,
        line: info.hasShare ? ViewerStrings.shareStillOpen : null,
        ghostTitle: title,
        ghostLine: ViewerStrings.ghostLine(dates, owner),
      ),
      bottomBar: BuddyBottomBar(
        children: [
          info.hasShare
              ? GradientPillButton(
                  key: const ValueKey('viewer_see_share'),
                  tone: BuddyLook.rose,
                  label: ViewerStrings.seeMyShare,
                  onTap: () => BuddyNavigation.openMyShare(widget.tripId, replace: true),
                )
              : GradientPillButton(key: const ValueKey('viewer_go_trips'), tone: BuddyLook.teal, label: ViewerStrings.goToMyTrips, onTap: () => ViewerDeps.toMyTrips()),
        ],
      ),
    );
  }

  Widget _deleted(ViewerTrip? saved) {
    final owner = saved?.owner.name;
    return BuddyPage(
      title: ViewerStrings.overviewTitle,
      subtitle: owner == null || owner.isEmpty ? null : ViewerStrings.sharedBy(owner),
      onBack: _back,
      body: TripEndedView(
        key: const ValueKey('viewer_deleted'),
        art: BuddyArt.warning,
        haloColor: ViewerLook.redHalo,
        title: ViewerStrings.tripDeleted,
        line: ViewerStrings.tripDeletedLine,
        ghostTitle: saved?.title,
        ghostLine: saved == null ? '' : ViewerStrings.ghostLine(BuddyFormat.dateRange(saved.startDate, saved.endDate), owner),
      ),
      bottomBar: BuddyBottomBar(
        children: [
          GradientPillButton(key: const ValueKey('viewer_go_trips'), tone: BuddyLook.teal, label: ViewerStrings.goToMyTrips, onTap: () => ViewerDeps.toMyTrips()),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('viewer_loading'),
        padding: DS.insets(l: 18, t: 20, r: 18),
        child: Column(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Container(height: DS.s(112), decoration: BoxDecoration(color: ViewerLook.ghostBg, borderRadius: DS.br(CardRadius.hero))),
              Gap.v(12),
            ],
          ],
        ),
      );
}
