import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../owner_core/calendar/month_grid_data.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../calendar/taxi_month_grid.dart';
import '../strings/taxi_availability_strings.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_availability_controller.dart';
import 'taxi_availability_grid.dart';
import 'taxi_availability_models.dart';
import 'taxi_days_off_list.dart';
import 'taxi_reason_sheet.dart';

class TaxiAvailabilityScreen extends StatefulWidget {
  const TaxiAvailabilityScreen({super.key, this.controller});

  final TaxiAvailabilityController? controller;

  @override
  State<TaxiAvailabilityScreen> createState() => _TaxiAvailabilityScreenState();
}

class _TaxiAvailabilityScreenState extends State<TaxiAvailabilityScreen> {
  late final TaxiAvailabilityController _c;
  late final AppLifecycleListener _life;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    if (given != null) {
      _c = given;
    } else {
      if (Get.isRegistered<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag)) {
        Get.delete<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag, force: true);
      }
      _c = Get.put(TaxiAvailabilityController(), tag: TaxiAvailabilityController.tag);
      _owned = true;
    }
    _life = AppLifecycleListener(onResume: _c.checkDay);
  }

  @override
  void dispose() {
    _life.dispose();
    if (_owned && Get.isRegistered<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag)) {
      Get.delete<TaxiAvailabilityController>(tag: TaxiAvailabilityController.tag, force: true);
    }
    super.dispose();
  }

  Future<void> _openSheet(DateTime day, {required bool off}) async {
    if (_c.saving.value) return;
    final action = await TaxiReasonSheet.show(context, day: day, off: off, reason: off ? _c.reasonOf(day) : null);
    if (action != null && mounted) _c.apply(day, action);
  }

  void _tap(DayCell cell) {
    if (_c.saving.value) return;
    if (cell.date.isBefore(_c.today)) {
      _c.checkDay();
      return;
    }
    switch (_c.stateOf(cell)) {
      case TaxiAvailDay.past:
        return;
      case TaxiAvailDay.booked:
        _c.bookedTap();
      case TaxiAvailDay.off:
        _openSheet(cell.date, off: true);
      case TaxiAvailDay.free:
        _openSheet(cell.date, off: false);
    }
  }

  Future<void> _save() async {
    final ok = await _c.save();
    // pop(), not maybePop(): PopScope still holds canPop=false until the next frame.
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = _c.saving.value;
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          backgroundColor: TaxiCal.page,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: PageHeader3D(
                  tone: ListingTone.coral,
                  title: TaxiAvailabilityStrings.title,
                  subtitle: TaxiAvailabilityStrings.pageSub,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(child: _body()),
              if (_c.store.value.value != null)
                TaxiBottomActions(children: [
                  Obx(() => PrimaryButton(
                        label: TaxiAvailabilityStrings.save,
                        tone: TaxiCal.kit,
                        loading: _c.saving.value,
                        onPressed: _c.dirty.value && !_c.saving.value ? _save : null,
                      )),
                ]),
            ],
          ),
        ),
      );
    });
  }

  Widget _body() {
    final load = _c.store.load.value;
    final data = _c.store.value.value;
    final parts = <WidgetBuilder>[];
    if (data == null) {
      if (load is OwnerLoadLoading<TaxiAvailability>) {
        parts.add((_) => const OwnerSkeletonList(rows: 4));
      } else {
        parts.add((_) => Padding(
              padding: DS.insets(t: 24),
              child: StateCard.error(
                title: OwnerSharedStrings.couldNotLoad,
                kit: TaxiCal.kit,
                actionLabel: OwnerSharedStrings.tryAgain,
                onAction: () => _c.store.refresh(force: true),
              ),
            ));
      }
    } else {
      if (load is OwnerLoadData<TaxiAvailability> && load.stale) parts.add((_) => const OwnerStaleLine());
      if (_c.showOfflineNote) parts.add((_) => const TaxiOfflineNote());
      parts
        ..add((_) => Obx(() => TaxiMonthPager(month: _c.month.value, window: _c.window, today: _c.today, onMonth: _c.setMonth)))
        ..add((_) => Obx(() {
              final cells = _c.cells.toList();
              return TaxiMonthGrid(
                cells: cells,
                cellBuilder: (cell) => TaxiAvailDayBox(cell: cell, state: _c.stateOf(cell), onTap: _tap),
              );
            }))
        ..add((_) => Padding(padding: DS.insets(t: 12, b: 4), child: const TaxiAvailLegend()))
        ..add((_) => Obx(() => TaxiDaysOffList(rows: _c.list.toList(), onTap: (d) => _openSheet(d.date, off: true))));
    }
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(4), DS.s(16), DS.s(24)),
        itemCount: parts.length,
        itemBuilder: (context, i) => parts[i](context),
      ),
    );
  }
}

class TaxiOfflineNote extends StatelessWidget {
  const TaxiOfflineNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(t: 4, b: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(color: TaxiLook.rowLine, borderRadius: DS.circular(14)),
          child: Padding(
            padding: DS.sym(h: 14, v: 10),
            child: Text(TaxiAvailabilityStrings.offlineNote, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.grey, height: 1.35, letterSpacing: 0)),
          ),
        ),
      );
}
