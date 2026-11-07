import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../trip/trip_strings_v2_find.dart';
import '../../trip/utils/trip_enquiry_rules.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../taxi_option_sets.dart';
import 'models/ask_models.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_ask_repository.dart';
import 'taxi_ways_strings.dart';
import 'trip_strings_a6.dart';

class AskDriversSheet {
  /// The caller saves the journey first and passes its id; the sheet never saves.
  static Future<AskResult?> show(
    BuildContext context, {
    required WayPlan plan,
    required Map<int, WayDriver> chosen,
    required DateTime date,
    required int people,
    required String journeyId,
    required String fromName,
    required String toName,
  }) {
    final request = AskDriversRequest.fromPlan(
      plan: plan,
      chosen: chosen,
      date: date,
      people: people,
      journeyId: journeyId,
      fromName: fromName,
      toName: toName,
    );
    if (request == null) return Future.value(null);
    return TripSheetFrame.show<AskResult>(
      context,
      _AskBody(plan: plan, request: request, chosen: chosen),
    );
  }
}

class _AskBody extends StatefulWidget {
  final WayPlan plan;
  final AskDriversRequest request;
  final Map<int, WayDriver> chosen;

  const _AskBody({required this.plan, required this.request, required this.chosen});

  @override
  State<_AskBody> createState() => _AskBodyState();
}

class _AskBodyState extends State<_AskBody> {
  static const _repo = TaxiWaysAskRepository();
  bool _sending = false;
  String? _error;

  String get _buttonLabel {
    final legs = widget.request.legs;
    if (legs.length == 1) {
      final n = legs.first.taxiIds.length;
      return n == 1 ? TaxiWaysStrings.askOne : TaxiWaysStrings.askThese(n);
    }
    return legs.length == 2 ? TaxiWaysStrings.askBoth : TaxiWaysStrings.askAll(legs.length);
  }

  int _carsPerLeg(List<WayLeg> legs) {
    var most = 1;
    for (final l in legs) {
      final n = l.carsWith(widget.chosen[l.index], widget.request.people);
      if (n > most) most = n;
    }
    return most;
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await _repo.ask(widget.request);
      if (!mounted) return;
      if (result.items.isEmpty) {
        setState(() {
          _sending = false;
          _error = TaxiWaysStrings.askFailed;
        });
        return;
      }
      AppToast.success(TaxiWaysStrings.asked(result.askedCount));
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = TaxiWaysAskRepository.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final legs = widget.plan.legs;
    final cars = _carsPerLeg(legs);
    final short = TripEnquiryRules.enquiryExpiry(req.date, req.date, DateTime.now().toUtc()).veryShortNotice;
    return PopScope(
      canPop: !_sending,
      child: TripSheetFrame(
        title: TaxiWaysStrings.askDrivers,
        description: '${TripFormat.shortDate(req.date)} · ${TaxiWaysStrings.peopleChip(req.people)}',
        children: [
          for (final l in req.legs) ...[
            _LegTile(
              leg: l,
              way: legs.firstWhere((x) => x.index == l.legIndex),
              pick: widget.chosen[l.legIndex],
              multi: req.legs.length > 1,
              people: req.people,
            ),
            const SizedBox(height: 8),
          ],
          if (cars > 1) ...[
            Text(
              TripStringsA6.carsPerLeg(cars),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
            ),
            const SizedBox(height: 4),
          ],
          if (short) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Iconsax.warning_2, size: 16, color: AppColors.warningText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(TripStringsV2Find.veryShortNoticeDriver,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            TaxiWaysStrings.listedFares,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
          ),
          const SizedBox(height: 4),
          TripPaymentLine(text: TaxiWaysStrings.payLine),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.errorText, height: 1.35),
              ),
            ),
          ],
        ],
        footer: GradientButton(
          label: _buttonLabel,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
          gradient: TaxiColors.gradient,
          shadowColor: TaxiColors.accent,
        ),
      ),
    );
  }
}

class _LegTile extends StatelessWidget {
  final AskLegRequest leg;
  final WayLeg way;
  final WayDriver? pick;
  final bool multi;
  final int people;

  const _LegTile({
    required this.leg,
    required this.way,
    required this.pick,
    required this.multi,
    required this.people,
  });

  @override
  Widget build(BuildContext context) {
    final driver = way.driverFor(pick);
    final cover = way.coverOthersFor(pick);
    final asked = cover.where(leg.taxiIds.contains).length;
    final backups = leg.taxiIds.length - 1 - asked;
    final cars = way.carsWith(pick, people);
    final total = way.fareWith(pick, people);
    final fare = total > 0 ? total : null;
    final names = [
      if (driver != null) driver.driverName,
      for (final id in cover)
        if (way.driverById(id) != null) way.driverById(id)!.driverName,
    ].join(' + ');
    final note = pick == null ? TripStringsA6.legSeats(way) : TripStringsA6.seatsNote(pick!.seats, cars, people);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TaxiColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (multi)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                TaxiWaysStrings.carOf(leg.legIndex, leg.carOf),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
              ),
            ),
          Text(
            TaxiWaysStrings.driversOn(leg.fromName, leg.toName, leg.taxiIds.length),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Iconsax.car, size: 16, color: TaxiColors.accentDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMedium),
                ),
              ),
              if (fare != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    BrowseItem.inr(fare),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warningText),
                  ),
                ),
            ],
          ),
          if (cars > 1 && note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
          if (backups > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                TaxiWaysStrings.askBackups(backups),
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ),
          if (leg.comesFrom != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                TaxiWaysStrings.comesFrom(leg.comesFrom!),
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ),
        ],
      ),
    );
  }
}
