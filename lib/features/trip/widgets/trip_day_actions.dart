import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../taxi/taxi_option_sets.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_steps_a1.dart';
import 'trip_cancel_sheet.dart';
import 'trip_own_booking_sheet.dart';
import 'trip_status.dart';
import 'trip_withdraw_sheet.dart';

enum TripTileState { active, pending, disabled }

enum TripTileStatus { none, selected, booked, asked, offered, confirmedByYou, confirmedByBoth, red, own }

class TripDayActions extends StatelessWidget {
  final int day;

  const TripDayActions(this.day, {super.key});

  static String _price(int? v) => v == null ? 'On request' : BrowseItem.inr(v);

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      TabConfigController.to.version.value;
      c.taxiSupply.value;
      c.taxiSupplyByLeg.length;
      c.taxiTabOff.value;
      c.stayTabOff.value;
      c.trip.value;
      c.enquiryList.length;
      final d = c.plan.value?.dayAt(day);
      if (d == null) return const SizedBox.shrink();
      final readOnly = c.isReadOnly || c.needsUpdate.value || c.isDayPast(day);
      _ensureLegSupply(c, readOnly);
      return Row(
        children: [
          Expanded(child: _taxiSlot(context, c, d, readOnly)),
          const SizedBox(width: 8),
          Expanded(child: _stayTile(context, c, d, readOnly)),
        ],
      );
    });
  }

  void _ensureLegSupply(TripPlanController c, bool readOnly) {
    if (readOnly || !c.supplyAvailableFor(day) || c.taxiSupplyFor(day) != null) return;
    final leg = c.plan.value?.legIndexOf(day) ?? 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => c.ensureSupply(leg));
  }

  String _taxiTitle(TripPlanController c) =>
      c.isMultiCity ? TripStringsMcaA3.taxiIn(c.cityNameOf(day)) : TripStringsA4.taxi;

  String _stayTitle(TripPlanController c) =>
      c.isMultiCity ? TripStringsMcaA3.stayTonightIn(c.cityNameOf(day)) : TripStrings.stay;

  Widget _emptyTile({
    required IconData icon,
    required Color accent,
    required Color surface,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    TripTileState state = TripTileState.active,
  }) =>
      _ActionTile(
        icon: icon,
        accent: accent,
        surface: surface,
        title: title,
        subtitle: subtitle,
        selected: false,
        state: state,
        status: TripTileStatus.none,
        onTap: onTap,
      );

  Widget _taxiSlot(BuildContext context, TripPlanController c, TripDay d, bool readOnly) {
    final enquiryTile = _taxiTile(context, c, readOnly);
    if (enquiryTile != null) return enquiryTile;
    final taxi = d.taxi;
    if (taxi != null && taxi.isSkipped) {
      return _ActionTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: TripStringsStepsA1.noTaxiThisDay,
        subtitle: TripStringsStepsA1.stepLabel(TripStepDisplay.skipped),
        selected: false,
        status: TripTileStatus.none,
        onTap: readOnly ? null : () => TripNavigation.openTaxi(day),
        onLongPress: readOnly
            ? null
            : () => _confirmClear(
                context, TripStrings.removeFromPlan, TripStringsStepsA1.noTaxiThisDay, () => c.clearSkippedTaxiDay(day)),
      );
    }
    if (taxi != null && taxi.isOwn) {
      final fare = taxi.fare;
      return _ActionTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: taxi.name.isEmpty ? TripStrings.ownTaxiTitle : taxi.name,
        subtitle: fare == null ? TripStringsA4.ownBooking : '${TripStringsA4.ownBooking} · ${TripStringsA4.perDay(BrowseItem.inr(fare))}',
        selected: true,
        status: TripTileStatus.own,
        display: TripDisplayStatus.own,
        onTap: readOnly ? null : () => TripOwnBookingSheet.show(context, day: day, kind: TripOwnKind.taxi, existingTaxi: taxi),
        onLongPress: readOnly
            ? null
            : () => _confirmClear(context, TripStrings.removeFromPlan, taxi.name, () => c.clearOwnTaxi(day)),
      );
    }
    if (taxi != null) {
      final booking = taxi.booking;
      final rate = taxi.fare == null ? TripStringsA4.rateOnRequest : TripStringsA4.perDay(BrowseItem.inr(taxi.fare!));
      return _ActionTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: taxi.name,
        subtitle: booking != null
            ? '${TripStrings.bookedByYou} · ${BrowseItem.inr(booking.agreedFare)}'
                '${booking.days.length > 1 ? ' · ${booking.days.length} days' : ''}'
            : (taxi.vehicleTypeName == null ? rate : '$rate · ${taxi.vehicleTypeName}'),
        selected: true,
        status: booking != null ? TripTileStatus.booked : TripTileStatus.selected,
        onTap: readOnly ? null : () => TripNavigation.openTaxi(day),
        onLongPress: readOnly
            ? null
            : booking != null
                ? () => _confirmClear(context, TripStrings.removeBooking, taxi.name, () => c.clearTaxiBooking(taxi.taxiId),
                    note: TripStrings.removeBookingNote)
                : () => _confirmClear(context, TripStringsA4.removeTaxi, taxi.name, () => c.clearTaxi(day)),
      );
    }
    final title = _taxiTitle(c);
    if (c.hidesLocalTaxi(day)) {
      return _emptyTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: title,
        subtitle: TripStringsMcbA2.journeyDriversBring,
        state: TripTileState.disabled,
      );
    }
    if (readOnly) {
      return _emptyTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: title,
        subtitle: TripStringsA4.notBooked,
        state: TripTileState.disabled,
      );
    }
    if (c.supplyPendingFor(day) || (c.supplyAvailableFor(day) && !c.taxiTabOff.value && c.taxiSupplyFor(day) == null)) {
      return _emptyTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: title,
        subtitle: TripStrings.checking,
        state: TripTileState.pending,
      );
    }
    final travel = c.plan.value?.isTravelDay(day) ?? false;
    if (c.canFindTaxiOn(day)) {
      return _emptyTile(
        icon: Iconsax.car,
        accent: TaxiColors.accent,
        surface: TaxiColors.surface,
        title: title,
        subtitle: travel ? '${TripStringsA4.findADriver} · ${TripStringsMcaA3.afterYouArrive}' : TripStringsA4.findADriver,
        onTap: () => TripNavigation.openTaxi(day),
      );
    }
    return _emptyTile(
      icon: Iconsax.car,
      accent: TaxiColors.accent,
      surface: TaxiColors.surface,
      title: title,
      subtitle: travel ? '${TripStrings.addOwnTaxi} · ${TripStringsMcaA3.afterYouArrive}' : TripStrings.addOwnTaxi,
      onTap: () => TripOwnBookingSheet.show(context, day: day, kind: TripOwnKind.taxi),
    );
  }

  Widget? _taxiTile(BuildContext context, TripPlanController c, bool readOnly) {
    final e = c.primaryTaxiEnquiry(day);
    final s = e?.display;
    if (e == null || s == null || s == TripDisplayStatus.closed || s == TripDisplayStatus.none) return null;
    final t = e.taxi;
    final String subtitle;
    final TripTileStatus status;
    switch (s) {
      case TripDisplayStatus.asked:
        subtitle = TripStrings.enquirySentWaiting;
        status = TripTileStatus.asked;
      case TripDisplayStatus.fareSent:
        subtitle = TripStrings.repliedFare(_price(t?.driverFare), _price(t?.listedTotal));
        status = TripTileStatus.offered;
      case TripDisplayStatus.bookedByYou:
        subtitle = '${TripStrings.bookedByYou} · ${_price(t?.agreedFare)}';
        status = TripTileStatus.booked;
      case TripDisplayStatus.confirmedByBoth:
        subtitle = TripStrings.bothFare(_price(t?.agreedFare));
        status = TripTileStatus.confirmedByBoth;
      default:
        subtitle = s == TripDisplayStatus.cancelled && e.cancelledBy == 'owner'
            ? TripStrings.hostCancelled
            : TripStatusVisuals.label(s, taxi: true);
        status = TripTileStatus.red;
    }
    VoidCallback? longPress;
    if (readOnly) {
      longPress = null;
    } else if (e.isWithdrawable) {
      longPress = () => TripWithdrawSheet.show(context, enquiry: e);
    } else if (e.isBooked) {
      longPress = () => TripCancelSheet.show(context, enquiry: e, ownerSide: false);
    } else if (e.isRed) {
      longPress = () => _confirmClear(context, TripStrings.removeFromPlan, e.listingName, () => c.dismissRedTaxi(day));
    }
    return _ActionTile(
      icon: Iconsax.car,
      accent: TaxiColors.accent,
      surface: TaxiColors.surface,
      title: e.listingName.isEmpty ? TripStrings.driver : e.listingName,
      subtitle: subtitle,
      selected: true,
      status: status,
      display: s,
      onTap: () => TripNavigation.openTaxiReplies(day, enquiryId: e.id),
      onLongPress: longPress,
    );
  }

  static String _names(List<TripEnquiryModel> items) {
    final names = items.map((e) => e.listingName).where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? TripStrings.stay : names.join(', ');
  }

  static String _redLabel(TripEnquiryModel e) {
    final s = e.display;
    if (s == TripDisplayStatus.cancelled && e.cancelledBy == 'owner') return TripStrings.hostCancelled;
    return TripStatusVisuals.label(s);
  }

  Widget _stayTile(BuildContext context, TripPlanController c, TripDay d, bool readOnly) {
    final stay = d.stay;
    final primary = c.primaryEnquiry(day);
    final display = primary?.display;
    final usable = display != null && display != TripDisplayStatus.closed && display != TripDisplayStatus.none;
    if (usable) {
      final e = primary!;
      String subtitle;
      TripTileStatus status;
      TripAdvanceModel? advance;
      var title = e.listingName.isEmpty ? TripStrings.stay : e.listingName;
      switch (e.display) {
        case TripDisplayStatus.asked:
          final asked = c.enquiriesForNight(day).where((x) => x.display == TripDisplayStatus.asked).toList();
          title = _names(asked);
          subtitle = TripStrings.askedWaiting(asked.length);
          status = TripTileStatus.asked;
        case TripDisplayStatus.offered:
          final total = e.openOffer?.total;
          subtitle = total == null ? TripStrings.offerReceived : '${TripStrings.offerReceived} · ${BrowseItem.inr(total)}';
          status = TripTileStatus.offered;
        case TripDisplayStatus.confirmedByYou:
          subtitle = '${TripStrings.confirmedByYou} · ${_price(e.agreedTotal)}';
          status = TripTileStatus.confirmedByYou;
        case TripDisplayStatus.confirmedByBoth:
          final label = e.advanceLabel;
          subtitle = label ?? '${TripStrings.both} · ${_price(e.agreedTotal)}';
          if (e.hasPendingRevised) subtitle = '$subtitle · ${TripStrings.notAcceptedYet}';
          if (label != null) advance = e.advance;
          status = TripTileStatus.confirmedByBoth;
        default:
          subtitle = _redLabel(e);
          status = TripTileStatus.red;
      }
      VoidCallback? longPress;
      if (readOnly) {
        longPress = null;
      } else if (e.display.isConfirmed) {
        longPress = () => TripCancelSheet.show(context, enquiry: e, ownerSide: false);
      } else if (e.display.isOpen) {
        longPress = () => _removeShortlist(context, c);
      } else if (e.isRed) {
        longPress = () => _confirmClear(context, TripStrings.removeFromPlan, e.listingName, () => c.dismissRed(day));
      }
      return _ActionTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: title,
        subtitle: subtitle,
        selected: true,
        status: status,
        display: display,
        advance: advance,
        onTap: () => TripNavigation.openReplies(day),
        onLongPress: longPress,
      );
    }
    if (stay != null && stay.isSkipped) {
      return _ActionTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: TripStrings.noStayTonight,
        subtitle: TripStrings.travelling,
        selected: false,
        status: TripTileStatus.none,
        onTap: readOnly ? null : () => TripNavigation.openStay(day),
        onLongPress: readOnly
            ? null
            : () => _confirmClear(context, TripStrings.removeFromPlan, TripStrings.noStayTonight, () => c.clearSkippedNight(day)),
      );
    }
    final own = c.ownStayOf(day);
    if (stay != null && own != null) {
      final same = stay.isSameStay;
      return _ActionTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: own.name,
        subtitle: same ? '${TripStrings.ownBooking} · ${TripStrings.sameAsLastNight}' : TripStrings.ownBooking,
        selected: true,
        status: TripTileStatus.own,
        display: TripDisplayStatus.own,
        onTap: readOnly
            ? null
            : () => TripOwnBookingSheet.show(context, day: same ? stay.sameAsDay! : day, existingStay: own),
        onLongPress: readOnly
            ? null
            : () => _confirmClear(context, TripStrings.removeFromPlan, own.name, () => same ? c.clearStay(day) : c.clearOwnStay(day)),
      );
    }
    final shortlist = d.stayShortlist;
    if (stay != null) {
      final sameStay = stay.isSameStay;
      return _ActionTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: stay.name,
        subtitle: sameStay ? TripStrings.sameAsLastNight : '${_price(stay.pricePerNight)} / night',
        selected: true,
        status: TripTileStatus.selected,
        onTap: readOnly ? null : () => TripNavigation.openStay(day),
        onLongPress: readOnly
            ? null
            : () => _confirmClear(context, TripStrings.removeFromPlan, stay.name, () => c.clearStay(day)),
      );
    }
    if (shortlist.isNotEmpty) {
      return _ActionTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: TripStrings.stay,
        subtitle: TripStrings.shortlistedCount(shortlist.length),
        selected: true,
        status: TripTileStatus.selected,
        display: TripDisplayStatus.shortlisted,
        onTap: readOnly ? null : () => TripNavigation.openStay(day),
        onLongPress: readOnly ? null : () => _removeShortlist(context, c),
      );
    }
    final stayTitle = _stayTitle(c);
    if (readOnly) {
      return _emptyTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: stayTitle,
        subtitle: TripStringsA4.notBooked,
        state: TripTileState.disabled,
      );
    }
    if (c.supplyPendingFor(day)) {
      return _emptyTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: stayTitle,
        subtitle: TripStrings.checking,
        state: TripTileState.pending,
      );
    }
    if (c.canFindStayOn(day)) {
      return _emptyTile(
        icon: Iconsax.building_4,
        accent: StayColors.accent,
        surface: StayColors.surface,
        title: stayTitle,
        subtitle: TripStringsA4.nightFindStay(day),
        onTap: () => TripNavigation.openStay(day),
      );
    }
    return _emptyTile(
      icon: Iconsax.building_4,
      accent: StayColors.accent,
      surface: StayColors.surface,
      title: stayTitle,
      subtitle: TripStrings.addOwnStay,
      onTap: () => TripOwnBookingSheet.show(context, day: day),
    );
  }

  Future<void> _removeShortlist(BuildContext context, TripPlanController c) async {
    final open = c.enquiriesForNight(day).where((e) => e.isUnconfirmed).toList();
    if (open.isNotEmpty) {
      if (await TripWithdrawSheet.showForRemove(context, open: open)) c.clearShortlist(day);
      return;
    }
    final names = c.plan.value?.dayAt(day)?.stayShortlist.map((s) => s.name).join(', ') ?? '';
    if (!context.mounted) return;
    await _confirmClear(context, TripStrings.removeFromPlan, names, () => c.clearShortlist(day));
  }

  Future<void> _confirmClear(BuildContext context, String title, String name, VoidCallback onRemove,
      {String? note}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(sheetCtx) + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Remove', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok == true) onRemove();
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color surface;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TripTileState state;
  final TripTileStatus status;
  final TripDisplayStatus? display;
  final TripAdvanceModel? advance;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.onLongPress,
    this.state = TripTileState.active,
    this.status = TripTileStatus.none,
    this.display,
    this.advance,
  });

  @override
  Widget build(BuildContext context) {
    final active = state == TripTileState.active;
    final muted = state == TripTileState.pending ? AppColors.textLight : AppColors.textHint;
    final iconColor = active ? accent : muted;
    final shown = display;
    final adv = advance?.status;
    final coloured = shown != null && shown != TripDisplayStatus.shortlisted;
    final booked = status == TripTileStatus.booked || coloured;
    final barColor = adv != null
        ? TripStatusVisuals.advanceBar(adv)
        : shown != null
            ? TripStatusVisuals.bar(shown)
            : switch (status) {
                TripTileStatus.selected => TripStatusColors.shortlisted,
                TripTileStatus.booked => TripStatusColors.booked,
                _ => Colors.transparent,
              };
    final tone = adv != null
        ? TripStatusVisuals.advanceText(adv)
        : (coloured ? TripStatusVisuals.text(shown) : TripStatusColors.booked);
    final fill = adv != null
        ? TripStatusVisuals.advanceSurface(adv)
        : (coloured ? TripStatusVisuals.surface(shown) : TripStatusColors.bookedSurface);
    final edge = adv != null ? barColor : (coloured ? TripStatusVisuals.bar(shown) : TripStatusColors.booked);
    final chevron = booked ? tone : (selected ? accent : AppColors.textHint);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: active && onLongPress != null
          ? () {
              if (!TripPlanController.to.isCompleted) onLongPress!();
            }
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: booked ? fill : (selected ? surface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active && booked
                ? edge.withValues(alpha: 0.6)
                : (active && selected ? accent.withValues(alpha: 0.6) : AppColors.divider),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: barColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, size: 15, color: iconColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active ? AppColors.textDark : muted),
                              ),
                              Text(
                                subtitle,
                                maxLines: booked ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10.5,
                                    color: active ? (booked ? tone : AppColors.textLight) : muted),
                              ),
                            ],
                          ),
                        ),
                        if (active && onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: chevron),
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
  }
}
