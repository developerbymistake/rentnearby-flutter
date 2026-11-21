import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../strings/taxi_home_strings.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_driver_home_controller.dart';
import 'taxi_driver_home_screen.dart';
import 'taxi_home_compose.dart';

class TaxiAttentionScreen extends StatelessWidget {
  const TaxiAttentionScreen({super.key, this.controller});

  final TaxiDriverHomeController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? TaxiDriverHomeController.maybe;
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Column(
        children: [
          Obx(() {
            final dto = c?.data;
            final denied = c?.notificationsDenied.value ?? false;
            final total = dto == null ? 0 : TaxiHomeCompose.attentionCount(dto, TaxiHomeCompose.attention(dto, denied: denied), denied: denied);
            return TaxiPageHeader(title: TaxiHomeStrings.attentionPageTitle, subtitle: dto == null ? null : TaxiHomeStrings.attentionPageSub(total), onBack: () => Get.back());
          }),
          Expanded(
            child: c == null
                ? const SizedBox.shrink()
                : Obx(() {
                    final dto = c.data;
                    if (dto == null) return const SizedBox.shrink();
                    final rows = TaxiHomeCompose.attention(dto, denied: c.notificationsDenied.value);
                    final views = TaxiHomeCompose.rowViews(rows, TaxiHomeActions.attention(dto.listing.id), c.now.value, compact: false);
                    return RefreshIndicator(
                      onRefresh: c.reload,
                      child: ListView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.only(bottom: DS.s(24) + MediaQuery.viewPaddingOf(context).bottom),
                        children: [TaxiRowsCard(rows: views)],
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}
