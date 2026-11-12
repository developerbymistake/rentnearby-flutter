import 'dart:async';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/trip_plan_controller.dart';
import '../../controllers/trip_plan_guide.dart';
import '../../controllers/trip_shortlist_controller.dart';
import '../../models/trip_plan_model.dart';
import '../../trip_navigation.dart';
import '../../trip_strings_guide.dart';
import '../../utils/trip_easy_rules.dart';
import '../../utils/trip_guide_rules.dart';
import '../trip_ui.dart';
import 'trip_guide_bar.dart';
import 'trip_guide_card.dart';
import 'trip_guide_finish.dart';
import 'trip_guide_nudge.dart';
import 'trip_guide_options.dart';
import 'trip_guide_progress.dart';
import 'trip_guide_reopened.dart';
import 'trip_guide_shortlist_review.dart';

class TripGuideView extends StatefulWidget {
  const TripGuideView({super.key, this.controller, this.shortlist});

  final TripPlanController? controller;
  final TripShortlistController? shortlist;

  @override
  State<TripGuideView> createState() => _TripGuideViewState();
}

class _TripGuideViewState extends State<TripGuideView> {
  late final TripPlanController _c = widget.controller ?? TripPlanController.to;
  late final TripShortlistController _sl = widget.shortlist ?? TripShortlistController.to;
  final _busy = false.obs;
  Worker? _planWorker;
  Worker? _listWorker;

  TripGuideState get _g => _c.guideState;

  @override
  void initState() {
    super.initState();
    _c.guideRefresh();
    _planWorker = ever<TripPlan?>(_c.plan, (_) => _c.guideSync());
    _listWorker = ever(_sl.items, (_) => _c.guideSync());
    unawaited(_sl.load());
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _listWorker?.dispose();
    super.dispose();
  }

  String _asset(TripGuideStep s) => switch (s.row.kind) {
        TripEasyRowKind.stay => TravelIcon.stay,
        TripEasyRowKind.taxi => TravelIcon.route,
        _ => TravelIcon.taxi,
      };

  TripGuideCardKind _kind(TripGuideStep step) {
    final key = step.key;
    final active = _sl.activeOf(key);
    final noReply = active.isEmpty && _sl.noReplyIds(key).isNotEmpty;
    var rowOpen = false;
    if (noReply) {
      final info = _c.easyRowOf(step.row);
      rowOpen = info?.isDone != true && _c.openRowsOf(step.row).isEmpty;
    }
    final sent = (_g.sent[key] ?? 0) > 0 && active.isEmpty;
    final card = TripGuideRules.cardKind(
      finish: false,
      nudge: _g.nudgeStep.value == key,
      reopen: _g.reopenStep.value == key,
      choice: _g.current.value,
      shortlisted: active.length,
      noReply: noReply,
      rowOpen: rowOpen,
    );
    return TripGuideCardKind(card, sent: sent && card == TripGuideCard.question, names: [for (final i in active) i.name]);
  }

  bool _isCar(TripGuideStep s) => s.row.kind != TripEasyRowKind.stay && s.row.kind != TripEasyRowKind.taxi;

  Future<void> _send(TripGuideStep step) async {
    await _c.guideSendAll(step.key);
  }

