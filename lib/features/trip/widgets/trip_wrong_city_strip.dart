import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/travel_icon.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings_mcc_a2.dart';
import '../utils/trip_enquiry_rules.dart';

class TripWrongCityStrip extends StatelessWidget {
  const TripWrongCityStrip({
    super.key,
    required this.enquiry,
    required this.info,
    this.onCancel,
    this.onChangeDays,
    this.dense = false,
  });

  final TripEnquiryModel enquiry;
  final WrongCityInfo info;
  final VoidCallback? onCancel;
  final VoidCallback? onChangeDays;
  final bool dense;

  static String lineOf(TripEnquiryModel e, WrongCityInfo info) {
    final taxi = e.isTaxi;
    if (info.total > 1) {
      return taxi
          ? TripStringsMccA2.daysInCity(info.wrong, info.total, info.dayCity)
          : TripStringsMccA2.nightsInCity(info.wrong, info.total, info.dayCity);
    }
    return taxi
        ? TripStringsMccA2.dayInCity(info.firstWrongDay, info.dayCity)
        : TripStringsMccA2.nightInCity(info.firstWrongDay, info.dayCity);
  }

  static const BorderRadius _denseRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  Widget _action(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w700, color: TripLook.error),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final taxi = enquiry.isTaxi;
    final name = enquiry.listingName;
    final line = lineOf(enquiry, info);
    final actions = [
      if (onCancel != null) _action(TripStringsMccA2.cancel, onCancel!),
      if (onChangeDays != null) _action(TripStringsMccA2.changeDays, onChangeDays!),
    ];
    return Container(
      margin: EdgeInsets.only(top: dense ? 6 : 8),
      decoration: TripLook.card(color: TripLook.errorSurface, radius: dense ? _denseRadius : TripLook.softRadius),
      child: ClipRRect(
        borderRadius: dense ? _denseRadius : TripLook.softRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: TripLook.error),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, dense ? 6 : 8, 6, actions.isEmpty ? (dense ? 6 : 8) : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          TravelIcon(taxi ? TravelIcon.taxi : TravelIcon.stay, size: 16),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              TripStringsMccA2.wrongCityNow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TripLook.errorText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.isEmpty || dense ? line : '$name · $line',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: TripLook.errorText),
                      ),
                      if (actions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(alignment: WrapAlignment.end, children: actions),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
