import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../owner_core/calendar/day_list.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import 'taxi_trip_sheet.dart';
import 'taxi_trip_text.dart';

abstract final class TaxiDaySheet {
  static Future<void> show(BuildContext context, {required TaxiCalendarController controller, required DateTime day}) async {
    final d = OwnerDates.only(day);
    final rows = controller.dayRows(d);
    final festival = controller.festivalOn(d);
    final canAdd = controller.canAddOn(d) && !TaxiDriverDeps.isDayOff(d);
    final action = await OwnerSheet.show<_DayAction>(
      context,
      look: TaxiCal.look,
      title: TaxiCalendarStrings.daySheetTitle(d),
      subtitle: rows.isEmpty ? TaxiCalendarStrings.nothingOnDay : TaxiCalendarStrings.tripsOnDay(rows.length),
      child: (c) => TaxiDayBody(rows: rows, festival: festival, onOpen: (e) => e.inactiveByPlan ? AppToast.info(OwnerSharedStrings.inactiveToast) : Navigator.of(c).pop(_DayAction.open(e.id))),
      footer: canAdd
          ? (c) => PrimaryButton(label: TaxiCalendarStrings.addTripOnDay, tone: TaxiCal.kit, onPressed: () => Navigator.of(c).pop(const _DayAction.add()))
          : null,
    );
    if (action == null || !context.mounted) return;
    final id = action.entryId;
    if (id != null) {
      TaxiDriverDeps.openEntry(id);
    } else {
      await TaxiTripSheet.show(context, controller: controller, date: d);
    }
  }
}

class _DayAction {
  const _DayAction.add() : entryId = null;
  const _DayAction.open(String this.entryId);

  final String? entryId;
}

class TaxiDayBody extends StatelessWidget {
  const TaxiDayBody({super.key, required this.rows, this.festival, required this.onOpen});

  final List<CalendarEntry> rows;
  final FestivalRow? festival;
  final ValueChanged<CalendarEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final f = festival;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f != null)
            Container(
              margin: EdgeInsets.only(bottom: DS.gv(8)),
              padding: DS.sym(h: 12, v: 8),
              decoration: BoxDecoration(color: TaxiCal.amberFill, borderRadius: DS.circular(12)),
              child: Row(
                children: [
                  Art3D(asset: ListingArt.diyaLamp, size: 20),
                  Gap.h(8),
                  Expanded(child: Text(f.name, style: Ink3D.text(12, FontWeight.w700, TaxiCal.amber, letterSpacing: 0))),
                ],
              ),
            ),
          DayList(
            entries: rows,
            shrinkWrap: true,
            row: (context, e) => TaxiDayRow(entry: e, onOpen: () => onOpen(e)),
          ),
        ],
      ),
    );
  }
}

class TaxiDayRow extends StatelessWidget {
  const TaxiDayRow({super.key, required this.entry, required this.onOpen});

  final CalendarEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = TaxiTripText.title(entry);
    return Container(
      decoration: BoxDecoration(
        color: entry.cancelled ? TaxiCal.greyFill : DesignColors.surface,
        borderRadius: DS.circular(14),
        border: Border.all(color: Ink3D.line, width: DS.s(1)),
      ),
      child: TaxiTripRow(
        entry: entry,
        tile: TaxiTripText.timeTile(entry),
        line: TaxiTripText.dayLine(entry),
        badgeTop: true,
        padding: DS.sym(h: 12, v: 12),
        trailing: TaxiSmallOutline(label: OwnerSharedStrings.open, onTap: onOpen, semantics: '${OwnerSharedStrings.open} $title'),
        chipBelow: true,
        onTap: onOpen,
      ),
    );
  }
}
