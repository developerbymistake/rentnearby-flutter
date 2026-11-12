import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.enquiryList.length;
      c.plan.value;
      final offline = c.offline.value;
      final contacts = offline ? _contacts() : const <({String name, String phone})>[];
      return TripSheetFrame(
        title: TripStrings.whatWentWrong,
        description: TripStrings.problemFooter,
        children: [
          TemplateStagger(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          if (offline) ...[
            _offlineBlock(contacts),
            const SizedBox(height: 12),
          ],
          _row(TravelIcon.taxi, TripStrings.driverDidNotCome, TripProblemKinds.driverNoShow),
          ..._extra(TripProblemKinds.driverNoShow),
          if (!c.problemOnTravelOnly) ...[
            const SizedBox(height: 8),
            _row(TravelIcon.stay, TripStrings.hostNoRoom, TripProblemKinds.hostNoRoom),
            ..._extra(TripProblemKinds.hostNoRoom),
          ],
          const SizedBox(height: 8),
          _row(TravelIcon.pin, TripStrings.roadClosed, TripProblemKinds.roadClosed),
          const SizedBox(height: 8),
          _row(TravelIcon.note, TripStrings.somethingElse, TripProblemKinds.other),
          if (_otherOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              enabled: _busyKind == null,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                ...noEmojiInputFormatters,
                LengthLimitingTextInputFormatter(TripConstants.problemNoteMax),
              ],
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: DesignColors.textStrong),
              decoration: InputDecoration(
                hintText: TripStrings.whatHappened,
                hintStyle: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: DesignColors.textMuted),
                filled: true,
                fillColor: DesignColors.scaffold,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RepliesTone.accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TripButton(
              label: TripStrings.done,
              height: 48,
              loading: _busyKind == TripProblemKinds.other,
              onPressed: () => _pick(TripProblemKinds.other),
            ),
          ],
            ],
          ),
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
      return [
        const SizedBox(height: 6),
        _affectNote(TripStringsA5.failsNightAndLater(widget.day, taxi: taxi)),
      ];
    }
    if (_pickerKind != kind) return const [];
    return [
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          TripStrings.whichBooking,
          style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w700, color: DesignColors.textSecondary),
        ),
      ),
      for (final e in rows) ...[
        _candidate(e, taxi),
        const SizedBox(height: 6),
      ],
      for (final car in cars) ...[
        _carCandidate(car),
        const SizedBox(height: 6),
      ],
    ];
  }

  static const BorderRadius _r = BorderRadius.all(Radius.circular(16));

  static List<BoxShadow> get _shadow =>
      [ShadowTokens.tint(DesignColors.textGrey, ShadowSpec.soft)];

  Widget _carCandidate(TripJourneyLeg car) => Container(
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: _r, boxShadow: _shadow),
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busyKind == null ? () => _pickCar(car) : null,
          borderRadius: _r,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              _journeyCarLabel(car),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.textStrong),
            ),
          ),
        ),
        ),
      );

  Widget _affectNote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: RepliesTone.warnSurface, borderRadius: BorderRadius.circular(8)),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w500, color: RepliesTone.warn, height: 1.35),
        ),
      );

  String _carLabel(TripEnquiryModel e) {
    final name = (e.owner.name ?? '').isNotEmpty ? e.owner.name! : e.listingName;
    return TripStringsMcdA3.carCandidate(e.context.journeyLegIndex ?? 1, name.isEmpty ? TripStrings.driver : name);
  }

  Widget _candidate(TripEnquiryModel e, bool taxi) {
    final earlier = !e.isSegment && _spansEarlier(e);
    final kind = taxi ? TripProblemKinds.driverNoShow : TripProblemKinds.hostNoRoom;
    return Container(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: _r, boxShadow: _shadow),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busyKind == null ? () => _pick(kind, enquiryId: e.id) : null,
        borderRadius: _r,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                e.isSegment
                    ? _carLabel(e)
                    : e.listingName.isEmpty
                        ? (taxi ? TripStrings.driver : TripStrings.stay)
                        : e.listingName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: DesignColors.textStrong),
              ),
              if (e.datesLabel.isNotEmpty)
                Text(
                  e.datesLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textMuted),
                ),
              if (earlier)
                Text(
                  TripStringsA5.failsNightAndLater(widget.day, taxi: taxi),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: RepliesTone.warn, height: 1.35),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _offlineBlock(List<({String name, String phone})> contacts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: RepliesTone.warnSurface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            TripStrings.noNetworkTitle,
            style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: RepliesTone.warn),
          ),
          const SizedBox(height: 2),
          const Text(
            TripStrings.callHostOrDriver,
            style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: RepliesTone.warn),
          ),
          for (final x in contacts) ...[
            const SizedBox(height: 8),
            TripActionChip(
              icon: Icons.call_rounded,
              label: '${TripStrings.call} · ${x.name}',
              onTap: () => ContactLauncher.call(x.phone),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String icon, String label, String kind) {
    final busy = _busyKind == kind;
    final otherOpen = kind == TripProblemKinds.other && _otherOpen;
    final selected = otherOpen || _pickerKind == kind;
    return Container(
      decoration: BoxDecoration(
        color: selected ? RepliesTone.accentSurface : DesignColors.surface,
        borderRadius: _r,
        boxShadow: _shadow,
      ),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busyKind == null && !otherOpen ? () => _pick(kind) : null,
        borderRadius: _r,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          foregroundDecoration: selected
              ? BoxDecoration(borderRadius: _r, border: Border.all(color: RepliesTone.accent, width: 1.5))
              : null,
          child: Row(
            children: [
              TravelIcon(icon, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName, fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignColors.textStrong),
                ),
              ),
              if (busy && kind != TripProblemKinds.other)
                const KitDots(color: RepliesTone.accent)
              else
                const Icon(Icons.chevron_right_rounded, size: 20, color: DesignColors.textMuted),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
