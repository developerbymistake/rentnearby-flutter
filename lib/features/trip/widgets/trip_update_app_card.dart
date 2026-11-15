import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/app_version_controller.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';

class TripUpdateAppCard extends StatelessWidget {
  const TripUpdateAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(18), DS.s(18), AppInsets.bottomViewPadding(context) + DS.s(14)),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(TripStrings.updateAppTitle, style: Ink3D.text(17, FontWeight.w700, Ink3D.title)),
              Gap.v(2),
              Text(TripStrings.updateAppBody, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
              Gap.v(14),
              GradientPillButton(
                tone: ListingTone.indigo,
                label: TripStringsA4.openPlayStore,
                onTap: () => AppVersionController.to.openStore(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
