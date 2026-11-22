import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../config/tab_slot.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../../widgets/tab_header.dart';
import '../../taxi/leads/trip_leads_controller.dart';
import '../../taxi/leads/trip_leads_screen.dart';
import '../../taxi/requests/controllers/driver_requests_controller.dart';
import '../../taxi/requests/widgets/driver_requests_body.dart';
import '../home/taxi_driver_home_controller.dart';
import '../strings/taxi_work_strings.dart';
import '../taxi_driver_tabs.dart';
import 'taxi_requests_segments.dart';

class TaxiRequestsTab extends StatefulWidget {
  const TaxiRequestsTab({super.key, this.requests, this.leadsBody, this.initialSegment = 0});

  final DriverRequestsController? requests;
  final Widget? leadsBody;
  final int initialSegment;

  static void openOffer(String offerId) => Get.toNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': offerId});

  @override
  State<TaxiRequestsTab> createState() => _TaxiRequestsTabState();
}

class _TaxiRequestsTabState extends State<TaxiRequestsTab> {
  late int _segment = widget.initialSegment;
  late final DriverRequestsController _requests = widget.requests ?? DriverRequestsController.to;
  TripLeadsController? _leads;
  Worker? _intentWorker;
  Worker? _leadsWorker;
  Worker? _countWorker;
  String? _leadFocus;

  AuthController? get _auth => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  @override
  void initState() {
    super.initState();
    if (widget.leadsBody == null) {
      final leads = TripLeadsController.ensure();
      _leads = leads;
      leads.loadBadge();
      _leadsWorker = ever<int>(leads.newCount, (_) => _syncBadge());
    }
    _countWorker = ever(_requests.counts, (_) => _syncBadge());
    final auth = _auth;
    if (auth != null) {
      _intentWorker = ever<TabIntent?>(auth.tabIntent, (i) {
        if (i != null && i.index == AppTabs.centre && mounted) _apply(auth.takeIntent(AppTabs.centre));
      });
      _apply(auth.takeIntent(AppTabs.centre));
    }
  }

  @override
  void dispose() {
    _intentWorker?.dispose();
    _leadsWorker?.dispose();
    _countWorker?.dispose();
    super.dispose();
  }

  void _syncBadge() {
    final home = TaxiDriverHomeController.maybe;
    if (home == null || !_requests.loaded.value) return;
    home.centreBadge.value = _requests.badge + (_leads?.newCount.value ?? 0);
  }

  void _apply(TabIntent? intent) {
    if (intent == null) return;
    final route = intent.args['route']?.toString() ?? '';
    final leads = TaxiDriverTabs.segmentFor(route) == 'leads' || intent.args['segment'] == 'leads';
    final enquiryId = intent.args[TripLeadsScreen.focusKey]?.toString();
    final offerId = intent.args['offerId']?.toString();
    setState(() {
      _segment = leads ? 1 : 0;
      if (leads && enquiryId != null && enquiryId.isNotEmpty) _leadFocus = enquiryId;
    });
    final l = _leads;
    if (leads && l != null && enquiryId != null && enquiryId.isNotEmpty) l.focus(enquiryId);
    if (!leads && offerId != null && offerId.isNotEmpty) TaxiRequestsTab.openOffer(offerId);
  }

  void _select(int i) {
    if (i == _segment) return;
    setState(() => _segment = i);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = BarMetrics.bodyBottomOf(context);
    final page = ListingPalette.coral.page;
    return Scaffold(
      backgroundColor: page,
      body: TabHeaderFrame(
        title: TaxiWorkStrings.requests,
        subtitle: _segment == 0 ? TaxiWorkStrings.today : TaxiWorkStrings.tripLeads,
        color: page,
        child: Column(
          children: [
            const NotificationOffBanner(body: NotificationOffBanner.requestsBody),
            Padding(
              padding: DS.insets(l: 18, t: 4, r: 18),
              child: _leads == null
                  ? TaxiRequestsSegments(selected: _segment, leadsBadge: 0, onSelect: _select)
                  : Obx(() => TaxiRequestsSegments(selected: _segment, leadsBadge: _leads!.newCount.value, onSelect: _select)),
            ),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: [
                  DriverRequestsBody(
                    controller: _requests,
                    onOpenOffer: TaxiRequestsTab.openOffer,
                    onOpenReady: () => Get.toNamed(AppRoutes.taxiReady),
                    bottomPadding: bottom + 12,
                    tabIndex: AppTabs.centre,
                  ),
                  widget.leadsBody ?? TripLeadsScreen(embedded: true, enquiryId: _leadFocus, bottomPadding: bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
