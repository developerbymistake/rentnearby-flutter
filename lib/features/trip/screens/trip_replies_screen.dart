import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../../utils/contact_launcher.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_shortlist_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../enquiries/similar_stays.dart';
import '../enquiries/traveller_enquiry_card.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_archived_view.dart';
import '../widgets/trip_not_found_view.dart';
import '../widgets/trip_status.dart';
import 'trip_replies_leg_parts.dart';

class TripRepliesScreen extends StatefulWidget {
  const TripRepliesScreen({super.key});

  @override
  State<TripRepliesScreen> createState() => _TripRepliesScreenState();
}

const int _maxOpenAsks = 3;

class _Entry {
  final String stayId;
  final String name;
  final TripEnquiryModel? enquiry;
  const _Entry({required this.stayId, required this.name, this.enquiry});

  TripDisplayStatus get status => enquiry?.display ?? TripDisplayStatus.shortlisted;
}

class _TripRepliesScreenState extends State<TripRepliesScreen> with TickerProviderStateMixin {
  late final AnimationController _anim;
  String _shown = '';
  late final TripPlanController _c;
  late final int _day;
  String? _tripId;
  String? _enquiryId;
  String? _flashId;
  Timer? _flashTimer;
  bool _started = false;
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _c = TripPlanController.to;
    _c.openPages++;
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    final day = map['day'];
    _day = (day is num ? day.toInt() : int.tryParse('${day ?? ''}')) ?? 1;
    _tripId = map['tripId']?.toString();
    _enquiryId = map['enquiryId']?.toString();
    _flashId = _enquiryId;
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _flashId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
      if (_c.openPages > 0) unawaited(_c.refreshEnquiries());
      _c.releaseIfIdle();
    }
    _flashTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _play(String kind) {
    if (_shown == kind) return;
    _shown = kind;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anim.forward(from: 0);
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final id = _tripId;
    if (id != null && _c.trip.value?.id != id) {
      await _c.open(id);
    } else {
      await _c.refreshEnquiries();
    }
    if (!mounted) return;
    setState(() => _started = true);
    final stale = _c.stayEnquiriesOf(_legIndex).any((e) => e.display == TripDisplayStatus.offered && e.openOffer == null);
    if (stale && !_retried) {
      _retried = true;
      await _c.refreshEnquiries();
    }
  }

  int get _legIndex => _c.legIndexOf(_day);

  int get _rankDay {
    final id = _enquiryId;
    if (id == null) return _day;
    for (final e in _c.enquiries) {
      if (e.id == id) return _c.dayOfDate(e.checkIn) ?? e.day ?? _day;
    }
    return _day;
  }

  static int _rank(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.confirmedByBoth => 0,
        TripDisplayStatus.confirmedByYou => 1,
        TripDisplayStatus.offered => 2,
        TripDisplayStatus.asked => 3,
        TripDisplayStatus.shortlisted => 4,
        _ when s.isRed => 5,
        _ => 6,
      };

  List<_Entry> _entries() {
    final byStay = <String, TripEnquiryModel>{};
    final focus = _enquiryId;
    if (focus != null) {
      for (final e in _c.enquiries) {
        if (e.id == focus) byStay[e.listingId] = e;
      }
    }
    for (final e in _c.stayEnquiriesOf(_legIndex)) {
      byStay.putIfAbsent(e.listingId, () => e);
    }
    final out = <_Entry>[];
    for (final e in byStay.values) {
      out.add(_Entry(stayId: e.listingId, name: e.listingName, enquiry: e));
    }
    final indexed = out.asMap().entries.toList()
      ..sort((a, b) {
        final r = _rank(a.value.status).compareTo(_rank(b.value.status));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return [for (final x in indexed) x.value];
  }

  String? _phone(_Entry x) {
    final raw = x.enquiry?.owner.phone;
    if (raw != null && ContactLauncher.tenDigits(raw).isNotEmpty) return raw;
    if (!Get.isRegistered<TripSupplyController>()) return null;
    for (final s in Get.find<TripSupplyController>().stays) {
      final p = s.ownerPhone;
      if (s.id == x.stayId && p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  int? _listed(_Entry x) {
    final dated = x.enquiry?.status == TripEnquiryStatuses.asked ? x.enquiry?.listedPerNight : null;
    if (dated != null) return dated;
    if (!Get.isRegistered<TripSupplyController>()) return null;
    for (final s in Get.find<TripSupplyController>().stays) {
      if (s.id == x.stayId) return s.minPricePerNight;
    }
    return null;
  }

  bool get _archivedHere => _c.isArchived && (_tripId == null || _c.trip.value?.id == _tripId);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _c.plan.value;
      if (_archivedHere) return TripArchivedView(trip: _c.trip.value!);
      return RepliesScaffold(
        tone: ListingTone.forest,
        title: TripStrings.stayReplies,
        subtitle: _subtitle(),
        art: ListingArt.hotel,
        leg: TripRepliesLegParts.legLine(_c, _rankDay),
        onBack: () => Get.back(),
        body: _buildBody(),
      );
    });
  }

  String _subtitle() {
    final date = _c.dateOf(_rankDay);
    final city = _c.legOf(_rankDay).cityName;
    if (date == null) return city.isEmpty ? _c.cityName : city;
    final days = _c.legDays(_c.legIndexOf(_rankDay));
    final first = days.isEmpty ? null : _c.dateOf(days.first);
    final last = days.isEmpty ? null : _c.dateOf(days.last);
    final from = first ?? date;
    final to = last == null ? date : DateTime(last.year, last.month, last.day + 1);
    return [city.isEmpty ? _c.cityName : city, TripFormat.dayMonthRange(from, to), _c.settings.peopleSummary]
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .join(' · ');
  }

  Widget _scroll(List<Widget> children, [String kind = 'list']) {
    _play(kind);
    return RefreshIndicator(
      color: ListingTone.forest.g2,
      onRefresh: _c.refreshEnquiries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: DS.s(24) + MediaQuery.paddingOf(context).bottom),
        children: [
          for (var i = 0; i < children.length; i++)
            TemplateEntrance(
              animation: templateInterval(_anim, i, children.length),
              animationController: _anim,
              child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: children[i])),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (_c.tripGone.value) return const TripNotFoundView();
      if (_c.plannerOff.value) {
        return _scroll([
          RepliesEmpty(tone: _tone, art: ListingArt.compass, title: TripStrings.plannerOff, message: TripStrings.plannerOffSubtitle),
        ], 'plannerOff');
      }
      final plan = _c.plan.value;
      _c.enquiryList.length;
      TripEnquiryController.to.busyIds.length;
      if (plan == null && _c.openFailed.value) {
        return _scroll([_error(_load)], 'openFailed');
      }
      final entries = plan == null ? const <_Entry>[] : _entries();
      if (plan == null || (entries.isEmpty && (!_started || _c.enquiriesLoading.value))) {
        _play('loading');
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [ReplyCardSkeleton(), ReplyCardSkeleton(), ReplyCardSkeleton()],
        );
      }
      if (entries.isEmpty && _c.enquiriesFailed.value) {
        return _scroll([_error(_c.refreshEnquiries)], 'failed');
      }
      if (entries.isEmpty) {
        return _scroll([
          RepliesEmpty(tone: _tone, art: ListingArt.roundPushpin, title: TripStrings.noRepliesYet, message: TripStrings.hostsReply),
        ], 'empty');
      }
      final nothingToAsk = !_c.isCompleted && entries.every((x) => x.enquiry?.isRed ?? false);
      return _scroll([
        if (nothingToAsk)
          RepliesBanner(
            bad: true,
            art: ListingArt.roundPushpin,
            text: TripStrings.allAsksEnded,
            actionLabel: TripStrings.findAnother,
            onAction: () => TripNavigation.reopenStayShortlist(_legIndex),
          ),
        for (var i = 0; i < entries.length; i++) _card(entries[i], i),
        if (_similarRef(entries) case final ref?)
          SimilarStaysCard(reference: ref, onFindAnother: () => TripNavigation.reopenStayShortlist(_legIndex)),
        if (_canAskAnother(entries))
          ArtPillButton(tone: _tone, art: ListingArt.hotel, label: TripStringsA5.askAnotherStay, onTap: () => TripNavigation.reopenStayShortlist(_legIndex)),
      ], 'list');
    });
  }

  static final ListingTone _tone = ListingTone.forest;

  Widget _error(VoidCallback onRetry) => RepliesEmpty(
        tone: _tone,
        art: ListingArt.worldMap,
        title: TripStrings.couldNotLoad,
        message: TripStrings.checkConnection,
        actionLabel: TripStrings.retry,
        onAction: onRetry,
      );

  String get _stepKey => 'stay:$_legIndex';

  bool get _editable => !_c.isReadOnly && !_c.isDayPast(_day) && !_c.isCompleted;

  bool _canAskAnother(List<_Entry> entries) {
    if (_c.isReadOnly || _c.isDayPast(_day)) return false;
    if (entries.any((x) => x.enquiry?.isBooked ?? false)) return false;
    final free = Get.isRegistered<TripShortlistController>() ? TripShortlistController.to.freeOf(_stepKey, tripId: _c.trip.value?.id) : null;
    if (free != null) return free > 0;
    return entries.where((x) => (x.enquiry?.display.isOpen ?? false) && !(x.enquiry?.isQuiet ?? false)).length < _maxOpenAsks;
  }

  TripEnquiryModel? _similarRef(List<_Entry> entries) {
    if (!_editable || entries.any((x) => x.enquiry?.isBooked ?? false)) return null;
    TripEnquiryModel? best;
    for (final x in entries) {
      final e = x.enquiry;
      if (e == null || e.tripId == null || e.day == null) continue;
      final ended = e.isQuiet || e.isRed || (!e.isOpen && !e.isBooked);
      if (!ended) continue;
      final at = e.updatedAt ?? e.createdAt;
      final bestAt = best?.updatedAt ?? best?.createdAt;
      if (best == null || (at != null && (bestAt == null || at.isAfter(bestAt)))) best = e;
    }
    return best;
  }

  String? _legRange() {
    final days = _c.legDays(_legIndex);
    if (days.isEmpty) return null;
    final first = _c.dateOf(days.first);
    final last = _c.dateOf(days.last);
    if (first == null || last == null) return null;
    return TripFormat.dayMonthRange(first, DateTime(last.year, last.month, last.day + 1));
  }

  Widget _card(_Entry x, int i) {
    final e = x.enquiry;
    if (e == null) return const SizedBox.shrink();
    final busy = TripEnquiryController.to.busyIds.contains(e.id);
    final notes = <(ReplyNote, String)>[
      if (TripRepliesLegParts.wrongCityNote(context, _c, e) case final w?) (w, ListingArt.roundPushpin),
      if (TripRepliesLegParts.oldDatesNote(_c, e) case final o?) (o, ListingArt.calendar),
    ];
    final canAsk = _editable && e.tripId != null && e.day != null;
    return TravellerEnquiryCard(
      key: ValueKey('reply-${x.stayId}-${e.id}'),
      enquiry: e,
      phone: _phone(x),
      listedPerNight: _listed(x),
      busy: busy,
      readOnly: _c.isReadOnly,
      highlighted: _flashId != null && _flashId == e.id,
      planNotes: notes,
      tripRange: _legRange(),
      onRefresh: _c.refreshEnquiries,
      onSimilar: canAsk ? () => SimilarStaysSheet.show(context, reference: e) : null,
      onFindAnother: _c.isReadOnly ? null : () => TripNavigation.reopenStayShortlist(_legIndex),
    );
  }
}
