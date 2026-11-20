import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../models/viewer_models.dart';
import '../viewer_look.dart';
import '../viewer_rules.dart';
import '../viewer_strings.dart';

abstract final class ViewerBookingSheet {
  static Future<void> taxi(BuildContext context, ViewerTaxi taxi) => BuddySheet.show<void>(
        context,
        art: ListingArt.taxi,
        title: ViewerStrings.taxi,
        builder: (_) => _Rows(key: const ValueKey('viewer_taxi_sheet'), rows: [
          if ((taxi.vehicleType ?? '').isNotEmpty) (ViewerStrings.vehicle, taxi.vehicleType!),
          if ((taxi.driverFirstName ?? '').isNotEmpty) (ViewerStrings.driver, taxi.driverFirstName!),
          if (ViewerRules.taxiWhen(taxi).isNotEmpty) (ViewerStrings.pickup, ViewerRules.taxiWhen(taxi)),
        ]),
      );

  static Future<void> stays(BuildContext context, ViewerStay stay) => BuddySheet.show<void>(
        context,
        art: ListingArt.camping,
        title: ViewerStrings.stay,
        builder: (_) => Column(
          key: const ValueKey('viewer_stay_sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in stay.items)
              Padding(
                padding: EdgeInsets.only(bottom: DS.s(12)),
                child: _Rows(title: '${s.cityName} · ${s.stayName}', rows: [
                  (ViewerStrings.nightsLabel, ViewerStrings.nights(s.nights)),
                  if (s.checkIn != null) (ViewerStrings.checkIn, BuddyFormat.weekdayDate(s.checkIn!)),
                  if (s.checkOut != null) (ViewerStrings.checkOut, BuddyFormat.weekdayDate(s.checkOut!)),
                ]),
              ),
          ],
        ),
      );
}

class _Rows extends StatelessWidget {
  const _Rows({super.key, this.title, required this.rows});

  final String? title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, style: Ink3D.text(15, FontWeight.w700, ViewerLook.ink, letterSpacing: 0)),
          for (final r in rows)
            Container(
              padding: DS.sym(v: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ViewerLook.line))),
              child: Row(
                children: [
                  Text(r.$1, style: Ink3D.text(13, FontWeight.w400, ViewerLook.greyKey, letterSpacing: 0)),
                  Gap.h(14),
                  Expanded(child: Text(r.$2, textAlign: TextAlign.right, style: Ink3D.text(13, FontWeight.w700, ViewerLook.ink, letterSpacing: 0))),
                ],
              ),
            ),
        ],
      );
}
