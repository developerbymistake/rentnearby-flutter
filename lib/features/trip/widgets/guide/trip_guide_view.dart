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
import '../../utils/trip_format.dart';
import '../../utils/trip_guide_rules.dart';
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
  final _sentNames = <String, List<String>>{};
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

  ListingTone _tone(TripGuideStep s) => s.isStay
      ? ListingTone.forest
      : s.row.kind == TripEasyRowKind.gettingThere
          ? ListingTone.indigo
          : ListingTone.coral;

  String _asset(TripGuideStep s) => switch (s.row.kind) {
        TripEasyRowKind.stay => ListingArt.hotel,
        TripEasyRowKind.between => ListingArt.bus,
        TripEasyRowKind.comingBack => ListingArt.airplane,
        _ => ListingArt.taxi,
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
    final names = [for (final i in _sl.activeOf(step.key)) i.name];
    if (names.isNotEmpty) _sentNames[step.key] = names;
    await _c.guideSendAll(step.key, context: context);
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

  TripGuideFrame _cardFor(TripGuideStep step) {
    final key = step.key;
    final k = _kind(step);
    final asset = _asset(step);
    final tone = _tone(step);
    if (k.sent) {
      return TripGuideFrame(
        title: TripStringsGuide.sentTitle,
        body: TripStringsGuide.sentBody(_g.sent[key] ?? 0, taxi: !step.isStay),
        asset: ListingArt.speechBalloon,
        tone: tone,
        child: TripGuideSentRows(names: _sentNames[key] ?? _sl.namesOf(key).values.toList(), art: asset),
      );
    }
    switch (k.card) {
      case TripGuideCard.review:
        final note = _g.notes[key];
        return TripGuideFrame(
          title: TripStringsGuide.reviewTitle,
          body: TripStringsGuide.reviewBody(step.isStay),
          asset: asset,
          tone: tone,
          child: TripGuideShortlistReview(
            asset: asset,
            tone: tone,
            names: k.names,
            stays: step.isStay,
            step: key,
            hidePillNote: note != null,
            note: note,
            sending: _g.sending.contains(key),
            failed: _g.failed[key] ?? (note == null ? 0 : 1),
            onSend: () => _send(step),
            onChange: _isCar(step) ? () => _c.guideFind(context, key) : null,
            onNotNow: () => _c.guideNotNow(key),
          ),
        );
      case TripGuideCard.nudge:
        final name = _g.nudgeName.value.isNotEmpty ? _g.nudgeName.value : (k.names.isEmpty ? '' : k.names.first);
        return TripGuideFrame(
          title: TripGuideNudge.titleFor(name),
          body: TripStringsGuide.nudgeBody,
          asset: asset,
          tone: tone,
          child: Obx(() => TripGuideNudge(
                asset: asset,
                tone: tone,
                name: name,
                busy: _busy.value,
                onBooked: () => _booked(key),
                onNew: () => _newOptions(key),
              )),
        );
      case TripGuideCard.reopened:
        return TripGuideFrame(
          title: TripStringsGuide.reopenTitle,
          body: TripStringsGuide.reopenBody,
          asset: asset,
          tone: tone,
          child: Obx(() => TripGuideReopened(
                asset: asset,
                tone: tone,
                busy: _busy.value,
                onBooked: () => _booked(key),
                onNew: () => _newOptions(key),
              )),
        );
      case TripGuideCard.finish:
      case TripGuideCard.question:
        return TripGuideFrame(
          title: step.title,
          body: step.body,
          asset: asset,
          tone: tone,
          child: TripGuideOptions(
            choice: _g.current.value,
            skipNote: step.row.kind == TripEasyRowKind.taxi,
            onPick: (c) => _c.guideChoose(context, key, c),
          ),
        );
    }
  }

  Widget _progress(ListingTone tone) => Obx(() {
        final idx = _g.index.value;
        final total = _g.total.value;
        final name = idx >= total ? TripStringsGuide.finishName : _g.steps[idx].name;
        final pendingNames = [for (final st in _g.steps) if (_g.pending.contains(st.key)) st.name];
        return TripGuideProgress(percent: _g.percent.value, name: name, index: idx, total: total, tone: tone, pendingNames: pendingNames);
      });

  Widget _bar(ListingTone tone) => Obx(() {
        final idx = _g.index.value;
        final total = _g.total.value;
        var canNext = false;
        String? label = TripStringsGuide.next;
        VoidCallback? action;
        var loading = false;
        var why = '';
        if (total > 0 && idx >= total) {
          label = null;
        } else if (total > 0) {
          final step = _g.steps[idx];
          final key = step.key;
          final k = _kind(step);
          final choice = _g.current.value;
          canNext = TripGuideRules.canAdvance(k.card, answered: _g.answered.contains(key));
          if (k.sent) {
            if (idx + 1 < total) why = TripStringsGuide.nextStep(_g.steps[idx + 1].name);
            action = () {
              _c.guideDismissSent(key);
              _c.guideNext();
            };
          } else if (k.card == TripGuideCard.review) {
            label = null;
          } else if (choice == TripGuideChoice.find && !canNext && k.card == TripGuideCard.question) {
            label = step.isStay
                ? TripStringsGuide.findStays
                : step.isTaxi
                    ? TripStringsGuide.findATaxi
                    : TripStringsGuide.findTaxis;
            action = () => _c.guideFind(context, key);
            why = TripStringsGuide.guideWhyPick;
          } else if (canNext) {
            action = _c.guideNext;
          }
          if (k.card == TripGuideCard.nudge || k.card == TripGuideCard.reopened) label = null;
          if (!k.sent && k.card == TripGuideCard.question && choice == null && action == null) why = TripStringsGuide.guideWhyChoose;
          if (!k.sent && k.card == TripGuideCard.question && choice == TripGuideChoice.skip && step.row.kind == TripEasyRowKind.taxi) {
            why = TripStringsGuide.noTaxiNote;
          }
        }
        return TripGuideBar(
          canNext: canNext,
          primaryLabel: label,
          onPrimary: action,
          loading: loading,
          onPrevious: _c.guidePrevious,
          why: why,
          tone: tone,
        );
      });

  Widget _finish(int total) {
    final rows = _c.easyRows;
    final arranged = rows.isNotEmpty && TripEasyRules.allResolved(rows);
    final start = _c.plan.value?.settings.startDate;
    final days = _c.plan.value?.days.length ?? 0;
    final dates = [
      if (start != null) TripFormat.dayMonth(start),
      if (days > 0) TripStringsGuide.days(days),
    ].join(' · ');
    return TripGuideFinish(
      key: const ValueKey('finish'),
      arranged: arranged,
      pendingNames: [for (final st in _g.steps) if (_g.pending.contains(st.key)) st.name],
      percent: TripEasyRules.progress(rows).percent,
      title: _c.title,
      subtitle: dates,
      stepText: '$total of $total',
      onBack: _c.guidePrevious,
      onSummary: () {
        final tripId = _c.trip.value?.id;
        if (tripId != null) TripNavigation.openSummary(tripId);
      },
    );
  }

  Widget _sheet() {
    return Obx(() {
      final idx = _g.index.value;
      final total = _g.total.value;
      if (total == 0) return const SizedBox.shrink();
      if (idx >= total) return _finish(total);
      final step = _g.steps[idx];
      final frame = _cardFor(step);
      final kind = _kind(step);
      final id = '${step.key}-${frame.child.runtimeType}';
      final tone = frame.tone ?? ListingTone.indigo;
      final reduce = KitMotion.reduce(context);
      final sheetKey = ValueKey(step.key);
      final header = _progress(tone);
      final noBar = !kind.sent && (kind.card == TripGuideCard.review || kind.card == TripGuideCard.nudge || kind.card == TripGuideCard.reopened);
      final bottom = noBar ? null : _bar(tone);
      final content = AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(id), child: frame),
      );
      return Obx(() {
        final p = _g.percent.value.clamp(0, 100);
        return GuideSheetScaffold(
          key: sheetKey,
          tone: tone,
          art: _asset(step),
          title: frame.title,
          body: frame.body,
          progress: p / 100,
          ringLabel: '$p%',
          scrollKey: '$id-${kind.card.name}-${kind.sent}',
          centerText: !kind.sent && kind.card == TripGuideCard.review,
          header: header,
          bottom: bottom,
          children: [content],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // The plan Scaffold strips the inset from its body because it always has a bottom bar slot.
    final bottom = mq.viewPadding.bottom > 0 ? mq.viewPadding.bottom : MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    return MediaQuery(
      data: mq.copyWith(padding: EdgeInsets.only(bottom: bottom)),
      child: _sheet(),
    );
  }
}

class TripGuideCardKind {
  const TripGuideCardKind(this.card, {this.sent = false, this.names = const []});

  final TripGuideCard card;
  final bool sent;
  final List<String> names;
}
