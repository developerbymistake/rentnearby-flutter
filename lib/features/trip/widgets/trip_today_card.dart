import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_steps_a3.dart';
import '../utils/trip_format.dart';
import 'trip_problem_sheet.dart';

class TripTodayCard extends StatelessWidget {
  const TripTodayCard({super.key});

  static String? _validPhone(String? raw) =>
      raw != null && ContactLauncher.tenDigits(raw).isNotEmpty ? raw : null;

  static String? stayPhone(TripEnquiryModel e) => _validPhone(e.owner.phone) ?? _validPhone(e.phoneBooking?.hostPhone);

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.plan.value;
      c.enquiryList.length;
      c.trip.value;
      final today = c.todayDay;
      final journey = c.journeyToday;
      if ((today == null && journey == null) || c.isCompleted) return const SizedBox.shrink();
      final n = today ?? _nearestDay(c);
      final offline = c.offline.value;
      final rows = <Widget>[
        if (journey != null) ..._travelRows(journey),
        if (today != null) ..._stayRow(c, n),
        if (today != null) ..._taxiRow(c, n),
        if (today != null) ..._routeRow(c, n, offline),
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: TripColors.accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            today == null ? TripStringsStepsA3.travelDay(_todayDate) : TripStrings.todayDay(n, c.dayCount),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                          ),
                          if (offline) ...[
                            const SizedBox(height: 8),
                            _offlineBanner(),
                          ],
                          for (final r in rows) ...[
                            const SizedBox(height: 8),
                            r,
                          ],
                          const SizedBox(height: 12),
                          _problemButton(context, n),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _offlineBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Iconsax.cloud_cross, size: 15, color: AppColors.textMedium),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                TripStrings.offlineSaved,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      );

  static int _nearestDay(TripPlanController c) {
    final first = c.dateOf(1);
    return first != null && _todayDate.isBefore(first) ? 1 : c.dayCount;
  }

  static List<Widget> _travelRows(TripJourney j) {
    final legs = j.legs;
    if (legs.isEmpty) return const [];
    final multi = legs.length > 1;
    final leg = multi ? legs[1] : legs.first;
    final phone = _validPhone(leg.phone);
    final wa = _validPhone(leg.whatsApp);
    final head = j.role == TripStepRole.comingBack ? TripStringsStepsA3.todayComingBack : TripStringsStepsA3.todayGettingThere;
    final paused = legs.where((l) => !l.driverAvailable).firstOrNull;
    return [
      Text(
        head,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight),
      ),
      _Row(
        icon: Iconsax.routing_2,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: multi ? TripStringsStepsA3.changeCarAt(leg.changePlace) : TripStringsStepsA3.takesYou(leg.driverName, j.toName),
        subtitle: multi
            ? TripStringsStepsA3.nextDriver(leg.driverName)
            : [leg.vehicleTypeName, leg.plateDisplay].where((e) => e != null && e.isNotEmpty).join(' · '),
        actionLabel: phone == null ? null : TripStringsStepsA3.call,
        onAction: () => ContactLauncher.call(phone!),
        secondLabel: wa == null ? null : TripStringsStepsA3.whatsApp,
        onSecond: () => ContactLauncher.whatsApp(wa!),
      ),
      if (paused != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Iconsax.warning_2, size: 15, color: AppColors.warningText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TripStringsStepsA3.pausedBackup(paused.driverName, paused.backupName),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
              ),
            ),
          ]),
        ),
    ];
  }

  static DateTime get _todayDate {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  static String _checkOutLine(DateTime checkOut) {
    final t = _todayDate;
    final tomorrow = DateTime(t.year, t.month, t.day + 1);
    return checkOut == tomorrow ? TripStringsA5.checkOutTomorrow : TripStringsA5.checkOutOn(TripFormat.shortDate(checkOut));
  }

  static ({int k, int total, DateTime checkOut}) _nightOf(TripEnquiryModel e) {
    final today = _todayDate;
    final inDate = e.checkIn == null ? null : DateTime(e.checkIn!.year, e.checkIn!.month, e.checkIn!.day);
    final total = inDate == null ? 1 : e.nights.clamp(1, 1 << 20);
    final k = inDate == null ? 1 : (today.difference(inDate).inDays + 1).clamp(1, total);
    final out = e.checkOut == null
        ? DateTime(today.year, today.month, today.day + total - k + 1)
        : DateTime(e.checkOut!.year, e.checkOut!.month, e.checkOut!.day);
    return (k: k, total: total, checkOut: out);
  }

  static ({int k, int total, int last}) _ownNight(TripPlanController c, int day) {
    final days = c.plan.value?.days ?? const <TripDay>[];
    final base = days.firstWhereOrNull((d) => d.day == day)?.stay?.sameAsDay ?? day;
    final chain = days.where((d) => d.day == base || d.stay?.sameAsDay == base).map((d) => d.day).toList()..sort();
    return (k: chain.indexOf(day) + 1, total: chain.length, last: chain.last);
  }

  List<Widget> _stayRow(TripPlanController c, int n) {
    final e = c.todayStay(n);
    if (e != null) {
      final room = e.phoneBooking?.roomName.isNotEmpty == true
          ? e.phoneBooking!.roomName
          : (e.acceptedOffer?.lines.firstOrNull?.roomName ?? '');
      final night = _nightOf(e);
      final sub = [
        if (room.isNotEmpty) room,
        TripStringsA5.nightOf(night.k, night.total, e.agreedTotal == null ? null : BrowseItem.inr(e.agreedTotal!)),
        e.isConfirmedByBoth ? TripStrings.bothConfirmedShort : TripStrings.confirmedByYou,
      ].join(' · ');
      return [
        _Row(
          icon: Iconsax.building_4,
          accent: StayColors.accent,
          surface: StayColors.surface,
          title: e.listingName.isEmpty ? TripStrings.stay : e.listingName,
          subtitle: '$sub\n${_checkOutLine(night.checkOut)}',
          actionLabel: stayPhone(e) == null ? null : TripStrings.call,
          onAction: () => ContactLauncher.call(stayPhone(e)!),
        ),
      ];
    }
    final own = c.ownStayOf(n);
    if (own == null) return const [];
    final phone = _validPhone(own.ownPhone);
    final chain = _ownNight(c, n);
    final lastDate = c.dateOf(chain.last);
    final ownSub = TripStringsA5.nightOf(chain.k, chain.total, null);
    final checkOut = lastDate == null
        ? null
        : _checkOutLine(DateTime(lastDate.year, lastDate.month, lastDate.day + 1));
    return [
      _Row(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: own.name,
        subtitle: [TripStrings.ownBookingShort, ownSub].join(' · ') + (checkOut == null ? '' : '\n$checkOut'),
        actionLabel: phone == null ? null : TripStrings.call,
        onAction: () => ContactLauncher.call(phone!),
      ),
    ];
  }

  List<Widget> _taxiRow(TripPlanController c, int n) {
    final e = c.todayTaxi(n);
    if (e != null) {
      final pickup = e.taxi?.pickupTime;
      final sub = [
        if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
        e.isConfirmedByBoth ? TripStrings.bothConfirmedShort : TripStrings.bookedByYouShort,
      ].join(' · ');
      final phone = _validPhone(e.owner.phone);
      return [
        _Row(
          icon: Iconsax.car,
          accent: TaxiColors.accent,
          surface: TaxiColors.surface,
          title: e.listingName.isEmpty ? TripStrings.driver : e.listingName,
          subtitle: sub,
          actionLabel: phone == null ? null : TripStrings.call,
          onAction: () => ContactLauncher.call(phone!),
        ),
      ];
    }
    final own = c.ownTaxiOf(n);
    if (own == null) return const [];
    final phone = _validPhone(own.ownPhone);
    final pickup = own.booking?.pickupTime;
    final sub = [
      if (pickup != null && pickup.isNotEmpty) TripStrings.pickupAt(TripFormat.time12(pickup)),
      TripStrings.ownBookingShort,
    ].join(' · ');
    return [
      _Row(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: own.name,
        subtitle: sub,
        actionLabel: phone == null ? null : TripStrings.call,
        onAction: () => ContactLauncher.call(phone!),
      ),
    ];
  }

  List<Widget> _routeRow(TripPlanController c, int n, bool offline) {
    final names = c.todaySpotNames(n);
    if (names.isEmpty) return const [];
    return [
      _Row(
        icon: Iconsax.location,
        accent: TripColors.accent,
        surface: TripColors.surface,
        title: offline ? TripStrings.lastSavedRoute : TripStrings.todaysRoute,
        subtitle: names.join(' · '),
        actionLabel: TripStrings.map,
        onAction: () => TripNavigation.openMap(day: n),
      ),
    ];
  }

  Widget _problemButton(BuildContext context, int n) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton(
          onPressed: () => TripProblemSheet.show(context, day: n),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: AppColors.errorSurface,
            side: const BorderSide(color: AppColors.error, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.warning_2, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  TripStrings.problemOnTrip,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondLabel,
    this.onSecond,
  });

  final IconData icon;
  final Color accent;
  final Color surface;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondLabel;
  final VoidCallback? onSecond;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(
              actionLabel!,
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
          ),
        if (secondLabel != null && onSecond != null)
          TextButton(
            onPressed: onSecond,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(
              secondLabel!,
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TripColors.accentDark),
            ),
          ),
      ],
    );
  }
}
