import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/gradient_button.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
import '../taxi_option_sets.dart';
import 'models/ask_models.dart';
import 'models/taxi_ways_models.dart';
import 'taxi_ways_ask_repository.dart';
import 'taxi_ways_strings.dart';

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

  String get _buttonLabel {
    final legs = widget.request.legs;
    if (legs.length == 1) {
      final n = legs.first.taxiIds.length;
      return n == 1 ? TaxiWaysStrings.askOne : TaxiWaysStrings.askThese(n);
    }
    return legs.length == 2 ? TaxiWaysStrings.askBoth : TaxiWaysStrings.askAll(legs.length);
  }

  WayDriver? _driverFor(WayLeg leg, String taxiId) {
    final c = widget.chosen[leg.index];
    if (c != null && c.taxiId == taxiId) return c;
    for (final d in leg.topDrivers) {
      if (d.taxiId == taxiId) return d;
    }
    return null;
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final result = await _repo.ask(widget.request);
      if (!mounted) return;
      if (result.items.isEmpty) {
        AppToast.warning(TaxiWaysStrings.askFailed);
        setState(() => _sending = false);
        return;
      }
      AppToast.success(TaxiWaysStrings.asked(result.askedCount));
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(TaxiWaysAskRepository.errorMessage(e));
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final legs = widget.plan.legs;
    return PopScope(
      canPop: !_sending,
      child: TripSheetFrame(
        title: TaxiWaysStrings.askDrivers,
        description: '${TripFormat.shortDate(req.date)} · ${TaxiWaysStrings.peopleChip(req.people)}',
        children: [
          for (final l in req.legs) ...[
            _LegTile(
              leg: l,
              multi: req.legs.length > 1,
              driver: _driverFor(legs.firstWhere((x) => x.index == l.legIndex), l.taxiIds.first),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            TaxiWaysStrings.listedFares,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
          ),
          const SizedBox(height: 4),
          TripPaymentLine(text: TaxiWaysStrings.payLine),
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
  final bool multi;
  final WayDriver? driver;

  const _LegTile({required this.leg, required this.multi, required this.driver});

  @override
  Widget build(BuildContext context) {
    final backups = leg.taxiIds.length - 1;
    final fare = leg.listedFare;
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
                  driver?.driverName ?? '',
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
