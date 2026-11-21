import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';

class TaxiReminderRow extends StatelessWidget {
  const TaxiReminderRow({super.key, required this.controller});

  final TaxiCalendarController controller;

  Future<void> _set(bool on) async {
    final r = await controller.setReminder(on);
    if (r == null || r is OwnerOk<CalendarReminder>) return;
    if (r is OwnerRefused<CalendarReminder> && OwnerRefusal.lockedKey(r) != null) {
      await controller.reload();
      return;
    }
    if (r is OwnerRefused<CalendarReminder> && r.statusCode == 429) {
      AppToast.error(OwnerSharedStrings.tooManyTries);
      return;
    }
    AppToast.error(OwnerSharedStrings.noConnection);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.load.value;
      final locked = controller.reminderLocked;
      final on = controller.reminderOn.value ?? false;
      final allowed = controller.current?.reminder.allowed ?? true;
      return Container(
        key: locked ? GateKeys.softRow : null,
        padding: DS.sym(h: 14, v: 12),
        decoration: TaxiCal.card(),
        child: Row(
          children: [
            Art3D(asset: ListingArt.alarmClock, size: 44),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TaxiCalendarStrings.morningReminder, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                  Text(locked ? TaxiCalendarStrings.reminderLocked : TaxiCalendarStrings.reminderOn,
                      style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ),
            if (locked)
              const SeePlusButton(taxi: true)
            else
              Semantics(
                label: TaxiCalendarStrings.morningReminder,
                toggled: on,
                child: Switch(
                  value: on,
                  activeTrackColor: TaxiCal.accent,
                  onChanged: allowed && !controller.reminderBusy.value ? _set : null,
                ),
              ),
          ],
        ),
      );
    });
  }
}
