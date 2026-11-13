import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/location_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../trip_constants.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_mcd_a3.dart';
import '../utils/trip_format.dart';
import 'trip_sheet_frame.dart';
import 'trip_today_card.dart';

class TripProblemKinds {
  static const String driverNoShow = 'DriverNoShow';
  static const String hostNoRoom = 'HostNoRoom';
  static const String roadClosed = 'RoadClosed';
  static const String other = 'Other';
}

class TripProblemSheet {
  static Future<bool> show(BuildContext context, {required int day}) async {
    final done = await TripSheetFrame.show<bool>(context, _ProblemBody(day: day));
    return done == true;
  }
}

class _ProblemBody extends StatefulWidget {
  const _ProblemBody({required this.day});

  final int day;

  @override
  State<_ProblemBody> createState() => _ProblemBodyState();
}

class _ProblemBodyState extends State<_ProblemBody> {
  final _note = TextEditingController();
  String? _busyKind;
  bool _otherOpen = false;
  String? _pickerKind;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<({String name, String phone})> _contacts() {
    final c = TripPlanController.to;
    final day = widget.day;
    final out = <({String name, String phone})>[];
    void add(String name, String? phone) {
      if (phone != null && ContactLauncher.tenDigits(phone).isNotEmpty) out.add((name: name, phone: phone));
    }

    final stay = c.todayStay(day);
    if (stay != null) add(stay.listingName, TripTodayCard.stayPhone(stay));
    final taxi = c.todayTaxi(day);
    if (taxi != null) add(taxi.listingName, taxi.owner.phone);
    for (final e in _carRows(c)) {
      add(_carLabel(e), e.owner.phone);
    }
    for (final car in _journeyCars(c)) {
      add(_journeyCarLabel(car), car.phone);
    }
    return out;
  }

  List<TripEnquiryModel> _carRows(TripPlanController c) {
    final day = widget.day;
    if (c.todayDay == null || !c.isMultiCity || !c.isTravelDay(day)) return const [];
    return c.segmentRows(c.legIndexOf(day)).where((e) => e.isBooked).toList();
  }

  List<TripJourneyLeg> _journeyCars(TripPlanController c) => c.journeyToday?.legs ?? const <TripJourneyLeg>[];

  List<TripJourneyLeg> _cars(String kind) =>
      kind == TripProblemKinds.driverNoShow ? _journeyCars(TripPlanController.to) : const <TripJourneyLeg>[];

  List<TripEnquiryModel> _booked(String kind) {
    final c = TripPlanController.to;
    final taxis = c.problemTaxiRows(widget.day);
    return switch (kind) {
      TripProblemKinds.driverNoShow => [
          ...taxis,
          ..._carRows(c).where((e) => !taxis.any((x) => x.id == e.id)),
        ],
      TripProblemKinds.hostNoRoom => c.problemStayRows(widget.day),
      _ => const <TripEnquiryModel>[],
    };
  }

  String _journeyCarLabel(TripJourneyLeg car) =>
      TripStringsMcdA3.carCandidate(car.legIndex, car.driverName.isEmpty ? TripStrings.driver : car.driverName);

