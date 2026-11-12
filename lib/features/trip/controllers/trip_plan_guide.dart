import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../../taxi/ways/models/ask_models.dart';
import '../../taxi/ways/models/taxi_ways_models.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_guide_args.dart';
import '../models/trip_plan_model.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_guide.dart';
import '../trip_strings_shortlist.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_guide_rules.dart';
import '../widgets/trip_arrange_confirm.dart';
import 'trip_enquiry_controller.dart';
import 'trip_plan_controller.dart';
import 'trip_shortlist_controller.dart';

class TripGuideState {
  static const String finishKey = 'finish';

  final steps = <TripGuideStep>[];
  final choices = <String, TripGuideChoice>{};
  String step = '';
  String? _hydratedFor;
  bool _hydrated = false;

  final on = false.obs;
  final index = 0.obs;
  final total = 0.obs;
  final percent = 0.obs;
  final current = Rxn<TripGuideChoice>();
  final nudgeStep = RxnString();
  final nudgeName = ''.obs;
  final reopenStep = RxnString();
  final sent = <String, int>{}.obs;
  final failed = <String, int>{}.obs;
  final notes = <String, String>{}.obs;
  final sending = <String>{}.obs;
  final answered = <String>{}.obs;
  final notNow = <String>{};
  final sentOk = <String>{};
  Future<bool> Function(BuildContext context, TripEasyRowKey row, GuideArgs guide)? opener;

  bool get atFinish => total.value > 0 && index.value >= total.value;

  TripGuideStep? get stepNow => index.value >= 0 && index.value < steps.length ? steps[index.value] : null;

  String? get keyNow => stepNow?.key;

  void clearFlags() {
    nudgeStep.value = null;
    reopenStep.value = null;
  }
}

extension TripPlanGuide on TripPlanController {
  TripGuideState get _g => guideState;

  bool get _guideAvailable {
    final p = plan.value;
    return p != null &&
        !tripGone.value &&
        !plannerOff.value &&
        !needsUpdate.value &&
        !isReadOnly &&
        !isCompleted &&
        !editMode.value &&
        p.spotCount > 0;
  }

  bool get guideAvailable => _guideAvailable;

  void guideRefresh() {
    final p = plan.value;
    if (p != null) guideHydrate();
    guideSync();
    final next = _guideAvailable && planStep.value == 2;
    if (_g.on.value != next) _g.on.value = next;
  }

  void guideHydrate() {
    final p = plan.value;
    if (p == null) return;
    final id = trip.value?.id ?? '';
    if (_g._hydrated && _g._hydratedFor == id) return;
    _g._hydrated = true;
    _g._hydratedFor = id;
    _g.choices
      ..clear()
      ..addAll(TripGuideRules.effective(p, easyRows));
    final keys = TripGuideRules.keys(p);
    final at = TripGuideRules.cursor(keys, p.guide?.step, _g.choices, answered: _answeredKeys(keys));
    _g.step = at >= keys.length ? TripGuideState.finishKey : keys[at];
  }

  bool guideAnswered(String key) {
    final sl = Get.isRegistered<TripShortlistController>() ? Get.find<TripShortlistController>() : null;
    final row = TripGuideRules.rowKeyOf(key);
    final info = row == null ? null : easyRowOf(row);
    return TripGuideRules.answered(
      choice: _g.choices[key],
      shortlisted: sl?.countOf(key) ?? 0,
      sentOk: _g.sentOk.contains(key),
      notNow: _g.notNow.contains(key),
      rowEvidence: info != null && TripGuideRules.hasSendEvidence(info.state),
    );
  }

  Set<String> _answeredKeys(List<String> keys) => {
        for (final k in keys)
          if (guideAnswered(k)) k,
      };

  void guideSync() {
    final p = plan.value;
    if (p == null) return;
    final steps = TripGuideRules.steps(p);
    final keys = [for (final s in steps) s.key];
    for (final e in TripGuideRules.effective(p, easyRows).entries) {
      _g.choices.putIfAbsent(e.key, () => e.value);
    }
    _g.steps
      ..clear()
      ..addAll(steps);
    final answered = _answeredKeys(keys);
    if (_g.step == TripGuideState.finishKey && keys.isNotEmpty) {
      final open = TripGuideRules.firstUnanswered(keys, answered);
      if (open >= 0) _g.step = keys[open];
    }
    final idx = _g.step == TripGuideState.finishKey && keys.isNotEmpty
        ? keys.length
        : TripGuideRules.cursor(keys, _g.step, _g.choices, answered: answered);
    final pct = TripGuideRules.percent(answered.length, keys.length);
    if (!(_g.answered.length == answered.length && _g.answered.containsAll(answered))) _g.answered.assignAll(answered);
    if (_g.total.value != keys.length) _g.total.value = keys.length;
    if (_g.index.value != idx) _g.index.value = idx;
    if (_g.percent.value != pct) _g.percent.value = pct;
    final choice = idx < keys.length ? _g.choices[keys[idx]] : null;
    if (_g.current.value != choice) _g.current.value = choice;
  }

