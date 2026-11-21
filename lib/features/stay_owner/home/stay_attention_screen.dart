import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../stay/setup/stay_page_header.dart';
import '../../stay/setup/stay_setup_controller.dart';
import '../strings/stay_home_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_home_compose.dart';
import 'stay_owner_home_controller.dart';
import 'stay_owner_home_screen.dart';

class StayAttentionScreen extends StatelessWidget {
  const StayAttentionScreen({super.key, this.controller});

  final StayOwnerHomeController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? StayOwnerHomeController.maybe;
    return Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: Column(
        children: [
          StayPageHeader(title: StayHomeStrings.attentionPageTitle, onBack: () => Get.back(), asset: ListingArt.bell),
          Expanded(
            child: c == null
                ? const SizedBox.shrink()
                : Obx(() {
                    final dto = c.data;
                    if (dto == null) return const SizedBox.shrink();
                    final hub = Get.isRegistered<StaySetupController>() ? Get.find<StaySetupController>().stay.value : null;
                    final state = StayHomeCompose.stateOf(dto.listing);
                    final rows = StayHomeCompose.attention(dto, denied: c.notificationsDenied.value, hasShareDetails: hub?.hasShareDetails ?? false);
                    final views = StayHomeCompose.rowViews(rows, StayHomeActions.attention(context, dto.listing.id, dto.listing.name), StayHomeCompose.variant(state));
                    return RefreshIndicator(
                      onRefresh: c.reload,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.only(bottom: DS.s(24) + MediaQuery.viewPaddingOf(context).bottom),
                        itemCount: views.length,
                        itemBuilder: (_, i) => StayRowsCard(rows: [views[i]]),
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}
