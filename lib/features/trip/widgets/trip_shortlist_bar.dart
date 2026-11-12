import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_plan_guide.dart';
import '../controllers/trip_shortlist_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_navigation.dart';
import '../trip_strings_shortlist.dart';
import 'trip_send_result_sheet.dart';
import 'trip_sheet_frame.dart';

class TripShortlistBar extends StatelessWidget {
  const TripShortlistBar({super.key, required this.step, required this.onDone, this.tone = KitTone.stay, this.maxWidth = 640});

  final String step;
  final VoidCallback onDone;
  final KitTone tone;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = TripShortlistController.to;
    return DecoratedBox(
      decoration: const BoxDecoration(color: DesignColors.surface, boxShadow: ShadowTokens.elev2),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Obx(() {
                final n = c.countOf(step);
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        TripStringsShortlist.barCount(n, c.max),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 112),
                      child: PrimaryButton(
                        label: TripStringsShortlist.done,
                        loading: c.isSending(step),
                        onPressed: c.isSending(step) ? null : onDone,
                        tone: tone,
                        expand: false,
                        height: 48,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class TripShortlistFlow {
  static Future<void> done(
    BuildContext context, {
    required String step,
    required bool taxi,
    required Future<TripEnquiryBatch?> Function() send,
  }) async {
    final c = TripShortlistController.to;
    final n = c.countOf(step);
    if (n == 0) {
      TripNavigation.backToPlan();
      return;
    }
    if (!c.beginSend(step)) return;
    try {
      await _run(context, c, step: step, taxi: taxi, n: n, send: send);
    } finally {
      c.endSend(step);
    }
  }

  static Future<void> _run(
    BuildContext context,
    TripShortlistController c, {
    required String step,
    required bool taxi,
    required int n,
    required Future<TripEnquiryBatch?> Function() send,
  }) async {
    final yes = await TripShortlistReview.show(context, taxi: taxi, count: n);
    if (!yes) {
      TripNavigation.backToPlan();
      if (Get.isRegistered<TripPlanController>()) {
        final plan = TripPlanController.to;
        if (plan.guideState.keyNow == step) {
          plan.guideDismissSent(step);
          plan.guideNext();
        }
      }
      return;
    }
    final names = c.namesOf(step);
    final batch = await send();
    if (batch == null || !context.mounted) return;
    await TripSendResultSheet.show(context, batch: batch, names: names, taxi: taxi, shortlist: true);
  }
}

class TripShortlistReview {
  static Future<bool> show(BuildContext context, {required bool taxi, required int count}) async {
    final yes = await TripSheetFrame.show<bool>(context, _ReviewBody(taxi: taxi, count: count));
    return yes == true;
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.taxi, required this.count});

  final bool taxi;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tone = taxi ? KitTone.taxi : KitTone.stay;
    return TripSheetFrame(
      title: TripStringsShortlist.reviewTitle,
      description: TripStringsShortlist.reviewBody(count, taxi: taxi),
      children: [
        PrimaryButton(label: TripStringsShortlist.yesSendAll, onPressed: () => Navigator.pop(context, true), tone: tone),
        const SizedBox(height: 8),
        Center(
          child: TextLink(label: TripStringsShortlist.notNow, onTap: () => Navigator.pop(context, false), tone: KitTone.trip),
        ),
      ],
    );
  }
}
