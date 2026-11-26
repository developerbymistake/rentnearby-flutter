import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../buddy/shared/widgets/segment_tabs.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_enquiry_simple.dart';
import '../utils/trip_format.dart';
import 'my_enquiries_controller.dart';
import 'similar_stays.dart';
import 'traveller_enquiry_card.dart';

class MyEnquiriesScreen extends StatefulWidget {
  const MyEnquiriesScreen({super.key});

  @override
  State<MyEnquiriesScreen> createState() => _MyEnquiriesScreenState();
}

class _MyEnquiriesScreenState extends State<MyEnquiriesScreen> {
  late final MyEnquiriesController _c;
  final _scroll = ScrollController();
  final _flashKey = GlobalKey();
  final _highlight = RxnString();
  Worker? _focusWorker;
  Timer? _flashTimer;
  bool _similar = false;

  static final ListingTone _tone = ListingTone.forest;

  @override
  void initState() {
    super.initState();
    _c = MyEnquiriesController.ensure();
    _scroll.addListener(_onScroll);
    _focusWorker = ever(_c.focusId, (String? id) {
      if (id != null) _flash(id);
    });
    final args = Get.arguments;
    final map = args is Map ? args : const {};
    final id = map['enquiryId']?.toString();
    final bucket = MyEnquiryBucket.parse(map['bucket']);
    _similar = map['similar'] == true || map['similar'] == 'true';
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(id, bucket));
  }

  @override
  void dispose() {
    _focusWorker?.dispose();
    _flashTimer?.cancel();
    _scroll.dispose();
    if (identical(MyEnquiriesController.maybe, _c)) Get.delete<MyEnquiriesController>();
    super.dispose();
  }

  Future<void> _open(String? id, String? bucket) async {
    var target = bucket;
    if (id != null && id.isNotEmpty) target = await _c.bucketFor(id) ?? bucket;
    if (!mounted) return;
    _c.bucket.value = target ?? MyEnquiryBucket.waiting;
    await _c.load();
    if (!mounted || id == null || id.isEmpty) return;
    _flash(id);
    if (!_similar) return;
    final e = _c.items.firstWhereOrNull((x) => x.id == id);
    if (e != null && (e.isQuiet || !e.isOpen) && mounted) await SimilarStaysSheet.show(context, reference: e);
  }

  void _flash(String id) {
    _highlight.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, 3));
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _highlight.value == id) _highlight.value = null;
    });
  }

  void _reveal(String id, int tries) {
    if (!mounted || _highlight.value != id) return;
    final ctx = _flashKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
      return;
    }
    final index = _c.items.indexWhere((e) => e.id == id);
    if (index < 0 || tries <= 0 || !_scroll.hasClients) return;
    final p = _scroll.position;
    final perRow = (p.maxScrollExtent + p.viewportDimension) / _c.items.length;
    _scroll.jumpTo((index * perRow).clamp(0.0, p.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, tries - 1));
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _c.loadMore();
  }

  void _findAnother(TripEnquiryModel e) {
    final tripId = e.tripId;
    if (tripId == null) return;
    final plan = Get.isRegistered<TripPlanController>() ? Get.find<TripPlanController>() : null;
    if (plan != null && plan.trip.value?.id == tripId) {
      TripNavigation.reopenStayShortlist(e.cityLeg ?? 1);
    } else {
      TripNavigation.openOverview(tripId: tripId);
    }
  }

  ReplyRow? _tripRow(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    final text = [
      e.context.city,
      if (a != null && b != null) TripFormat.dayMonthRange(a, b),
      e.context.peopleLabel,
    ].whereType<String>().where((t) => t.trim().isNotEmpty).join(' · ');
    return text.isEmpty ? null : ReplyRow(text, '');
  }

  @override
  Widget build(BuildContext context) {
    return RepliesScaffold(
      tone: _tone,
      title: TripStringsEnq.myEnquiries,
      subtitle: TripStringsEnq.staysYouAsked,
      art: ListingArt.clipboard,
      onBack: () => Get.back(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pills(),
          Expanded(child: Obx(_body)),
        ],
      ),
    );
  }

  static const List<String> bucketKeys = [MyEnquiryBucket.waiting, MyEnquiryBucket.offers, MyEnquiryBucket.booked];
  static const List<String> _labels = [TripStringsEnq.boxWaiting, TripStringsEnq.boxOffers, TripStringsEnq.boxBooked];

  Widget _pills() {
    return Obx(() {
      final selected = bucketKeys.indexOf(_c.bucket.value);
      _c.counts.value;
      return SegmentTabs(
        key: const ValueKey('my_enquiries_tabs'),
        labels: _labels,
        selected: selected,
        tone: ListingTone.indigo,
        counts: {for (var i = 0; i < bucketKeys.length; i++) i: _c.countOf(bucketKeys[i])},
        solidBadges: const {0, 1, 2},
        margin: DS.gapInsets(l: 18, t: 8, r: 18, b: 6),
        onTap: (i) => _c.selectBucket(bucketKeys[i]),
      );
    });
  }

  String _emptyTitle(String bucket) => switch (bucket) {
        MyEnquiryBucket.offers => TripStringsEnq.noneOffers,
        MyEnquiryBucket.booked => TripStringsEnq.noneBooked,
        MyEnquiryBucket.past => TripStringsEnq.nonePast,
        _ => TripStringsEnq.noneWaiting,
      };

  Widget _pastLink() => Padding(
        padding: DS.gapInsets(t: 8, b: 8),
        child: Center(
          child: TextLink(label: '${TripStringsEnq.pastEnquiries} ›', tone: KitTone.stay, onTap: () => _c.selectBucket(MyEnquiryBucket.past)),
        ),
      );

  Widget _body() {
    final items = _c.items;
    final bucket = _c.bucket.value;
    final showPast = bucket != MyEnquiryBucket.past;
    final flash = _highlight.value;
    TripEnquiryController.to.busyIds.length;
    final bottom = DS.s(24) + MediaQuery.paddingOf(context).bottom;

    if (_c.loading.value && items.isEmpty) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [ReplyCardSkeleton(), ReplyCardSkeleton(), ReplyCardSkeleton()],
      );
    }
    final List<Widget> children;
    if (items.isEmpty) {
      children = [
        if (_c.failed.value)
          RepliesEmpty(
            tone: _tone,
            art: ListingArt.worldMap,
            title: TripStrings.couldNotLoad,
            message: TripStrings.checkConnection,
            actionLabel: TripStrings.retry,
            onAction: _c.load,
          )
        else
          RepliesEmpty(tone: _tone, art: ListingArt.clipboard, title: _emptyTitle(bucket), message: TripStringsEnq.noneSub),
        if (showPast) _pastLink(),
      ];
    } else {
      children = [
        for (final e in items)
          Center(
            key: e.id == flash ? _flashKey : ValueKey('mine-${e.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: TravellerEnquiryCard(
                enquiry: e,
                phone: e.owner.phone,
                listedPerNight: e.listedPerNight,
                busy: TripEnquiryController.to.busyIds.contains(e.id),
                highlighted: e.id == flash,
                firstRow: _tripRow(e),
                onSimilar: e.tripId == null || e.day == null ? null : () => SimilarStaysSheet.show(context, reference: e),
                onFindAnother: e.tripId == null ? null : () => _findAnother(e),
              ),
            ),
          ),
        if (_c.loadingMore.value) const ReplyCardSkeleton(),
        if (showPast && !_c.hasMore.value) _pastLink(),
      ];
    }
    return RefreshIndicator(
      color: _tone.g2,
      onRefresh: _c.refreshList,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottom),
        children: children,
      ),
    );
  }
}
