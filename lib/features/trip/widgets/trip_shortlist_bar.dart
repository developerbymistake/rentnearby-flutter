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
import 'trip_list_look.dart';
import 'trip_sheet_frame.dart';

class TripShortlistBar extends StatelessWidget {
  const TripShortlistBar({
    super.key,
    required this.step,
    required this.onDone,
    this.tone = KitTone.stay,
    this.maxWidth = 640,
  });

  final String step;
  final VoidCallback onDone;
  final KitTone tone;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = TripShortlistController.to;
    return Obx(() {
      final n = c.countOf(step);
      final hint = n >= c.max
          ? TripStringsShortlist.full
          : (n == 0 && c.doneHint.contains(step) ? TripStringsShortlist.pickFirst : null);
      final roomy = MediaQuery.textScalerOf(context).scale(14) <= 18.5;
      final note = hint ?? (!roomy ? '' : (tone == KitTone.taxi ? TripStringsShortlist.pickDrivers(c.max) : TripStringsShortlist.tapDone));
      final sending = c.isSending(step);
      return DockBar(
        tone: tripListTone(tone),
        title: TripStringsShortlist.barCount(n, c.max),
        subtitle: note,
        subtitleKey: hint == null ? null : const ValueKey('shortlist-bar-note'),
        actionLabel: TripStringsShortlist.done,
        onAction: sending ? null : onDone,
        loading: sending,
        maxWidth: maxWidth,
      );
    });
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
      c.doneHint.add(step);
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
    final yes = await TripShortlistReview.show(context, taxi: taxi, count: n, names: [for (final i in c.activeOf(step)) i.name]);
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
    if (batch == null) return;
    if (Get.isRegistered<TripPlanController>()) TripPlanController.to.guideRecordSend(step, batch, taxi: taxi);
    if (!context.mounted) return;
    await TripSendResultSheet.show(
      context,
      batch: batch,
      names: names,
      taxi: taxi,
      shortlist: true,
    );
  }
}

class TripShortlistReview {
  static Future<bool> show(
    BuildContext context, {
    required bool taxi,
    required int count,
    List<String> names = const [],
  }) async {
    final yes = await TripSheetFrame.show<bool>(
      context,
      _ReviewBody(taxi: taxi, count: count, names: names),
    );
    return yes == true;
  }
}

// One row reserved per pick, so the taxi and stay sheets keep the same height.
class _ReviewChips extends StatelessWidget {
  const _ReviewChips({required this.tone, required this.art, required this.labels});

  final ListingTone tone;
  final String art;
  final List<String> labels;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final style = Ink3D.text(14, FontWeight.w700, tone.text);
    final textH = KitText.heightOf('Ag', style, MediaQuery.textScalerOf(context), 400, 1);
    final rowH = (textH > 28 ? textH : 28) + 10;
    final reserve = labels.length * rowH + (labels.length - 1) * _gap;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: reserve, minWidth: double.infinity),
        child: Center(
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            alignment: WrapAlignment.center,
            children: [
              for (final l in labels)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
                  decoration: BoxDecoration(color: tone.tint, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(art, width: 28, height: 28, fit: BoxFit.contain),
                      const SizedBox(width: 6),
                      Flexible(child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.taxi, required this.count, this.names = const []});

  final bool taxi;
  final int count;
  final List<String> names;

  static String _label(String name, bool taxi) {
    final t = name.trim();
    final i = t.indexOf(' ');
    return taxi && i > 0 ? t.substring(0, i) : t;
  }

  @override
  Widget build(BuildContext context) {
    final art = taxi ? ListingArt.taxi : ListingArt.hotel;
    final tone = taxi ? ListingTone.coral : ListingTone.forest;
    final labels = [for (final n in names) if (n.trim().isNotEmpty) _label(n, taxi)];
    return SheetModalBody(
      tone: tone,
      art: art,
      title: TripStringsShortlist.reviewTitle,
      body: TripStringsShortlist.reviewBody(count, taxi: taxi),
      extra: labels.isEmpty ? null : _ReviewChips(tone: tone, art: art, labels: labels),
      primaryLabel: TripStringsShortlist.sendAll,
      onPrimary: () => Navigator.pop(context, true),
      linkLabel: TripStringsShortlist.notNow,
      onLink: () => Navigator.pop(context, false),
    );
  }
}
