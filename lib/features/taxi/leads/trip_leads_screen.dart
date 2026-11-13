import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_taxi_owner.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/trip_report_traveller_sheet.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../trip/widgets/trip_status.dart';
import '../../stay/stay_strings_fin_c1.dart';
import '../setup/taxi_setup_controller.dart';
import 'journey_leg_tag.dart';
import 'trip_fare_sheet.dart';
import 'trip_lead_format.dart';
import 'trip_leads_controller.dart';

class TripLeadsScreen extends StatefulWidget {
  const TripLeadsScreen({super.key});

  @override
  State<TripLeadsScreen> createState() => _TripLeadsScreenState();
}

class _TripLeadsScreenState extends State<TripLeadsScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _ctrl = TripLeadsController.ensure();
  final _taxi = TaxiSetupController.ensure();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  final _highlight = RxnString();
  String? _targetId;
  Worker? _focusWorker;
  Worker? _bucketWorker;
  static const int _count = 6;
  late final AnimationController _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  Widget _enter(int i, int count, Widget child) => TemplateEntrance(
        animation: templateInterval(_anim, math.min(i, count - 1), count),
        animationController: _anim,
        child: child,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim.forward();
    _bucketWorker = ever<String>(_ctrl.bucket, (_) {
      if (mounted) _anim.forward(from: 0);
    });
    _scroll.addListener(_onScroll);
    final args = Get.arguments;
    _targetId = args is Map ? args['enquiryId']?.toString() : null;
    if (!_taxi.hasLoaded.value) _taxi.load();
    _ctrl.focusId.value = null;
    _focusWorker = ever<String?>(_ctrl.focusId, (id) {
      if (id == null || !mounted) return;
      _ctrl.focusId.value = null;
      _flash(id);
    });
    _init();
  }

  @override
  void dispose() {
    _focusWorker?.dispose();
    _bucketWorker?.dispose();
    _anim.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.refreshList();
  }

  Future<void> _init() async {
    final id = _targetId;
    _ctrl.bucket.value = TripLeadBucket.newOnes;
    if (id != null) {
      final bucket = await _ctrl.bucketFor(id);
      if (bucket != null) _ctrl.bucket.value = bucket;
    }
    await _ctrl.load();
    if (id == null || !mounted) return;
    _flash(id);
  }

  void _flash(String id) {
    _highlight.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlight.value == id) _highlight.value = null;
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _ctrl.loadMore();
  }


  static final ListingTone _tone = ListingTone.coral;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: KitStatusBar(
        lightIcons: false,
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            _enter(0, 3, _header()),
            const NotificationOffBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(children: [
                  _enter(1, 3, _chips(compact: box.maxHeight < _compactBelow)),
                  Obx(() => Get.find<AuthController>().taxisEnabled ? const SizedBox.shrink() : _pausedNote()),
                  Expanded(child: Obx(_body)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: const TaxiPayBar(text: TripStrings.taxiPayLine),
    );
  }

  Widget _header() => Obx(() {
        final name = Get.find<AuthController>().user.value?.name;
        final t = _taxi.taxi.value;
        final sub = name != null && name.isNotEmpty
            ? StayFinStrings.taxiSubtitle(name)
            : [t?.plateDisplay ?? '', t?.vehicleTypeName ?? ''].where((s) => s.isNotEmpty).join(' · ');
        return PageHeader3D(
          tone: _tone,
          title: TripStrings.tripLeads,
          subtitle: sub.isEmpty ? null : sub,
          art: ListingArt.taxi,
          inlineTitle: true,
          onBack: () => Get.back(),
        );
      });

  static const _bucketLook = {
    TripLeadBucket.newOnes: ListingArt.speechBalloon,
    TripLeadBucket.replied: ListingArt.clipboard,
    TripLeadBucket.booked: ListingArt.calendar,
    TripLeadBucket.closed: ListingArt.key,
  };

  static ListingTone _bucketTone(String key) => switch (key) {
        TripLeadBucket.replied => ListingTone.cB,
        TripLeadBucket.booked => ListingTone.teal,
        TripLeadBucket.closed => ListingTone.cD,
        _ => ListingTone.cA,
      };

  static const double _compactBelow = 480;

  Widget _chips({required bool compact}) {
    return Obx(() {
      final selected = _ctrl.bucket.value;
      final n = _ctrl.newCount.value;
      final labels = {
        TripLeadBucket.newOnes: n > 0 ? TripStrings.newChip(n) : TripStrings.newPill,
        TripLeadBucket.replied: TripStrings.repliedChip,
        TripLeadBucket.booked: TripStrings.bookedChip,
        TripLeadBucket.closed: TripStrings.closedChip,
      };
      Widget chip(String key) => TaxiBucketChip(
            tone: _bucketTone(key),
            art: _bucketLook[key]!,
            label: labels[key]!,
            selected: selected == key,
            onTap: () => _ctrl.selectBucket(key),
            compact: compact,
          );
      const all = TripLeadBucket.all;
      if (compact) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < all.length; i++) ...[if (i > 0) const SizedBox(width: 8), chip(all[i])],
              ]),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        child: Column(children: [
          for (var r = 0; r < all.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(children: [
              Expanded(child: chip(all[r])),
              const SizedBox(width: 12),
              Expanded(child: r + 1 < all.length ? chip(all[r + 1]) : const SizedBox.shrink()),
            ]),
          ],
        ]),
      );
    });
  }

  Widget _pausedNote() => Banner3D(kind: BannerKind.warn, art: ListingArt.calendar, title: TripStrings.pausedTaxiHere);

  Widget _column(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
      );

  String _emptyTitle(String bucket) => switch (bucket) {
        TripLeadBucket.replied => TripStrings.noReplied,
        TripLeadBucket.booked => TripStrings.noBooked,
        TripLeadBucket.closed => TripStrings.nothingClosed,
        _ => TripStrings.noLeads,
      };

  static double _tallNeed(BuildContext context, bool action) {
    final w = MediaQuery.sizeOf(context).width;
    final s = MediaQuery.textScalerOf(context);
    final art = w < 340 ? 150.0 : 186.0;
    final lines = w < 340 || s.scale(1) > 1.15 ? 3 : 2;
    return 100 + art - 66 + s.scale(30) + 6 + s.scale(21) * lines + 34 + (action ? 78 : 0) + 24;
  }

  Widget _body() {
    final items = _ctrl.items;
    final loading = _ctrl.loading.value;
    final failed = _ctrl.failed.value;
    final bucket = _ctrl.bucket.value;
    final highlight = _highlight.value;
    final moreFooter = _ctrl.loadingMore.value || _ctrl.loadMoreFailed.value ? 1 : 0;

    if (loading && items.isEmpty) {
      return _column(ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: 2,
        itemBuilder: (_, i) => _enter(i, 2, const ReplyCardSkeleton()),
      ));
    }
    if (items.isEmpty) {
      final off = failed && _ctrl.executionDisabled.value;
      StateCard3D empty(StateLayout layout) => off
          ? StateCard3D(
              tone: _tone,
              art: ListingArt.worldMap,
              title: TripStrings.plannerOff,
              message: TripStrings.plannerOffSubtitle,
              layout: layout,
            )
          : failed
              ? StateCard3D(
                  tone: _tone,
                  art: ListingArt.clipboard,
                  title: TripStrings.couldNotLoad,
                  message: TripStrings.checkConnection,
                  actionLabel: TripStrings.retry,
                  onAction: _ctrl.load,
                  layout: layout,
                )
              : StateCard3D(
                  tone: _tone,
                  art: ListingArt.speechBalloon,
                  title: _emptyTitle(bucket),
                  message: TripStrings.noLeadsSub,
                  layout: layout,
                );
      return RefreshIndicator(
        color: _tone.button,
        onRefresh: _ctrl.refreshList,
        child: LayoutBuilder(
          builder: (context, box) => _column(ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [_enter(0, 1, empty(box.maxHeight >= _tallNeed(context, failed && !off) ? StateLayout.tall : StateLayout.wide))],
          )),
        ),
      );
    }
    return RefreshIndicator(
      color: _tone.button,
      onRefresh: _ctrl.refreshList,
      child: _column(ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: items.length + moreFooter,
        itemBuilder: (_, i) {
          if (i >= items.length) return _moreFooter();
          final e = items[i];
          return _enter(
            i,
            _count,
            KeyedSubtree(
              key: _keys.putIfAbsent(e.id, () => GlobalKey()),
              child: _LeadCard(lead: e, highlighted: highlight == e.id, ctrl: _ctrl),
            ),
          );
        },
      )),
    );
  }

  Widget _moreFooter() {
    if (_ctrl.loadMoreFailed.value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: WhitePillButton(tone: _tone, label: TripStrings.retry, expand: false, height: 44, fontSize: 14, onTap: _ctrl.loadMore),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: _tone.button)),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.highlighted, required this.ctrl});

  final TripEnquiryModel lead;
  final bool highlighted;
  final TripLeadsController ctrl;

  static ListingTone _toneOf(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.asked => ListingTone.cA,
        TripDisplayStatus.fareSent => ListingTone.cB,
        TripDisplayStatus.bookedByYou => ListingTone.cF,
        TripDisplayStatus.confirmedByBoth => ListingTone.cE,
        _ => ListingTone.cD,
      };

  static bool _closed(TripDisplayStatus s) => _toneOf(s) == ListingTone.cD;

  @override
  Widget build(BuildContext context) {
    final e = lead;
    final city = TripStrings.tripMapSubtitle(e.context.city);
    var summary = TripLeadFormat.summary(e);
    if (e.context.city.isNotEmpty && summary.startsWith(city)) {
      summary = summary.substring(city.length).replaceFirst(RegExp(r'^ · '), '');
    }
    final status = TripStatusVisuals.label(e.display, ownerSide: true, taxi: true);
    final menuKey = GlobalKey();
    final journeyLine = TripLeadFormat.journeyLine(e);
    final rawLeg = e.context.text.startsWith('Car ') ? e.context.text.trim() : '';
    final rawExtra = TripLeadFormat.journeyExtra(e) ?? (journeyLine == null && rawLeg.isNotEmpty ? rawLeg : null);
    final tail = rawExtra?.trim().replaceFirst(RegExp(r'\.$'), '').toLowerCase() ?? '';
    final extra = tail.isEmpty || summary.toLowerCase().contains(tail) ? null : rawExtra;
    return Obx(() {
      final busy = ctrl.busyIds.contains(e.id);
      return TaxiLeadCard3D(
        tone: _toneOf(e.display),
        guest: TripLeadFormat.guest(e),
        city: e.context.city.isNotEmpty ? city : '',
        urgent: e.isUrgent && e.isUnconfirmed ? TripStrings.urgent : null,
        pills: [if (status.isNotEmpty) status],
        summary: summary,
        journey: journeyLine ?? JourneyLegTag.fromLead(e),
        places: TripLeadFormat.spots(e),
        detail: _detail(e),
        extra: extra,
        pillColor: _closed(e.display) ? TaxiOwnerLook.rejected : null,
        highlighted: highlighted,
        menuKey: menuKey,
        onMenu: (e.traveller.id ?? '').isNotEmpty ? () => _menu(context, menuKey, e) : null,
        buttons: _buttons(context, e, busy),
      );
    });
  }

  void _menu(BuildContext context, GlobalKey key, TripEnquiryModel e) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    showMenu3D(context, anchor: rect, width: 236, coverAnchor: true, items: [
      MenuItem3D(label: TripStrings.reportTraveller, art: ListingArt.pushpin, onTap: () => TripReportTravellerSheet.show(context, enquiry: e)),
    ]);
  }

  String? _detail(TripEnquiryModel e) {
    final t = e.taxi;
    switch (e.display) {
      case TripDisplayStatus.fareSent:
        if (t?.driverFare != null) {
          final listed = TripLeadFormat.listedTotal(e);
          return TripStrings.youReplied(
              BrowseItem.inr(t!.driverFare!), listed == null ? '' : BrowseItem.inr(listed), TripLeadFormat.dayCount(e));
        }
      case TripDisplayStatus.bookedByYou:
        if (t?.agreedFare != null) return TripStrings.saysAgreedFare(BrowseItem.inr(t!.agreedFare!), TripLeadFormat.dates(e));
      default:
    }
    return null;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String art,
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: art,
      title: title,
      body: body,
      cancelLabel: TripStrings.cancelAction,
      confirmLabel: action,
      destructive: danger,
    );
    return ok == true;
  }

  Future<void> _notAvailable(BuildContext context) async {
    final ok = await _confirm(context,
        art: ListingArt.calendar,
        title: TripStrings.notAvailableLead,
        body: TripStrings.notAvailableLeadBody,
        action: TripStrings.notAvailableAction,
        danger: true);
    if (ok) await ctrl.notAvailable(lead.id);
  }

  Future<void> _yes(BuildContext context) async {
    final e = lead;
    final fare = e.taxi?.agreedFare;
    final ok = await _confirm(context,
        art: ListingArt.key,
        title: TripStrings.confirmBookingQ,
        body: TripStrings.confirmBookingBody(
            TripLeadFormat.guest(e), fare == null ? '' : BrowseItem.inr(fare), TripLeadFormat.dates(e)),
        action: TripStrings.yesConfirm);
    if (ok) await ctrl.confirm(e.id);
  }

  Future<void> _notMe(BuildContext context) async {
    final ok = await _confirm(context,
        art: ListingArt.speechBalloon,
        title: TripStrings.notYourBooking,
        body: TripStrings.notYourBookingBody(TripLeadFormat.guest(lead)),
        action: TripStrings.notMe,
        danger: true);
    if (ok) await ctrl.deny(lead.id);
  }

  List<TaxiLeadButton?> _buttons(BuildContext context, TripEnquiryModel e, bool busy) {
    final phone = e.traveller.phone;
    final canCall = phone != null && ContactLauncher.tenDigits(phone).isNotEmpty;
    TaxiLeadButton btn(String label, VoidCallback onTap, {bool solid = false}) =>
        TaxiLeadButton(label: label, onTap: onTap, busy: busy, kind: solid ? TaxiLeadButtonKind.solid : TaxiLeadButtonKind.glass);
    TaxiLeadButton? call({bool solid = false}) => canCall ? btn(TripStrings.callTraveller, () => ContactLauncher.call(phone), solid: solid) : null;

    switch (e.display) {
      case TripDisplayStatus.asked:
        return [
          call(solid: true),
          btn(TripStrings.confirmFare, () => TripFareSheet.show(context, lead: e), solid: true),
          btn(TripStrings.notAvailableAction, () => _notAvailable(context)),
        ];
      case TripDisplayStatus.fareSent:
        final left = e.taxi?.fareEditsLeft ?? 0;
        return [
          call(solid: true),
          btn(TripStrings.changeFare,
              left > 0 ? () => TripFareSheet.show(context, lead: e) : () => AppToast.warning(TripStrings.fareLimit)),
          btn(TripStrings.notAvailableAction, () => _notAvailable(context)),
        ];
      case TripDisplayStatus.bookedByYou:
        return [
          call(),
          btn(TripStrings.yesConfirm, () => _yes(context), solid: true),
          btn(TripStrings.notMe, () => _notMe(context)),
        ];
      case TripDisplayStatus.confirmedByBoth:
        return [
          call(),
          if (!TripLeadBucket.hasEnded(e)) btn(TripStrings.cancelBooking, () => ctrl.cancel(context, e)) else null,
          null,
        ];
      default:
        return const [null, null, null];
    }
  }
}
