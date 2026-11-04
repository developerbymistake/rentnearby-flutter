import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/selectable_chip.dart';
import '../../trip/trip_colors.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../taxi_option_sets.dart';
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

class _ChangeDriverBodyState extends State<_ChangeDriverBody> {
  late final String _tag = 'change-driver-${widget.leg.legKey}-${identityHashCode(this)}';
  late final ChangeDriverController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ChangeDriverController(leg: widget.leg, people: widget.people), tag: _tag);
  }

  @override
  void dispose() {
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
          Wrap(
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
          ),
          const SizedBox(height: 12),
          ..._content(),
        ],
      );
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: SelectableChip(
          label: label,
          selected: selected,
          onTap: onTap,
          activeColor: TaxiColors.accentDark,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        ),
      );

  List<Widget> _content() {
    if (_ctrl.isLoading.value) {
      return [
        for (var i = 0; i < 3; i++) ...[
          TripShimmers.rowBox(height: 68, radius: 14),
          const SizedBox(height: 8),
        ],
      ];
    }
    if (_ctrl.loadFailed.value) {
      final offline = _ctrl.isOffline.value;
      return [
        EmptyStateView(
          icon: offline ? Iconsax.wifi_square : Iconsax.info_circle,
          title: offline ? TaxiWaysStrings.offlineTitle : TaxiWaysStrings.loadFailed,
          subtitle: offline ? TaxiWaysStrings.offlineBody : '',
          palette: TaxiColors.palette,
          retryLabel: TaxiWaysStrings.retry,
          onRetry: _ctrl.retry,
        ),
      ];
    }
    if (_ctrl.items.isEmpty) {
      return [
        EmptyStateView(
          icon: Iconsax.car,
          title: TaxiWaysStrings.noDriversMatch,
          subtitle: TaxiWaysStrings.noDriversMatchBody,
          palette: TaxiColors.palette,
        ),
      ];
    }
    final shown = _ctrl.items.length;
    final bestFit = _ctrl.sort.value == ChangeDriverSort.bestFit;
    return [
      Text(
        bestFit
            ? TaxiWaysStrings.bestFitFirst(widget.people, shown, _ctrl.total.value)
            : TaxiWaysStrings.showingCount(shown, _ctrl.total.value),
        style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
      ),
      const SizedBox(height: 8),
      for (final d in _ctrl.items) ...[
        _DriverRow(
          driver: d,
          isCurrent: widget.current?.taxiId == d.taxiId,
          isLowest: _ctrl.isLowest(d),
          onTap: () => _pick(d),
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
            child: CircularProgressIndicator(strokeWidth: 2.4, color: TaxiColors.accent),
          ),
        ),
      );
    }
    final failed = _ctrl.moreFailed.value;
    return TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: TaxiColors.accentDark),
      onPressed: _ctrl.loadMore,
      child: Text(
        failed ? TaxiWaysStrings.retry : TaxiWaysStrings.showMore(_ctrl.remaining),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final WayDriver driver;
  final bool isCurrent;
  final bool isLowest;
  final VoidCallback onTap;

  const _DriverRow({required this.driver, required this.isCurrent, required this.isLowest, required this.onTap});

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
    final fare = driver.listedFare > 0 ? driver.listedFare : null;
    final subtitle = _subtitle();
    return Semantics(
      button: true,
      child: Material(
        color: isCurrent ? TaxiColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isCurrent ? TaxiColors.accent : AppColors.divider, width: 1.4),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: TaxiColors.accentLight, shape: BoxShape.circle),
                  child: const Icon(Iconsax.car, size: 18, color: TaxiColors.accentDark),
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
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          if (isCurrent)
                            _tag(TaxiWaysStrings.current, TaxiColors.accentLight, TaxiColors.accentDark),
                          if (isLowest) _tag(TaxiWaysStrings.lowestTag, TripStatusColors.bothSurface, TripStatusColors.both),
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textLight, height: 1.3),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warningText),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}
