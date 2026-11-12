import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/kit_tone.dart';
import 'package:bakhli/design/extra/module_header.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/trip_report_traveller_sheet.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_payment_line.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../trip/widgets/trip_status.dart';
import '../../trip/widgets/trip_status_card.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(children: [
        _enter(0, 3, _header(), ),
        const NotificationOffBanner(),
        _enter(1, 3, _chips()),
        Obx(() => Get.find<AuthController>().taxisEnabled ? const SizedBox.shrink() : _pausedNote()),
        Expanded(child: Obx(_body)),
        _footer(),
      ]),
    );
  }

  Widget _header() => Obx(() {
        final name = Get.find<AuthController>().user.value?.name;
        final t = _taxi.taxi.value;
        final sub = name != null && name.isNotEmpty
            ? StayFinStrings.taxiSubtitle(name)
            : [t?.plateDisplay ?? '', t?.vehicleTypeName ?? ''].where((s) => s.isNotEmpty).join(' · ');
        return ModuleHeader(
          title: TripStrings.tripLeads,
          subtitle: sub.isEmpty ? null : sub,
          tone: KitTone.taxi,
          onBack: () => Get.back(),
          leadingAsset: TravelIcon.taxi,
          autoHeight: true,
        );
      });

  Widget _chips() {
    return Obx(() {
      final selected = _ctrl.bucket.value;
      final n = _ctrl.newCount.value;
      final labels = {
        TripLeadBucket.newOnes: n > 0 ? TripStrings.newChip(n) : TripStrings.newPill,
        TripLeadBucket.replied: TripStrings.repliedChip,
        TripLeadBucket.booked: TripStrings.bookedChip,
        TripLeadBucket.closed: TripStrings.closedChip,
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final key in TripLeadBucket.all)
              PickChip(
                label: labels[key]!,
                selected: selected == key,
                activeColor: DesignColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => _ctrl.selectBucket(key),
              ),
          ]),
        ),
      );
    });
  }

  Widget _pausedNote() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: journeyBarCard(TripLook.warning),
          child: ClipRRect(
            borderRadius: TripLook.softRadius,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: TripLook.warning, width: 4))),
              child: Text(TripStrings.pausedTaxiHere,
                  style: FitnessAppTheme.body2.copyWith(fontSize: 12, color: DesignColors.textPrimary)),
            ),
          ),
        ),
      );

  Widget _footer() => Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, AppInsets.bottomViewPadding(context) + 10),
        child: const TripPaymentLine(text: TripStrings.taxiPayLine),
      );

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

  Widget _body() {
    final items = _ctrl.items;
    final loading = _ctrl.loading.value;
    final failed = _ctrl.failed.value;
    final bucket = _ctrl.bucket.value;
    final highlight = _highlight.value;
    final moreFooter = _ctrl.loadingMore.value || _ctrl.loadMoreFailed.value ? 1 : 0;

    if (loading && items.isEmpty) {
      return _column(ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _enter(i, 3, const JourneySkeletonCard(buttons: 3)),
      ));
    }
    if (items.isEmpty) {
      final empty = failed && _ctrl.executionDisabled.value
          ? const TripPlanEmpty(
              image: TravelIcon.map,
              title: TripStrings.plannerOff,
              subtitle: TripStrings.plannerOffSubtitle,
            )
          : failed
          ? TripPlanEmpty(
              image: TravelIcon.note,
              title: TripStrings.couldNotLoad,
              subtitle: TripStrings.checkConnection,
              onRetry: _ctrl.load,
              retryLabel: TripStrings.retry,
            )
          : TripPlanEmpty(
              image: TravelIcon.chat,
              title: _emptyTitle(bucket),
              subtitle: TripStrings.noLeadsSub,
            );
      return RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _ctrl.refreshList,
        child: _column(ListView(physics: const AlwaysScrollableScrollPhysics(), children: [_enter(0, 1, empty)])),
      );
    }
    return RefreshIndicator(
      color: DesignColors.primary,
      onRefresh: _ctrl.refreshList,
      child: _column(ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: items.length + moreFooter,
        itemBuilder: (_, i) {
          if (i >= items.length) return _moreFooter();
          final e = items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _enter(
              i,
              _count,
              KeyedSubtree(
                key: _keys.putIfAbsent(e.id, () => GlobalKey()),
                child: _LeadCard(lead: e, highlighted: highlight == e.id, ctrl: _ctrl),
              ),
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
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: DesignColors.primary),
            onPressed: _ctrl.loadMore,
            child: Text(TripStrings.retry, style: TripKit.text(13, weight: FontWeight.w600, color: DesignColors.primary)),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: DesignColors.primary)),
      ),
    );
  }
}

