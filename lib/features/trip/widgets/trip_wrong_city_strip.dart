import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
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

  @override
  Widget build(BuildContext context) {
    final name = enquiry.listingName;
    final line = lineOf(enquiry, info);
    Widget action(String label, VoidCallback onTap) => Tap3D(
          onTap: onTap,
          label: label,
          exclude: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, RepliesLook.badInk, letterSpacing: 0))),
            ),
          ),
        );
    return Container(
      margin: EdgeInsets.only(top: dense ? 6 : 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
      decoration: BoxDecoration(color: RepliesLook.badSurface, borderRadius: BorderRadius.circular(dense ? 18 : 22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset(enquiry.isTaxi ? ListingArt.taxi : ListingArt.hotel, width: 22, height: 22, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Expanded(child: Text(TripStringsMccA2.wrongCityNow, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, RepliesLook.badInk, letterSpacing: 0))),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(name.isEmpty || dense ? line : '$name · $line', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, RepliesLook.badInk, letterSpacing: 0)),
          ),
          if (onCancel != null || onChangeDays != null)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(children: [
                if (onCancel != null) action(TripStringsMccA2.cancel, onCancel!),
                if (onChangeDays != null) action(TripStringsMccA2.changeDays, onChangeDays!),
              ]),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
