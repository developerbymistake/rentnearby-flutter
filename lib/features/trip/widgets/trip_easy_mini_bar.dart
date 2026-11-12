import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/motion_kit.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_easy_rules.dart';

class TripEasyMiniBar extends StatefulWidget {
  const TripEasyMiniBar({super.key});

  @override
  State<TripEasyMiniBar> createState() => _TripEasyMiniBarState();

  static String whatOf(TripEasyRowKind k) => switch (k) {
        TripEasyRowKind.stay => TripStringsV2Easy.stayShort,
        TripEasyRowKind.taxi => TripStringsV2Easy.taxiShort,
        _ => TripStringsV2Easy.waysShort,
      };

  static String lineOf(TripEasyRowInfo r) => TripStringsV2Easy.miniBar(
        whatOf(r.kind),
        r.state == TripRowState.offer ? TripStringsV2Easy.offerWaiting : TripStringsV2Easy.waitingForReply,
      );

}

class _TripEasyMiniBarState extends State<TripEasyMiniBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(duration: const Duration(milliseconds: 1200), vsync: this, value: 1);
  late final Animation<double> _fade =
      Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.fastOutSlowIn));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final row = c.plan.value == null ? null : c.easyInProgress;
      if (row == null) return const SizedBox.shrink();
      return DecoratedBox(
        decoration: TripLook.card(),
        child: InkWell(
          borderRadius: TripLook.softRadius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () => TripNavigation.openRepliesForRow(row.key),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: TripLook.warning, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TripEasyMiniBar.lineOf(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: TripLook.textDark),
                  ),
                ),
                InkWell(
                  onTap: () => TripNavigation.openRepliesForRow(row.key),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: const SizedBox(
                    height: 44,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(TripStringsV2Easy.view,
                              style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: FitnessAppTheme.nearlyDarkBlue)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16, color: FitnessAppTheme.nearlyDarkBlue),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
