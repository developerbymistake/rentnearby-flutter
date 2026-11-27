import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/plan_controller.dart';
import '../../../../design/design.dart';
import '../../../stay/setup/stay_setup_controller.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import 'quote_line_card.dart';
import 'quote_usage_line.dart';

// Home entry (mock Q1): only for an approved stay, count from /plans/me (no hub call).
class QuoteHomeCard extends StatelessWidget {
  const QuoteHomeCard({super.key, this.approved});

  final bool Function()? approved;

  static final RxInt _tick = 0.obs;

  static bool _approved() =>
      Get.isRegistered<StaySetupController>() && Get.find<StaySetupController>().stay.value?.isApproved == true;

  static void openList() => Get.toNamed(AppRoutes.stayQuotations);

  static void newQuotation() => Get.toNamed(AppRoutes.stayQuotationEdit, arguments: const {'new': true});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<StaySetupController>() && approved == null) return const SizedBox.shrink();
    return Obx(() {
      _tick.value;
      if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
      if (Get.isRegistered<StaySetupController>()) Get.find<StaySetupController>().stay.value;
      if (!(approved ?? _approved)()) return const SizedBox.shrink();
      final view = QuoteUsageSource.view();
      return Container(
        margin: DS.insets(l: 18, t: 22, r: 18),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DS.br(CardRadius.hero),
            onTap: openList,
            child: Padding(
              padding: DS.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      width: DS.s(52),
                      height: DS.s(52),
                      decoration: BoxDecoration(color: StayLook.greenSoft, borderRadius: DS.circular(14)),
                      child: Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.memo, size: 40))),
                    ),
                    Gap.h(12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(StayQuoteStrings.title, style: QuoteText.head),
                        Text(StayQuoteStrings.homeSub, style: QuoteText.small),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: DS.s(24), color: Ink3D.hint),
                  ]),
                  Gap.v(12),
                  Divider(height: DS.s(1), thickness: DS.s(1), color: StayLook.rowLine),
                  Gap.v(4),
                  Row(children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${StayQuoteStrings.thisMonth} '),
                          TextSpan(text: view.countLine, style: QuoteText.label),
                        ]),
                        style: QuoteText.small.copyWith(color: Ink3D.sub),
                      ),
                    ),
                    StayPill(label: StayQuoteStrings.newQuotation, kind: StayPillKind.forest, onTap: newQuotation),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
