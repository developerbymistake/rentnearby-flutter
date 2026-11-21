import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/stay_gate_strings_work.dart';
import '../strings/stay_reminder_strings.dart';

/// Last known reminder state; the calendar screen sets it from its month read (C1).
abstract final class StayReminderState {
  static final value = Rxn<CalendarReminder>();
  static CalendarApi api = const CalendarApi('/stays/me/calendar');

  static void reset() {
    value.value = null;
    api = const CalendarApi('/stays/me/calendar');
  }
}

class StayReminderRow extends StatefulWidget {
  const StayReminderRow({super.key});

  @override
  State<StayReminderRow> createState() => _StayReminderRowState();
}

class _StayReminderRowState extends State<StayReminderRow> {
  bool _busy = false;

  bool get _allowed {
    final known = StayReminderState.value.value;
    if (known != null) return known.allowed || !PlanGate.paymentOn;
    return !PlanGate.paymentOn || PlanGate.on(PlanKey.reminders);
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    final before = StayReminderState.value.value ?? CalendarReminder(allowed: _allowed, on: !on);
    setState(() => _busy = true);
    StayReminderState.value.value = CalendarReminder(allowed: before.allowed, on: on);
    try {
      final r = await StayReminderState.api.reminder(on);
      if (!mounted) return;
      switch (r) {
        case OwnerOk(:final value):
          StayReminderState.value.value = value;
        case OwnerRefused(:final message):
          StayReminderState.value.value = before;
          AppToast.error(message == null || message.isEmpty ? OwnerSharedStrings.noConnection : message);
        case OwnerOffline():
          StayReminderState.value.value = before;
          AppToast.error(OwnerSharedStrings.noConnection);
        case OwnerFailed():
          StayReminderState.value.value = before;
          AppToast.error(OwnerSharedStrings.noConnection);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = StayReminderState.value.value;
      final allowed = _allowed;
      if (PlanGate.canUpgrade && !allowed) {
        return Padding(
          padding: DS.gapInsets(l: 14, t: 10, r: 14),
          child: SoftLock.row(text: StayReminderStrings.title, sub: StayGateStringsWork.reminderLocked),
        );
      }
      final on = state?.on ?? false;
      return Container(
        margin: DS.gapInsets(l: 14, t: 10, r: 14),
        padding: DS.insets(l: 14, t: 12, r: 10, b: 10),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(14), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.alarmClock, size: 30)),
              Gap.h(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(StayReminderStrings.title, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(StayReminderStrings.sub, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                ]),
              ),
              Semantics(
                toggled: on,
                label: StayReminderStrings.title,
                child: Switch(value: on, activeTrackColor: OwnerLook.stay.accent, onChanged: _busy ? null : _toggle),
              ),
            ]),
            Padding(
              padding: EdgeInsets.only(top: DS.gv(6)),
              child: Row(children: [
                Icon(Icons.notifications_none_rounded, size: DS.s(15), color: Ink3D.grey),
                Gap.h(6),
                Expanded(child: Text(StayReminderStrings.needsNotifications, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0))),
              ]),
            ),
          ],
        ),
      );
    });
  }
}
