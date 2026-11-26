import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../owner_core/home/numbers_row.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../availability/taxi_availability_store.dart';
import '../calendar/taxi_calendar_widgets.dart';
import '../strings/taxi_availability_strings.dart';
import '../widgets/taxi_widgets.dart';

class TaxiAvailabilityCard extends StatefulWidget {
  const TaxiAvailabilityCard({super.key, this.info, this.today});

  final OwnerHomeAvailability? info;
  final DateTime? today;

  static void open() => Get.toNamed(AppRoutes.taxiAvailability);

  @override
  State<TaxiAvailabilityCard> createState() => _TaxiAvailabilityCardState();
}

class _TaxiAvailabilityCardState extends State<TaxiAvailabilityCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaxiAvailabilityStore.maybe?.prefetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final month = info?.month ?? widget.today ?? OwnerDates.only(DateTime.now());
    final monthText = OwnerSharedStrings.monthTitle(month);
    final bookings = NumberTile.of(info?.bookings);
    final daysOff = NumberTile.of(info?.daysOff);
    final radius = DS.br(CardRadius.tile);
    return Padding(
      padding: DS.insets(l: 18, t: 8, r: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius, boxShadow: DS.shadows(Ink3D.softShadow)),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              label: TaxiAvailabilityStrings.cardSemantics(monthText, bookings, daysOff),
              excludeSemantics: true,
              child: InkWell(
                onTap: TaxiAvailabilityCard.open,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TaxiRowTile(
                      data: TaxiRowData(
                        art: ListingArt.calendar,
                        title: TaxiAvailabilityStrings.title,
                        sub: monthText,
                        trailing: const TaxiPill(label: TaxiAvailabilityStrings.manage, kind: TaxiPillKind.outline, onTap: TaxiAvailabilityCard.open),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: TaxiLook.rowLine),
                    OwnerFacts(facts: [
                      NumberTile(value: bookings, label: TaxiAvailabilityStrings.bookings, dot: TaxiCal.appDot),
                      NumberTile(value: daysOff, label: TaxiAvailabilityStrings.daysOff, dot: TaxiCal.ownDot),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