  Future<void> _pickCar(TripJourneyLeg car) async {
    if (_busyKind != null) return;
    final c = TripPlanController.to;
    final journeyId = c.journeyToday?.id;
    const kind = TripProblemKinds.driverNoShow;
    final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>().userLocation.value : null;
    setState(() => _busyKind = kind);
    final ok = await c.reportProblem(
      day: widget.day,
      kind: kind,
      note: _journeyCarLabel(car),
      latitude: loc?.latitude,
      longitude: loc?.longitude,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busyKind = null);
      return;
    }
    final queued = c.lastProblemQueued;
    Navigator.pop(context, true);
    if (queued) return;
    AppToast.info(TripStrings.problemNoted);
    if (journeyId != null) TripNavigation.openJourney(journeyId);
  }

  bool _spansEarlier(TripEnquiryModel e) {
    final date = TripPlanController.to.dateOf(widget.day);
    final first = e.checkIn;
    if (date != null && first != null) {
      return DateTime(first.year, first.month, first.day).isBefore(DateTime(date.year, date.month, date.day));
    }
    return e.isTaxi && e.days.isNotEmpty && e.days.reduce((a, b) => a < b ? a : b) < widget.day;
  }

  Future<void> _pick(String kind, {String? enquiryId}) async {
    if (_busyKind != null) return;
    if (kind == TripProblemKinds.other && !_otherOpen) {
      setState(() => _otherOpen = true);
      return;
    }
    final rows = _booked(kind);
    final cars = _cars(kind);
    if (enquiryId == null && rows.length + cars.length > 1) {
      setState(() => _pickerKind = _pickerKind == kind ? null : kind);
      return;
    }
    if (enquiryId == null && rows.isEmpty && cars.length == 1) {
      await _pickCar(cars.first);
      return;
    }
    FocusScope.of(context).unfocus();
    final c = TripPlanController.to;
    final day = widget.day;
    final id = enquiryId ?? (rows.isEmpty ? null : rows.first.id);
    final note = kind == TripProblemKinds.other ? _note.text.trim() : '';
    final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>().userLocation.value : null;
    setState(() => _busyKind = kind);
    final ok = await c.reportProblem(
      day: day,
      kind: kind,
      enquiryId: id,
      note: note.isEmpty ? null : note,
      latitude: loc?.latitude,
      longitude: loc?.longitude,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busyKind = null);
      return;
    }
    final queued = c.lastProblemQueued;
    final reported = rows.firstWhereOrNull((e) => e.id == id);
    Navigator.pop(context, true);
    if (queued) return;
    AppToast.info(TripStrings.problemNoted);
    switch (kind) {
      case TripProblemKinds.driverNoShow when reported != null && reported.isSegment:
        final journeyId = reported.context.journeyId ?? c.segmentJourney(c.legIndexOf(day))?.id;
        if (journeyId != null) {
          TripNavigation.openJourney(journeyId);
        } else {
          TripNavigation.openMap(day: day);
        }
      case TripProblemKinds.driverNoShow when c.todayDay == null:
        final todayJourney = c.journeyToday?.id;
        if (todayJourney != null) {
          TripNavigation.openJourney(todayJourney);
        } else {
          TripNavigation.openMap(day: day);
        }
      case TripProblemKinds.driverNoShow:
        TripNavigation.openTaxi(days: [day]);
      case TripProblemKinds.hostNoRoom:
        TripNavigation.openStay(TripPlanController.to.plan.value?.legIndexOf(day) ?? 0, nearLat: loc?.latitude, nearLng: loc?.longitude);
      default:
        TripNavigation.openMap(day: day);
    }
  }

  static final ListingTone _tone = ListingTone.indigo;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.enquiryList.length;
      c.plan.value;
      final offline = c.offline.value;
      final contacts = offline ? _contacts() : const <({String name, String phone})>[];
      return TripSheetFrame(
        tone: _tone,
        art: ListingArt.roundPushpin,
        size: SheetSize.list,
        title: TripStrings.whatWentWrong,
        description: TripStrings.problemFooter,
        children: [
          if (offline) _offlineBlock(contacts),
          _row(ListingTone.cA, ListingArt.taxi, TripStrings.driverDidNotCome, TripProblemKinds.driverNoShow),
          ..._extra(TripProblemKinds.driverNoShow),
          if (!c.problemOnTravelOnly) ...[
            _row(ListingTone.cE, ListingArt.hotel, TripStrings.hostNoRoom, TripProblemKinds.hostNoRoom),
            ..._extra(TripProblemKinds.hostNoRoom),
          ],
          _row(ListingTone.cF, ListingArt.worldMap, TripStrings.roadClosed, TripProblemKinds.roadClosed),
          _row(ListingTone.cB, ListingArt.clipboard, TripStrings.somethingElse, TripProblemKinds.other),
          if (_otherOpen) ...[
            PillField(
              tone: _tone,
              controller: _note,
              hint: TripStrings.whatHappened,
              firstLabel: false,
              minLines: 3,
              maxLines: 4,
              autofocus: true,
              enabled: _busyKind == null,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.problemNoteMax)],
            ),
            const SizedBox(height: 12),
            GradientPillButton(
              tone: _tone,
              label: TripStrings.done,
              height: 50,
              loading: _busyKind == TripProblemKinds.other,
              onTap: () => _pick(TripProblemKinds.other),
            ),
          ],
        ],
      );
    });
  }

  List<Widget> _extra(String kind) {
    final rows = _booked(kind);
    final cars = _cars(kind);
    if (rows.isEmpty && cars.isEmpty) return const [];
    final taxi = kind == TripProblemKinds.driverNoShow;
    if (rows.length + cars.length == 1) {
      if (rows.isEmpty) return const [];
      if (!_spansEarlier(rows.first)) return const [];
      return [RepliesBanner(art: ListingArt.calendar, text: TripStringsA5.failsNightAndLater(widget.day, taxi: taxi), margin: const EdgeInsets.only(top: 10))];
    }
    if (_pickerKind != kind) return const [];
    return [
      Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 0), child: Text(TripStrings.whichBooking, style: Ink3D.text(14, FontWeight.w700, Ink3D.title))),
      for (final e in rows) _candidate(e, taxi),
      for (final car in cars) CandidateRow3D(title: _journeyCarLabel(car), onTap: _busyKind == null ? () => _pickCar(car) : null),
    ];
  }

  String _carLabel(TripEnquiryModel e) {
    final name = (e.owner.name ?? '').isNotEmpty ? e.owner.name! : e.listingName;
    return TripStringsMcdA3.carCandidate(e.context.journeyLegIndex ?? 1, name.isEmpty ? TripStrings.driver : name);
  }

  Widget _candidate(TripEnquiryModel e, bool taxi) {
    final earlier = !e.isSegment && _spansEarlier(e);
    final kind = taxi ? TripProblemKinds.driverNoShow : TripProblemKinds.hostNoRoom;
    final a = e.checkIn;
    final b = e.checkOut;
    return CandidateRow3D(
      title: e.isSegment ? _carLabel(e) : (e.listingName.isEmpty ? (taxi ? TripStrings.driver : TripStrings.stay) : e.listingName),
      subtitle: !taxi && a != null && b != null ? TripFormat.dayMonthRange(a, b) : e.datesLabel,
      warn: earlier ? TripStringsA5.failsNightAndLater(widget.day, taxi: taxi) : null,
      onTap: _busyKind == null ? () => _pick(kind, enquiryId: e.id) : null,
    );
  }

  Widget _offlineBlock(List<({String name, String phone})> contacts) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: RepliesLook.warnSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TripStrings.noNetworkTitle, style: Ink3D.text(15, FontWeight.w700, RepliesLook.warnInk)),
          const SizedBox(height: 2),
          Text(TripStrings.callHostOrDriver, style: Ink3D.text(13, FontWeight.w400, RepliesLook.warnInk)),
          for (final x in contacts) ...[
            const SizedBox(height: 10),
            WhitePillButton(tone: _tone, label: '${TripStrings.call} · ${x.name}', height: 46, fontSize: 14, onTap: () => ContactLauncher.call(x.phone)),
          ],
        ],
      ),
    );
  }

  Widget _row(ListingTone tone, String art, String label, String kind) {
    final busy = _busyKind == kind;
    final otherOpen = kind == TripProblemKinds.other && _otherOpen;
    final selected = otherOpen || _pickerKind == kind;
    return ProblemOption3D(
      tone: tone,
      art: art,
      label: label,
      selected: selected,
      busy: busy && kind != TripProblemKinds.other,
      onTap: _busyKind == null && !otherOpen ? () => _pick(kind) : null,
    );
  }
}
