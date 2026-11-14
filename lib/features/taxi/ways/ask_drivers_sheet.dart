import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../trip/trip_strings_v2_find.dart';
import '../../trip/utils/trip_enquiry_rules.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_sheet_frame.dart';
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
    final tone = ListingTone.coral;
    return PopScope(
      canPop: !_sending,
      child: TripSheetFrame(
        tone: tone,
        closeEnabled: !_sending,
        art: ListingArt.speechBalloon,
        title: TaxiWaysStrings.askDrivers,
        description: '${TripFormat.shortDate(req.date)} · ${TaxiWaysStrings.peopleChip(req.people)}',
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${TaxiWaysStrings.listedFares}\n${TaxiWaysStrings.payLine}',
                style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.35),
              ),
            ),
            GradientPillButton(
              tone: tone,
              label: _buttonLabel,
              loading: _sending,
              height: 52,
              fontSize: 15,
              onTap: _sending ? null : _send,
            ),
          ],
        ),
        children: [
          for (final l in req.legs)
            _LegTile(
              leg: l,
              way: legs.firstWhere((x) => x.index == l.legIndex),
              pick: widget.chosen[l.legIndex],
              multi: req.legs.length > 1,
              people: req.people,
            ),
          if (cars > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(TripStringsA6.carsPerLeg(cars), style: Ink3D.text(12.5, FontWeight.w700, tone.text)),
            ),
          if (short) const JourneyNoteBox3D(text: TripStringsV2Find.veryShortNoticeDriver),
          if (_error != null) JourneyNoteBox3D(text: _error!, error: true),
        ],
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
    return JourneyLegTile3D(
      art: JourneyArt.forVehicle(driver?.vehicleTypeName, driver?.seats),
      tag: multi ? TaxiWaysStrings.carOf(leg.legIndex, leg.carOf) : null,
      fare: fare == null ? null : BrowseItem.inr(fare),
      route: TaxiWaysStrings.driversOn(leg.fromName, leg.toName, leg.taxiIds.length),
      names: names,
      badge: backups > 0 ? TaxiWaysStrings.askBackups(backups) : null,
      notes: [
        ?note,
        if (leg.comesFrom != null) TaxiWaysStrings.comesFrom(leg.comesFrom!),
      ],
    );
  }
}
