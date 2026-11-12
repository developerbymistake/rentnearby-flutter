import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
        title: TaxiWaysStrings.changeDriver,
        description: TaxiWaysStrings.driversOn(leg.from.name, leg.to.name, count),
        children: [
          _enter(0, Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(TaxiWaysStrings.seats6, _ctrl.seats6.value, _ctrl.toggleSeats6),
              _chip(TaxiWaysStrings.suv, _ctrl.suv.value, _ctrl.toggleSuv),
              _chip(_cap(TaxiWaysStrings.repliesInApp), _ctrl.repliesOnly.value, _ctrl.toggleReplies),
              _chip(
                TaxiWaysStrings.lowestPrice,
                _ctrl.sort.value == ChangeDriverSort.lowestPrice,
                _ctrl.toggleLowestPrice,
              ),
            ],
          )),
          const SizedBox(height: 12),
          ..._content(),
        ],
      );
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: PickChip(
            label: label,
            selected: selected,
            onTap: onTap,
            activeColor: DesignColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          ),
        ),
      );

  List<Widget> _content() {
    if (_ctrl.isLoading.value) {
      return [
        for (var i = 0; i < 3; i++) ...[
          const TemplatePlaceholder(height: 68, radius: 14),
          const SizedBox(height: 8),
        ],
      ];
    }
    if (_ctrl.loadFailed.value) {
      final offline = _ctrl.isOffline.value;
      return [
        TripPlanEmpty(
          image: offline ? TravelIcon.map : TravelIcon.route,
          title: offline ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          subtitle: offline ? TaxiWaysStrings.offlineBody : '',
          retryLabel: TaxiWaysStrings.retry,
          onRetry: _ctrl.retry,
        ),
      ];
    }
    if (_ctrl.items.isEmpty) {
      return [
        const TripPlanEmpty(
          image: TravelIcon.taxi,
          title: TaxiWaysStrings.noDriversMatch,
          subtitle: TaxiWaysStrings.noDriversMatchBody,
        ),
      ];
    }
    final shown = _ctrl.items.length;
    final bestFit = _ctrl.sort.value == ChangeDriverSort.bestFit;
    return [
      _enter(
        1,
        Text(
          bestFit
              ? TaxiWaysStrings.bestFitFirst(widget.people, shown, _ctrl.total.value)
              : TaxiWaysStrings.showingCount(shown, _ctrl.total.value),
          style: FitnessAppTheme.caption.copyWith(fontSize: 11, height: 1.35),
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _ctrl.items.length; i++) ...[
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
        const SizedBox(height: 8),
      ],
      if (_ctrl.hasMore.value) _moreButton(),
    ];
  }

  Widget _moreButton() {
    if (_ctrl.isLoadingMore.value) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: DesignColors.primary),
          ),
        ),
      );
    }
    final failed = _ctrl.moreFailed.value;
    return InkWell(
      onTap: _ctrl.loadMore,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(
            failed ? TaxiWaysStrings.retry : TaxiWaysStrings.showMore(_ctrl.remaining),
            style: FitnessAppTheme.title.copyWith(fontSize: 13, color: DesignColors.primary),
          ),
        ),
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
    final subtitle = _subtitle();
    return Semantics(
      button: true,
      child: Container(
        decoration: TripLook.card(
          color: isCurrent ? TripLook.surface : DesignColors.surface,
          radius: TripLook.softRadius,
          shadowColor: isCurrent ? DesignColors.primary : DesignColors.textGrey,
        ),
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: TripLook.softRadius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? null : PickKit.taxiTint,
                    gradient: isCurrent ? PickKit.taxiGradient : null,
                    shape: BoxShape.circle,
                  ),
                  child: const TravelIcon(TravelIcon.taxi, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            driver.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FitnessAppTheme.title.copyWith(fontSize: 13),
                          ),
                          if (isCurrent)
                            _tag(TaxiWaysStrings.current, PickKit.tripTint, DesignColors.primary),
                          if (isLowest) _tag(TaxiWaysStrings.lowestTag, PickKit.goodTint, PickKit.goodDark),
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, height: 1.3),
                          ),
                        ),
                    ],
                  ),
                ),
                if (fare != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        BrowseItem.inr(fare),
                        style: FitnessAppTheme.title.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: DesignColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}
