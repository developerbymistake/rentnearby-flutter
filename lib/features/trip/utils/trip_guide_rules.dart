import '../models/trip_plan_model.dart';
import '../trip_strings_guide.dart';
import 'trip_easy_rules.dart';

enum TripGuideCard { question, review, nudge, reopened, finish }

class TripGuideStep {
  final String key;
  final TripEasyRowKey row;
  final String name;
  final String title;
  final String body;

  const TripGuideStep({required this.key, required this.row, required this.name, required this.title, required this.body});

  bool get isStay => row.kind == TripEasyRowKind.stay;

  bool get isTaxi => row.kind == TripEasyRowKind.taxi;
}

class TripGuideRules {
  const TripGuideRules._();

  static bool isStepKey(String? s) => s != null && TripGuide.stepPattern.hasMatch(s);

  static List<String> keys(TripPlan p) {
    final n = p.legs.isEmpty ? 1 : p.legs.length;
    return [
      TripEasyRowKind.gettingThere.name,
      TripEasyRowKey(TripEasyRowKind.stay, 1).id,
      TripEasyRowKind.taxi.name,
      for (var k = 2; k <= n; k++) ...[
        TripEasyRowKey(TripEasyRowKind.between, k).id,
        TripEasyRowKey(TripEasyRowKind.stay, k).id,
      ],
      TripEasyRowKind.comingBack.name,
    ];
  }

  static TripEasyRowKey? rowKeyOf(String step) => isStepKey(step) ? TripEasyRowKey.parse(step) : null;

  static List<TripGuideStep> steps(TripPlan p) {
    return [
      for (final k in keys(p))
        if (rowKeyOf(k) case final row?) describe(p, row),
    ];
  }

  static String cityList(TripPlan p, String fallback) {
    final names = <String>[];
    for (final l in p.legs) {
      final n = l.cityName.trim();
      if (n.isNotEmpty && !names.contains(n)) names.add(n);
    }
    if (names.isEmpty) return fallback;
    return names.length <= 2 ? names.join(' & ') : '${names.take(2).join(', ')} +${names.length - 2}';
  }

  static TripGuideStep describe(TripPlan p, TripEasyRowKey row) {
    final first = p.legAt(1)?.cityName ?? p.cityName;
    final k = row.legIndex ?? 1;
    final city = p.legAt(k)?.cityName ?? first;
    final prev = p.legAt(k - 1)?.cityName ?? '';
    switch (row.kind) {
      case TripEasyRowKind.gettingThere:
        final from = p.steps.startFrom?.name.trim() ?? '';
        return TripGuideStep(
          key: row.id,
          row: row,
          name: TripStringsGuide.nameGettingThere,
          title: TripStringsGuide.gettingThereTitle,
          body: TripStringsGuide.gettingThereBody(from.isEmpty ? 'your location' : from, first),
        );
      case TripEasyRowKind.stay:
        return TripGuideStep(
          key: row.id,
          row: row,
          name: TripStringsGuide.nameStay(city),
          title: TripStringsGuide.stayTitle(city),
          body: TripStringsGuide.stayBody(city),
        );
      case TripEasyRowKind.taxi:
        return TripGuideStep(
          key: row.id,
          row: row,
          name: TripStringsGuide.nameTaxi,
          title: TripStringsGuide.taxiTitle(cityList(p, first)),
          body: TripStringsGuide.taxiBody,
        );
      case TripEasyRowKind.between:
        return TripGuideStep(
          key: row.id,
          row: row,
          name: TripStringsGuide.nameBetween(city),
          title: TripStringsGuide.betweenTitle(city),
          body: TripStringsGuide.betweenBody(prev, city),
        );
      case TripEasyRowKind.comingBack:
        return const TripGuideStep(
          key: 'comingBack',
          row: TripEasyRowKey(TripEasyRowKind.comingBack),
          name: TripStringsGuide.nameWayBack,
          title: TripStringsGuide.backTitle,
          body: TripStringsGuide.backBody,
        );
    }
  }

  static TripGuideChoice? _fromRow(TripEasyRowInfo r) {
    if (r.state == TripRowState.skipped) return TripGuideChoice.skip;
    if (r.state == TripRowState.own) return TripGuideChoice.own;
    if (r.isDone || r.state.inProgress) return TripGuideChoice.find;
    return null;
  }

  static Map<String, TripGuideChoice> effective(TripPlan p, List<TripEasyRowInfo> rows) {
    final out = <String, TripGuideChoice>{};
    final stored = p.guide?.choices ?? const <String, TripGuideChoice>{};
    for (final k in keys(p)) {
      final c = stored[k];
      if (c != null) {
        out[k] = c;
        continue;
      }
      final row = rowKeyOf(k);
      final info = row == null ? null : TripEasyRules.rowOf(rows, row);
      final d = info == null ? null : _fromRow(info);
      if (d != null) out[k] = d;
    }
    return out;
  }

  static int percent(int resolved, int total) => total <= 0 ? 0 : (resolved * 100 / total).round().clamp(0, 100);

  static int resolvedCount(List<String> keys, Map<String, TripGuideChoice> choices, {Set<String>? engaged}) =>
      keys.where((k) {
        final c = choices[k];
        if (c == null) return false;
        return c != TripGuideChoice.find || engaged == null || engaged.contains(k);
      }).length;

  static int firstUnresolved(List<String> keys, Map<String, TripGuideChoice> choices) =>
      keys.indexWhere((k) => !choices.containsKey(k));

  static Set<String> staleKeys(TripPlan old, TripPlan next) {
    final out = <String>{};
    final n = old.legs.length > next.legs.length ? old.legs.length : next.legs.length;
    for (var k = 1; k <= n; k++) {
      final a = old.legAt(k)?.cityKey;
      final b = next.legAt(k)?.cityKey;
      if (a != b) out.add(TripEasyRowKey(TripEasyRowKind.stay, k).id);
      if (k >= 2) {
        final pa = old.legAt(k - 1)?.cityKey;
        final pb = next.legAt(k - 1)?.cityKey;
        if (a != b || pa != pb) out.add(TripEasyRowKey(TripEasyRowKind.between, k).id);
      }
    }
    return out;
  }

  static int cursor(List<String> keys, String? stored, Map<String, TripGuideChoice> choices) {
    if (keys.isEmpty) return 0;
    if (stored != null && stored.isNotEmpty) {
      final i = keys.indexOf(stored);
      if (i >= 0) return i;
    }
    for (var i = 0; i < keys.length; i++) {
      if (!choices.containsKey(keys[i])) return i;
    }
    return keys.length;
  }

  static TripGuideCard cardKind({
    required bool finish,
    required bool nudge,
    required bool reopen,
    required TripGuideChoice? choice,
    required int shortlisted,
    required bool noReply,
    required bool rowOpen,
  }) {
    if (finish) return TripGuideCard.finish;
    if (reopen) return TripGuideCard.reopened;
    if (nudge) return TripGuideCard.nudge;
    if (choice == TripGuideChoice.find) {
      if (shortlisted > 0) return TripGuideCard.review;
      if (noReply && rowOpen) return TripGuideCard.reopened;
    }
    return TripGuideCard.question;
  }

  static bool canNext(TripGuideCard card, TripGuideChoice? choice) =>
      card == TripGuideCard.question && choice != null;
}
