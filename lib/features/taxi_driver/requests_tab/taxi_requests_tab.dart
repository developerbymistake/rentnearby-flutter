import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../config/tab_slot.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../../widgets/tab_header.dart';
import '../../taxi/requests/controllers/driver_requests_controller.dart';
import '../../taxi/requests/widgets/driver_requests_body.dart';
import '../home/taxi_driver_home_controller.dart';
import '../strings/taxi_work_strings.dart';

class TaxiRequestsTab extends StatefulWidget {
  const TaxiRequestsTab({super.key, this.requests});

  final DriverRequestsController? requests;

  static void openOffer(String offerId) => Get.toNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': offerId});

  @override
  State<TaxiRequestsTab> createState() => _TaxiRequestsTabState();
}

class _TaxiRequestsTabState extends State<TaxiRequestsTab> {
  late final DriverRequestsController _requests = widget.requests ?? DriverRequestsController.to;
  Worker? _intentWorker;
  Worker? _countWorker;

  AuthController? get _auth => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  @override
  void initState() {
    super.initState();
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
    _countWorker?.dispose();
    super.dispose();
  }

  void _syncBadge() {
    final home = TaxiDriverHomeController.maybe;
    if (home == null || !_requests.loaded.value) return;
    home.centreBadge.value = _requests.badge;
  }

  void _apply(TabIntent? intent) {
    final offerId = intent?.args['offerId']?.toString();
    if (offerId != null && offerId.isNotEmpty) TaxiRequestsTab.openOffer(offerId);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = BarMetrics.bodyBottomOf(context);
    final page = ListingPalette.coral.page;
    return Scaffold(
      backgroundColor: page,
      body: TabHeaderFrame(
        title: TaxiWorkStrings.requests,
        subtitle: TaxiWorkStrings.today,
        color: page,
        child: Column(
          children: [
            const NotificationOffBanner(body: NotificationOffBanner.requestsBody),
            Expanded(
              child: DriverRequestsBody(
                controller: _requests,
                onOpenOffer: TaxiRequestsTab.openOffer,
                onOpenReady: () => Get.toNamed(AppRoutes.taxiReady),
                bottomPadding: bottom + 12,
                tabIndex: AppTabs.centre,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
