import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../config/app_tabs.dart';
import '../../controllers/tab_config_controller.dart';
import '../../design/design.dart';
import '../../utils/app_toast.dart';
import '../buddy/buddy_navigation.dart';
import '../buddy/viewer/controllers/shared_trips_controller.dart';
import '../trip/controllers/my_trips_controller.dart';
import '../trip/trip_navigation.dart';
import 'seeker_feed_controller.dart';
import 'seeker_trip_card.dart';
import 'strings/seeker_home_strings.dart';

class SeekerQuickAction {
  const SeekerQuickAction({required this.art, required this.tone, required this.title, required this.body, required this.add, required this.onTap});

  final String art;
  final ListingTone tone;
  final String title;
  final String body;
  final bool add;
  final VoidCallback onTap;
}

class ExpenseTripOption {
  const ExpenseTripOption(this.id, this.title);

  final String id;
  final String title;
}

abstract final class SeekerQuickActionTargets {
  static bool _open(DateTime? end, DateTime today) => end == null || !DateTime(end.year, end.month, end.day).isBefore(today);

  // D-21: trips that can still take an expense, my own first, then the ones shared with me; no duplicates.
  static List<ExpenseTripOption> openTrips({
    required Iterable<({String id, String title, DateTime? end, bool completed})> mine,
    required Iterable<({String id, String title, DateTime? end})> shared,
    String? feedTripId,
    String? feedTitle,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final out = <ExpenseTripOption>[];
    final seen = <String>{};
    void add(String id, String title) {
      if (id.isNotEmpty && seen.add(id)) out.add(ExpenseTripOption(id, title));
    }

    for (final t in mine) {
      if (!t.completed && _open(t.end, today)) add(t.id, t.title);
    }
    for (final t in shared) {
      if (_open(t.end, today)) add(t.id, t.title);
    }
    if (out.isEmpty && feedTripId != null) add(feedTripId, feedTitle ?? '');
    return out;
  }

  static List<ExpenseTripOption> _currentTrips() {
    final mine = Get.isRegistered<MyTripsController>() ? Get.find<MyTripsController>().active : const [];
    final shared = Get.isRegistered<SharedTripsController>() ? Get.find<SharedTripsController>().items : const [];
    final card = SeekerFeedController.maybe?.feed.value?.tripCard;
    return openTrips(
      mine: [for (final t in mine) (id: t.id, title: t.title, end: t.endDate, completed: t.isCompleted)],
      shared: [for (final t in shared) (id: t.tripId, title: t.title, end: t.endDate)],
      feedTripId: card?.tripId,
      feedTitle: card?.title,
    );
  }

  static Future<void> addExpense([BuildContext? context]) async {
    final trips = _currentTrips();
    if (trips.isEmpty) {
      AppToast.info(SeekerHomeStrings.planTripFirst);
      TripNavigation.openTripsTab();
      return;
    }
    if (trips.length == 1) {
      BuddyNavigation.openExpenses(trips.single.id);
      return;
    }
    final ctx = context ?? Get.context;
    if (ctx == null) return;
    final id = await ExpenseTripPicker.show(ctx, trips);
    if (id != null) BuddyNavigation.openExpenses(id);
  }

  static void findBuddy() => Get.toNamed(AppRoutes.buddies);
}

class ExpenseTripPicker extends StatelessWidget {
  const ExpenseTripPicker({super.key, required this.trips});

  final List<ExpenseTripOption> trips;

  static Future<String?> show(BuildContext context, List<ExpenseTripOption> trips) =>
      Sheet3D.show<String>(context, builder: (_) => ExpenseTripPicker(trips: trips));

  @override
  Widget build(BuildContext context) {
    return Sheet3D(
      tone: ListingTone.cF,
      art: ListingArt.moneyBag,
      title: SeekerHomeStrings.expensePickTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < trips.length; i++)
            SheetListRow(
              key: ValueKey('expense-trip-${trips[i].id}'),
              tone: ListingTone.cF,
              title: trips[i].title.isEmpty ? SeekerHomeStrings.myTrips : trips[i].title,
              divider: i > 0,
              compact: true,
              trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: Ink3D.grey),
              onTap: () => Navigator.of(context).pop(trips[i].id),
            ),
        ],
      ),
    );
  }
}

class SeekerQuickActions extends StatelessWidget {
  const SeekerQuickActions({super.key, this.actions});

  final List<SeekerQuickAction>? actions;

  static bool get _tripsOn => !Get.isRegistered<TabConfigController>() || TabConfigController.to.isActiveForIndex(AppTabs.trips);

  // FX-25: Plan a trip and My trips are hidden while the Trips module is off.
  static List<SeekerQuickAction> defaults({bool? tripsOn}) => [
    if (tripsOn ?? _tripsOn) SeekerQuickAction(
      art: ListingArt.worldMap,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tilePlanTitle,
      body: SeekerHomeStrings.tilePlanBody,
      add: true,
      onTap: SeekerTripActions.planTrip,
    ),
    if (tripsOn ?? _tripsOn) SeekerQuickAction(
      art: ListingArt.luggage,
      tone: ListingTone.teal,
      title: SeekerHomeStrings.tileTripsTitle,
      body: SeekerHomeStrings.tileTripsBody,
      add: false,
      onTap: SeekerTripActions.openMyTrips,
    ),
    SeekerQuickAction(
      art: ListingArt.moneyBag,
      tone: ListingTone.cF,
      title: SeekerHomeStrings.tileExpenseTitle,
      body: SeekerHomeStrings.tileExpenseBody,
      add: true,
      onTap: SeekerQuickActionTargets.addExpense,
    ),
    SeekerQuickAction(
      art: ListingArt.panda,
      tone: ListingTone.cB,
      title: SeekerHomeStrings.tileBuddyTitle,
      body: SeekerHomeStrings.tileBuddyBody,
      add: false,
      onTap: SeekerQuickActionTargets.findBuddy,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final given = actions;
    if (given != null) return _build(given);
    if (!Get.isRegistered<TabConfigController>()) return _build(defaults());
    return Obx(() {
      TabConfigController.to.version.value;
      return _build(defaults());
    });
  }

  Widget _build(List<SeekerQuickAction> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: const TitleRow3D(title: SeekerHomeStrings.quickActions)),
        LayoutBuilder(
          builder: (context, box) {
            final width = tileWidth(box.maxWidth);
            return MealsRail(
              physics: const BouncingScrollPhysics(),
              children: [
                for (final a in list)
                  MealsCardV(
                    key: ValueKey('seeker-qa-${a.title}'),
                    width: width,
                    tone: a.tone,
                    art: a.art,
                    title: a.title,
                    minCardHeight: 0,
                    goIcon: a.add ? Icons.add : Icons.arrow_forward,
                    onTap: a.onTap,
                    semanticsLabel: '${a.title}, ${a.body}',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static double tileWidth(double maxWidth) {
    final w = (maxWidth - DS.s(20)) / 3.1;
    return w.clamp(DS.s(104), DS.s(160)).toDouble();
  }
}