  void _guidePersist() {
    final p = plan.value;
    if (p == null || isReadOnly) return;
    final step = TripGuide.stepPattern.hasMatch(_g.step) ? _g.step : '';
    final next = TripGuide(step: step, choices: {
      for (final e in _g.choices.entries)
        if (e.value != TripGuideChoice.find) e.key: e.value,
    });
    final old = p.guide ?? const TripGuide();
    if (old == next) return;
    plan.value = p.withGuide(next);
    scheduleSave();
  }

  void _guideCommit() {
    _guidePersist();
    guideRefresh();
  }

  void guideGoTo(int i) {
    final keys = [for (final s in _g.steps) s.key];
    if (keys.isEmpty) return;
    final at = i.clamp(0, keys.length);
    final from = _g.index.value;
    for (var k = from < 0 ? 0 : from; k < at && k < keys.length; k++) {
      if (!guideAnswered(keys[k])) return;
    }
    if (at >= keys.length && !keys.every(guideAnswered)) return;
    _g.step = at >= keys.length ? TripGuideState.finishKey : keys[at];
    _g.clearFlags();
    _guideCommit();
  }

  void guideNext() => guideGoTo(_g.index.value + 1);

  void guidePrevious() {
    if (_g.index.value <= 0) {
      planStep.value = 1;
      return;
    }
    guideGoTo(_g.index.value - 1);
  }

  void guideJumpTo(String step, {bool nudge = false, bool reopen = false, bool persist = false, String? name}) {
    if (!TripGuideRules.isStepKey(step)) return;
    guideHydrate();
    guideSync();
    if (persist && !nudge && !reopen) {
      final keys = [for (final s in _g.steps) s.key];
      final at = keys.indexOf(step);
      final open = TripGuideRules.firstUnanswered(keys, _g.answered.toSet());
      if (at < 0 || (open >= 0 && at > open)) return;
    }
    _g.step = step;
    _g.clearFlags();
    if (nudge) {
      _g.nudgeStep.value = step;
      _g.nudgeName.value = name?.trim() ?? '';
    }
    if (reopen) _g.reopenStep.value = step;
    planStep.value = 2;
    if (nudge || reopen || persist) {
      _guideCommit();
    } else {
      guideRefresh();
    }
    unawaited(TripShortlistController.to.load(force: true));
  }

  void guideDropStale(TripPlan old, TripPlan next) {
    final stale = TripGuideRules.staleKeys(old, next);
    if (stale.isEmpty) return;
    for (final k in stale) {
      _g.choices.remove(k);
      _g.notes.remove(k);
      _g.sent.remove(k);
      _g.failed.remove(k);
      _g.notNow.remove(k);
      _g.sentOk.remove(k);
    }
    if (stale.contains(_g.step)) _g.step = '';
    if (stale.contains(_g.nudgeStep.value) || stale.contains(_g.reopenStep.value)) _g.clearFlags();
  }

  void _setChoice(String key, TripGuideChoice? c) {
    _g.step = key;
    if (c != TripGuideChoice.find) _g.notNow.remove(key);
    if (c == null) {
      _g.choices.remove(key);
    } else {
      _g.choices[key] = c;
    }
    _g.clearFlags();
    _guideCommit();
  }

  Future<void> guideChoose(BuildContext context, String key, TripGuideChoice c) async {
    final row = TripGuideRules.rowKeyOf(key);
    if (row == null || isReadOnly) return;
    final prev = _g.choices[key];
    final shortlist = TripShortlistController.to;
    switch (c) {
      case TripGuideChoice.skip:
        if (openRowsOf(row).isNotEmpty || confirmedRowOf(row) != null) {
          AppToast.warning(TripStringsGuide.skipBlocked);
          return;
        }
        if (_journeyLinked(row)) {
          AppToast.warning(TripStringsGuide.skipArranged);
          return;
        }
        skipRow(row);
        _setChoice(key, c);
        if (shortlist.countOf(key) > 0) unawaited(shortlist.closeStep(key, reason: 'Skipped'));
      case TripGuideChoice.own:
        final res = await TripArrangeConfirm.mark(context, row);
        if (res == null) return;
        if (res is TripMarkBlocked) {
          AppToast.warning(TripStringsGuide.ownBlocked);
          return;
        }
        _setChoice(key, c);
        if (shortlist.countOf(key) > 0) unawaited(shortlist.closeStep(key, reason: 'Own'));
      case TripGuideChoice.find:
        if (prev == TripGuideChoice.own || prev == TripGuideChoice.skip) undoMark(row);
        if (!context.mounted) return;
        await guideFind(context, key, prev: prev);
    }
  }