enum _LeadButtonKind { primary, positive, negative, plain }

class _LeadButton extends StatelessWidget {
  const _LeadButton({required this.label, required this.onTap, this.kind = _LeadButtonKind.plain, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final _LeadButtonKind kind;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (JourneyButtonKind k, Color fg) = switch (kind) {
      _LeadButtonKind.primary => (JourneyButtonKind.filled, DesignColors.surface),
      _LeadButtonKind.positive => (JourneyButtonKind.positive, DesignColors.surface),
      _LeadButtonKind.negative => (JourneyButtonKind.dangerOutline, TripLook.error),
      _LeadButtonKind.plain => (JourneyButtonKind.outline, DesignColors.primary),
    };
    return IntrinsicWidth(
      child: JourneyButton(
        label: label,
        kind: k,
        busy: busy,
        onPressed: onTap,
        icon: icon == null ? null : Icon(icon, size: 16, color: fg),
        fontSize: 13,
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.highlighted, required this.ctrl});

  final TripEnquiryModel lead;
  final bool highlighted;
  final TripLeadsController ctrl;

  @override
  Widget build(BuildContext context) {
    final e = lead;
    final spots = TripLeadFormat.spots(e);
    final leg = TripLeadFormat.journeyLine(e) ?? JourneyLegTag.fromLead(e);
    final legText = e.context.text.startsWith('Car ') ? e.context.text.trim() : '';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      padding: EdgeInsets.all(highlighted ? 2 : 0),
      decoration: BoxDecoration(
        borderRadius: TripLook.softRadius,
        color: highlighted ? DesignColors.primary : Colors.transparent,
      ),
      child: TripStatusCard(
        status: e.display,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(TripLeadFormat.guest(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FitnessAppTheme.title.copyWith(fontSize: 15)),
            ),
            if ((e.traveller.id ?? '').isNotEmpty) _menu(context, e),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (e.isUrgent && e.isUnconfirmed) const TripStatusPill(TripDisplayStatus.asked, label: TripStrings.urgent),
            TripStatusPill(e.display, ownerSide: true, taxi: true),
          ]),
          if (leg != null) ...[
            const SizedBox(height: 6),
            Row(children: [Flexible(child: JourneyLegTag(text: leg))]),
          ],
          if (legText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(legText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TripKit.text(12.5, weight: FontWeight.w600).copyWith(height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text(TripLeadFormat.summary(e),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.caption.copyWith(color: DesignColors.textGrey, height: 1.4)),
          if (spots.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(spots,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(height: 1.4)),
          ],
          ..._detail(e),
          ..._actions(context, e),
        ]),
      ),
    );
  }

