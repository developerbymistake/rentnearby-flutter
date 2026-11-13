import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../models/browse_item.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import 'change_driver_controller.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_strings.dart';

class ChangeDriverSheet {
  /// Returns the picked driver, or null when dismissed or the current driver was tapped.
  static Future<WayDriver?> show(
    BuildContext context, {
    required WayLeg leg,
    required int people,
    required WayDriver? current,
  }) =>
      TripSheetFrame.show<WayDriver>(context, _ChangeDriverBody(leg: leg, people: people, current: current));
}

class _ChangeDriverBody extends StatefulWidget {
  final WayLeg leg;
  final int people;
  final WayDriver? current;

  const _ChangeDriverBody({required this.leg, required this.people, required this.current});

  @override
  State<_ChangeDriverBody> createState() => _ChangeDriverBodyState();
}

class _ChangeDriverBodyState extends State<_ChangeDriverBody> with TickerProviderStateMixin {
  late final String _tag = 'change-driver-${widget.leg.legKey}-${identityHashCode(this)}';
  late final ChangeDriverController _ctrl;
  late final AnimationController _ac = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ChangeDriverController(leg: widget.leg, people: widget.people), tag: _tag);
  }

  Widget _enter(int i, Widget child) => TemplateEntrance(
        animation: templateInterval(_ac, i < 7 ? i : 7, 8),
        animationController: _ac,
        child: child,
      );

  @override
  void dispose() {
    _ac.dispose();
    Get.delete<ChangeDriverController>(tag: _tag);
    super.dispose();
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _pick(WayDriver d) {
    final isCurrent = widget.current?.taxiId == d.taxiId;
    Navigator.of(context).pop(isCurrent ? null : d);
  }

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
    return Obx(() {
      final count = _ctrl.total.value > 0 ? _ctrl.total.value : leg.driverCount;
      return TripSheetFrame(
        tone: ListingTone.coral,
        art: ListingArt.taxi,
        size: SheetSize.list,
        title: TaxiWaysStrings.changeDriver,
        description: TaxiWaysStrings.driversOn(leg.from.name, leg.to.name, count),
        children: [
          _enter(0, LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    JourneyFilterPill3D(label: TaxiWaysStrings.seats6, selected: _ctrl.seats6.value, onTap: _ctrl.toggleSeats6),
                    const SizedBox(width: 6),
                    JourneyFilterPill3D(label: TaxiWaysStrings.suv, selected: _ctrl.suv.value, onTap: _ctrl.toggleSuv),
                    const SizedBox(width: 6),
                    JourneyFilterPill3D(label: _cap(TaxiWaysStrings.repliesInApp), selected: _ctrl.repliesOnly.value, onTap: _ctrl.toggleReplies),
                    const SizedBox(width: 6),
                    JourneyFilterPill3D(
                      label: TaxiWaysStrings.lowestPrice,
                      selected: _ctrl.sort.value == ChangeDriverSort.lowestPrice,
                      onTap: _ctrl.toggleLowestPrice,
                    ),
                  ],
                ),
              ),
            ),
          )),
          ..._content(),
        ],
      );
    });
  }

  List<Widget> _content() {
    if (_ctrl.isLoading.value) {
      return [
        const SizedBox(height: 22),
        for (var i = 0; i < 4; i++) const JourneyDriverPickSkeleton(),
      ];
    }
    if (_ctrl.loadFailed.value) {
      final offline = _ctrl.isOffline.value;
      return [
        JourneyEmpty3D(
          compact: true,
          art: offline ? ListingArt.worldMap : ListingArt.clipboard,
          title: offline ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          body: offline ? TaxiWaysStrings.offlineBody : null,
          actionLabel: TaxiWaysStrings.retry,
          onAction: _ctrl.retry,
        ),
      ];
    }
    if (_ctrl.items.isEmpty) {
      return const [
        JourneyEmpty3D(
          compact: true,
          art: ListingArt.taxi,
          title: TaxiWaysStrings.noDriversMatch,
          body: TaxiWaysStrings.noDriversMatchBody,
        ),
      ];
    }
    final shown = _ctrl.items.length;
    final bestFit = _ctrl.sort.value == ChangeDriverSort.bestFit;
    return [
      _enter(
        1,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            bestFit
                ? TaxiWaysStrings.bestFitFirst(widget.people, shown, _ctrl.total.value)
                : TaxiWaysStrings.showingCount(shown, _ctrl.total.value),
            style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35),
          ),
        ),
      ),
      for (var i = 0; i < _ctrl.items.length; i++)
        _enter(
          i + 2,
          _DriverRow(
            driver: _ctrl.items[i],
            people: widget.people,
            isCurrent: widget.current?.taxiId == _ctrl.items[i].taxiId,
            isLowest: _ctrl.isLowest(_ctrl.items[i]),
            onTap: () => _pick(_ctrl.items[i]),
          ),
        ),
      if (_ctrl.hasMore.value) _moreButton(),
    ];
  }

  Widget _moreButton() {
    final tone = ListingTone.coral;
    if (_ctrl.isLoadingMore.value) {
      return SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: tone.g2)),
        ),
      );
    }
    final failed = _ctrl.moreFailed.value;
    final label = failed ? TaxiWaysStrings.retry : TaxiWaysStrings.showMore(_ctrl.remaining);
    return Tap3D(
      onTap: _ctrl.loadMore,
      label: label,
      child: SizedBox(
        height: 52,
        child: Center(child: Text(label, style: Ink3D.text(14, FontWeight.w700, tone.text))),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final WayDriver driver;
  final int people;
  final bool isCurrent;
  final bool isLowest;
  final VoidCallback onTap;

  const _DriverRow({
    required this.driver,
    required this.people,
    required this.isCurrent,
    required this.isLowest,
    required this.onTap,
  });

  String _subtitle() {
    final vehicle = driver.vehicleTypeName;
    final seats = driver.seats;
    return [
      if (vehicle.isNotEmpty) vehicle,
      if (seats != null) TaxiWaysStrings.seatsCount(seats),
      if (driver.tripReplyLabel == 'app') TaxiWaysStrings.repliesInApp,
      if (driver.basedHere) TaxiWaysStrings.basedHere,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final fare = driver.fare > 0 ? driver.groupFare(people) : null;
    return JourneyDriverPick3D(
      art: JourneyArt.forVehicle(driver.vehicleTypeName, driver.seats),
      name: driver.driverName,
      subtitle: _subtitle(),
      fare: fare == null ? null : BrowseItem.inr(fare),
      current: isCurrent,
      lowest: isLowest,
      currentLabel: TaxiWaysStrings.current,
      lowestLabel: TaxiWaysStrings.lowestTag,
      onTap: onTap,
    );
  }
}