  bool _journeyLinked(TripEasyRowKey row) {
    final p = plan.value;
    if (p == null) return false;
    switch (row.kind) {
      case TripEasyRowKind.gettingThere:
        return p.steps.of(TripStepRole.gettingThere).hasJourney;
      case TripEasyRowKind.comingBack:
        return p.steps.of(TripStepRole.comingBack).hasJourney;
      case TripEasyRowKind.between:
        return (p.legAt(row.legIndex ?? 2)?.arrival?.journeyId ?? '').isNotEmpty;
      case TripEasyRowKind.stay || TripEasyRowKind.taxi:
        return false;
    }
  }

  Future<void> guideFind(BuildContext context, String key, {TripGuideChoice? prev}) async {
    final row = TripGuideRules.rowKeyOf(key);
    if (row == null) return;
    _g.notNow.remove(key);
    final opened = await (_g.opener?.call(context, row, GuideArgs(key)) ?? TripNavigation.helpMeFind(context, row, guide: GuideArgs(key)));
    if (!opened) {
      if (prev == TripGuideChoice.own || prev == TripGuideChoice.skip) {
        _g.choices.remove(key);
        _guideCommit();
      }
      return;
    }
    if (_g.keyNow != key) {
      guideRefresh();
      return;
    }
    _setChoice(key, TripGuideChoice.find);
    unawaited(TripShortlistController.to.load(force: true));
    unawaited(refreshEnquiries());
  }

  Future<void> guideNewOptions(BuildContext context, String key) async {
    _g.clearFlags();
    await guideFind(context, key, prev: _g.choices[key]);
  }

  Future<bool> guideMarkBooked(String key, {String? listingId}) async {
    final row = TripGuideRules.rowKeyOf(key);
    if (row == null || isReadOnly) return false;
    final res = await TripShortlistController.to.markBooked(key, listingId: listingId);
    if (res == null) return false;
    await markOwn(row, withdrawOpen: true, serverClosed: true);
    _setChoice(key, TripGuideChoice.own);
    unawaited(refreshEnquiries());
    guideNext();
    return true;
  }

  String _failNote(TripEnquiryController en) => switch (en.lastErrorType) {
        TripEnquiryErrorTypes.enquiryLimit =>
          '${TripStrings.askLimitTitle}. ${TripStrings.askLimitBody(en.lastRetryAfterMinutes ?? 1)}',
        TripEnquiryErrorTypes.leadLimit => TripStringsShortlist.leadLimit,
        _ => en.lastErrorMessage ?? TripStringsShortlist.sendFailedNote,
      };

  int _firstComingLeg(TripPlan p) {
    for (final d in p.days) {
      if (!isDayPast(d.day)) return d.leg;
    }
    return p.days.isEmpty ? 1 : p.days.first.leg;
  }

  Future<({TripEnquiryBatch? batch, int unsent})> _sendTaxiLegs(TripPlan p, String key) async {
    final sl = TripShortlistController.to;
    final en = TripEnquiryController.to;
    final active = sl.activeOf(key).take(sl.max).toList();
    if (active.isEmpty) return (batch: null, unsent: 0);
    if (netOff) {
      AppToast.warning(TripStringsV2Find.offlineAsk);
      return (batch: null, unsent: 0);
    }
    final first = _firstComingLeg(p);
    final groups = <int, List<String>>{};
    for (final i in active) {
      final k = i.legIndex != null && p.legAt(i.legIndex!) != null ? i.legIndex! : first;
      groups.putIfAbsent(k, () => []).add(i.listingId);
    }
    final legs = groups.keys.toList()..sort();
    final items = <TripEnquiryModel>[];
    final skipped = <TripSkipped>[];
    final results = <TripSendResult>[];
    var short = false;
    int? left;
    var processed = 0;
    var sentAny = false;
    for (final k in legs) {
      final ids = groups[k]!;
      final days = [for (final d in legDays(k)) if (!isDayPast(d)) d];
      if (days.isEmpty) {
        for (final id in ids) {
          results.add(TripSendResult(listingId: id, status: 'Failed'));
        }
        processed += ids.length;
        continue;
      }
      final scope = '$key@$k';
      final b = await en.sendLead(
        days: days,
        taxiIds: ids,
        clientRequestId: sl.requestIdFor(scope, ids),
        stepKey: key,
      );
      if (b == null) break;
      sl.completeRequest(scope, ids);
      sl.applyResults(key, b.perRecipient);
      items.addAll(b.items);
      skipped.addAll(b.skipped);
      results.addAll(b.perRecipient);
      short = short || b.veryShortNotice;
      left = b.asksLeft ?? left;
      processed += ids.length;
      sentAny = true;
    }
    unawaited(sl.load(force: true));
    final batch = sentAny
        ? TripEnquiryBatch(items: items, skipped: skipped, veryShortNotice: short, asksLeft: left, results: results)
        : null;
    return (batch: batch, unsent: active.length - processed);
  }