  Widget _menu(BuildContext context, TripEnquiryModel e) => SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: '',
          icon: const Icon(Icons.more_vert_rounded, size: 20, color: DesignColors.textGrey),
          color: DesignColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (_) => TripReportTravellerSheet.show(context, enquiry: e),
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
                value: 'report',
                height: 44,
                child: Text(TripStrings.reportTraveller, style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: DesignColors.textPrimary))),
          ],
        ),
      );

  List<Widget> _detail(TripEnquiryModel e) {
    final t = e.taxi;
    String? line;
    switch (e.display) {
      case TripDisplayStatus.fareSent:
        if (t?.driverFare != null) {
          final listed = TripLeadFormat.listedTotal(e);
          line = TripStrings.youReplied(
              BrowseItem.inr(t!.driverFare!), listed == null ? '' : BrowseItem.inr(listed), TripLeadFormat.dayCount(e));
        }
      case TripDisplayStatus.bookedByYou:
        if (t?.agreedFare != null) line = TripStrings.saysAgreedFare(BrowseItem.inr(t!.agreedFare!), TripLeadFormat.dates(e));
      default:
    }
    if (line == null) return const [];
    return [
      const SizedBox(height: 8),
      Text(line,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TripKit.text(12.5, weight: FontWeight.w600)),
    ];
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required Color color,
  }) async {
    return showTaxiConfirmDialog(
      context,
      title: title,
      body: body,
      cancelLabel: TripStrings.cancelAction,
      actionLabel: action,
      actionColor: color,
    );
  }

  Future<void> _notAvailable(BuildContext context) async {
    final ok = await _confirm(context,
        title: TripStrings.notAvailableLead,
        body: TripStrings.notAvailableLeadBody,
        action: TripStrings.notAvailableAction,
        color: TripLook.error);
    if (ok) await ctrl.notAvailable(lead.id);
  }

  Future<void> _yes(BuildContext context) async {
    final e = lead;
    final fare = e.taxi?.agreedFare;
    final ok = await _confirm(context,
        title: TripStrings.confirmBookingQ,
        body: TripStrings.confirmBookingBody(
            TripLeadFormat.guest(e), fare == null ? '' : BrowseItem.inr(fare), TripLeadFormat.dates(e)),
        action: TripStrings.yesConfirm,
        color: DesignColors.primaryLight);
    if (ok) await ctrl.confirm(e.id);
  }

  Future<void> _notMe(BuildContext context) async {
    final ok = await _confirm(context,
        title: TripStrings.notYourBooking,
        body: TripStrings.notYourBookingBody(TripLeadFormat.guest(lead)),
        action: TripStrings.notMe,
        color: TripLook.error);
    if (ok) await ctrl.deny(lead.id);
  }

  List<Widget> _actions(BuildContext context, TripEnquiryModel e) {
    final phone = e.traveller.phone;
    final canCall = phone != null && ContactLauncher.tenDigits(phone).isNotEmpty;
    final buttons = <Widget>[];
    Widget btn(String label, _LeadButtonKind kind, VoidCallback? onTap, {IconData? icon}) => Obx(() => _LeadButton(
          label: label,
          kind: kind,
          icon: icon,
          busy: ctrl.busyIds.contains(e.id),
          onTap: onTap,
        ));
    void call(_LeadButtonKind kind) {
      if (canCall) buttons.add(btn(TripStrings.callTraveller, kind, () => ContactLauncher.call(phone), icon: Icons.call_rounded));
    }

    switch (e.display) {
      case TripDisplayStatus.asked:
        call(_LeadButtonKind.primary);
        buttons.add(btn(TripStrings.confirmFare, _LeadButtonKind.positive, () => TripFareSheet.show(context, lead: e)));
        buttons.add(btn(TripStrings.notAvailableAction, _LeadButtonKind.negative, () => _notAvailable(context)));
      case TripDisplayStatus.fareSent:
        call(_LeadButtonKind.primary);
        final left = e.taxi?.fareEditsLeft ?? 0;
        buttons.add(btn(TripStrings.changeFare, _LeadButtonKind.plain,
            left > 0 ? () => TripFareSheet.show(context, lead: e) : () => AppToast.warning(TripStrings.fareLimit)));
        buttons.add(btn(TripStrings.notAvailableAction, _LeadButtonKind.negative, () => _notAvailable(context)));
      case TripDisplayStatus.bookedByYou:
        call(_LeadButtonKind.plain);
        buttons.add(btn(TripStrings.yesConfirm, _LeadButtonKind.positive, () => _yes(context)));
        buttons.add(btn(TripStrings.notMe, _LeadButtonKind.negative, () => _notMe(context)));
      case TripDisplayStatus.confirmedByBoth:
        call(_LeadButtonKind.plain);
        if (!TripLeadBucket.hasEnded(e)) {
          buttons.add(btn(TripStrings.cancelBooking, _LeadButtonKind.negative, () => ctrl.cancel(context, e)));
        }
      default:
    }
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: buttons),
    ];
  }
}