  Future<void> _booked(String key) async {
    _busy.value = true;
    try {
      await _c.guideMarkBooked(key);
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _newOptions(String key) async {
    _busy.value = true;
    try {
      await _c.guideNewOptions(context, key);
    } finally {
      _busy.value = false;
    }
  }

  Widget _cardFor(TripGuideStep step) {
    final key = step.key;
    final k = _kind(step);
    final asset = _asset(step);
    if (k.sent) {
      return TripGuideFrame(
        title: TripStringsGuide.sentTitle,
        body: TripStringsGuide.sentBody(_g.sent[key] ?? 0, taxi: step.isTaxi),
        asset: asset,
        child: TripButton(
          label: TripStringsGuide.next,
          onPressed: () {
            _c.guideDismissSent(key);
            _c.guideNext();
          },
        ),
      );
    }
    switch (k.card) {
      case TripGuideCard.review:
        void notNow() {
          _c.guideDismissSent(key);
          _c.guideNext();
        }

        if (_isCar(step)) {
          return _CarReview(asset: asset, names: k.names, onChoose: () => _c.guideFind(context, key), onNotNow: notNow);
        }
        final note = _g.notes[key];
        final review = TripGuideShortlistReview(
          asset: asset,
          names: k.names,
          stays: step.isStay,
          step: key,
          hidePillNote: note != null,
          sending: _g.sending.contains(key),
          failed: _g.failed[key] ?? (note == null ? 0 : 1),
          onSend: () => _send(step),
          onNotNow: notNow,
        );
        if (note == null) return review;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            review,
            const SizedBox(height: 10),
            Text(note,
                key: const ValueKey('guide-send-note'),
                textAlign: TextAlign.center,
                style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.warning)),
          ],
        );
      case TripGuideCard.nudge:
        final name = _g.nudgeName.value.isNotEmpty ? _g.nudgeName.value : (k.names.isEmpty ? '' : k.names.first);
        return Obx(() => TripGuideNudge(
              asset: asset,
              name: name,
              busy: _busy.value,
              onBooked: () => _booked(key),
              onNew: () => _newOptions(key),
            ));
      case TripGuideCard.reopened:
        return Obx(() => TripGuideReopened(
              asset: asset,
              busy: _busy.value,
              onBooked: () => _booked(key),
              onNew: () => _newOptions(key),
            ));
      case TripGuideCard.finish:
      case TripGuideCard.question:
        return TripGuideFrame(
          title: step.title,
          body: step.body,
          asset: asset,
          child: TripGuideOptions(
            choice: _g.current.value,
            skipNote: step.row.kind == TripEasyRowKind.taxi,
            onPick: (c) => _c.guideChoose(context, key, c),
          ),
        );
    }
  }

  Widget _card() {
    return Obx(() {
      final idx = _g.index.value;
      final total = _g.total.value;
      if (total == 0) return const SizedBox.shrink();
      final Widget child;
      final String id;
      if (idx >= total) {
        id = 'finish';
        final rows = _c.easyRows;
        child = TripGuideFinish(
          arranged: rows.isNotEmpty && TripEasyRules.allResolved(rows),
          onSummary: () {
            final tripId = _c.trip.value?.id;
            if (tripId != null) TripNavigation.openSummary(tripId);
          },
          onOverview: () => _c.guideSetOverview(true),
        );
      } else {
        final step = _g.steps[idx];
        child = _cardFor(step);
        id = '${step.key}-${child.runtimeType}';
      }
      final reduce = KitMotion.reduce(context);
      return AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(id), child: child),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 0),
          child: Obx(() {
            final idx = _g.index.value;
            final total = _g.total.value;
            final name = idx >= total ? TripStringsGuide.finishName : _g.steps[idx].name;
            return TripGuideProgress(percent: _g.percent.value, name: name, index: idx, total: total);
          }),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: _card()),
                ),
              ),
            ),
          ),
        ),
        Obx(() {
          final idx = _g.index.value;
          final total = _g.total.value;
          var canNext = false;
          if (total > 0 && idx < total) {
            final k = _kind(_g.steps[idx]);
            canNext = !k.sent && TripGuideRules.canNext(k.card, _g.current.value);
          }
          return TripGuideBar(
            canNext: canNext,
            onPrevious: _c.guidePrevious,
            onNext: _c.guideNext,
            onOverview: () => _c.guideSetOverview(true),
          );
        }),
      ],
    );
  }
}

class _CarReview extends StatelessWidget {
  const _CarReview({required this.asset, required this.names, required this.onChoose, required this.onNotNow});

  final String asset;
  final List<String> names;
  final VoidCallback onChoose;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: TripStringsGuide.reviewTitle,
        body: TripStringsGuide.carReviewBody,
        asset: asset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(TripStringsGuide.shortlisted(names.length), textAlign: TextAlign.center, style: TypeTokens.caption),
            const SizedBox(height: 16),
            TripButton(label: TripStringsGuide.chooseAndSend, onPressed: onChoose),
            const SizedBox(height: 10),
            TripButton(label: TripStringsGuide.notNow, outlined: true, onPressed: onNotNow),
          ],
        ),
      );
}

class TripGuideCardKind {
  const TripGuideCardKind(this.card, {this.sent = false, this.names = const []});

  final TripGuideCard card;
  final bool sent;
  final List<String> names;
}