  Future<AskResult?> _askCars(BuildContext? context, TripEasyRowKey row, String key, List<String> ids, String requestId) async {
    final custom = carSender;
    if (custom != null) return custom(key, ids, requestId);
    if (context == null || !context.mounted) return null;
    final ways = await (carWays ?? TripNavigation.carWaysFor)(row);
    if (ways == null) return null;
    try {
      await ways.load();
      final loaded = ways.result.value;
      if (ways.loadFailed.value || loaded == null) return null;
      final byId = <String, WayDriver>{
        for (final plan in loaded.plans)
          for (final leg in plan.legs)
            for (final d in leg.allDrivers) d.taxiId: d,
        for (final d in loaded.allTheWay) d.taxiId: d,
      };
      final drivers = [for (final id in ids) ?byId[id]];
      if (drivers.isEmpty) return const AskResult(items: [], skipped: [], veryShortNotice: false);
      if (!context.mounted) return null;
      return await ways.actions.askShortlisted(
        context,
        ways.singlePlan(drivers),
        step: key,
        requestId: requestId,
        taxiIds: [for (final d in drivers) d.taxiId],
      );
    } finally {
      ways.onClose();
    }
  }

  Future<TripEnquiryBatch?> guideSendAll(String key, {BuildContext? context}) async {
    final p = plan.value;
    final row = TripGuideRules.rowKeyOf(key);
    if (p == null || row == null || _g.sending.contains(key)) return null;
    _g.sending.add(key);
    _g.notes.remove(key);
    final en = TripEnquiryController.to;
    en.lastErrorType = null;
    en.lastErrorMessage = null;
    en.lastRetryAfterMinutes = null;
    try {
      final sl = TripShortlistController.to;
      final taxi = row.kind != TripEasyRowKind.stay;
      TripEnquiryBatch? batch;
      var unsent = 0;
      switch (row.kind) {
        case TripEasyRowKind.stay:
          final k = row.legIndex ?? 1;
          final n = p.legDayCount(k);
          var past = 0;
          for (var i = 0; i < n - 1; i++) {
            if (isDayPast(p.legStart(k) + i)) past++;
          }
          batch = await sl.sendStays(step: key, day: p.legStart(k) + past, nights: (n < 1 ? 1 : n) - past);
        case TripEasyRowKind.taxi:
          final r = await _sendTaxiLegs(p, key);
          batch = r.batch;
          unsent = r.unsent;
        case TripEasyRowKind.gettingThere || TripEasyRowKind.comingBack || TripEasyRowKind.between:
          batch = await sl.sendCars(step: key, ask: (ids, requestId) => _askCars(context, row, key, ids, requestId));
      }
      if (batch == null) {
        if (sl.countOf(key) > 0) _g.notes[key] = _failNote(en);
        return null;
      }
      guideRecordSend(key, batch, taxi: taxi, unsent: unsent);
      unawaited(refreshEnquiries());
      return batch;
    } finally {
      _g.sending.remove(key);
    }
  }

  void guideRecordSend(String key, TripEnquiryBatch batch, {required bool taxi, int unsent = 0}) {
    final en = TripEnquiryController.to;
    final results = batch.perRecipient;
    final ok = results.where((r) => r.ok).length;
    final bad = results.length - ok + unsent;
    _g.sent[key] = ok;
    if (ok > 0) {
      _g.sentOk.add(key);
      _g.choices.putIfAbsent(key, () => TripGuideChoice.find);
      guideSync();
    }
    if (bad > 0) {
      _g.failed[key] = bad;
      final firstBad = results.where((r) => !r.ok).firstOrNull;
      _g.notes[key] =
          unsent > 0 ? _failNote(en) : TripStringsShortlist.reasonLine(firstBad?.status ?? 'Failed', taxi: taxi);
    } else {
      _g.failed.remove(key);
    }
  }

  void guideNotNow(String key) {
    if (!_markNotNow(key)) return;
    guideNext();
  }

  bool _markNotNow(String key) {
    if (!Get.isRegistered<TripShortlistController>() || TripShortlistController.to.countOf(key) == 0) return false;
    if (_g.sentOk.contains(key)) return true;
    _g.notNow.add(key);
    _g.choices[key] = TripGuideChoice.find;
    _g.step = key;
    _guideCommit();
    return true;
  }

  void guideDismissSent(String key) {
    _markNotNow(key);
    _g.sent.remove(key);
    _g.failed.remove(key);
    _g.notes.remove(key);
  }
}
