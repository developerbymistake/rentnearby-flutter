import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_guide_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TripPlan plan(int legs) => TripPlan(
      legs: [
        for (var k = 1; k <= legs; k++)
          TripCityLeg(index: k, cityKey: k, cityName: 'City$k', latitude: 29.4 + k / 10, longitude: 79.4),
      ],
      days: [for (var k = 1; k <= legs; k++) TripDay(day: k, leg: k)],
    );

void main() {
  group('steps and order', () {
    test('single city order', () {
      expect(TripGuideRules.keys(plan(1)), ['gettingThere', 'stay:1', 'taxi', 'comingBack']);
    });

    test('multi city order puts between and stay per city after the local taxi', () {
      expect(TripGuideRules.keys(plan(3)), [
        'gettingThere',
        'stay:1',
        'taxi',
        'between:2',
        'stay:2',
        'between:3',
        'stay:3',
        'comingBack',
      ]);
    });

    test('the largest real plan (4 cities, 10 steps) is described without gaps', () {
      final p = plan(4);
      final steps = TripGuideRules.steps(p);
      expect(steps.length, 10);
      expect(steps.map((s) => s.key).toSet().length, 10);
      expect(steps.every((s) => s.name.isNotEmpty && s.title.isNotEmpty && s.body.isNotEmpty), isTrue);
    });

    test('copy follows the contract', () {
      final steps = TripGuideRules.steps(plan(2));
      expect(steps[0].title, "Let's get you there");
      expect(steps[1].name, 'Stay in City1');
      expect(steps[1].title, 'Where will you stay in City1?');
      expect(steps[2].name, 'Sightseeing taxi');
      expect(steps[3].name, 'To City2');
      expect(steps[3].body, 'Do you need a taxi from City1 to City2?');
      expect(steps.last.name, 'Way back');
    });
  });

  group('percent and cursor', () {
    final keys = TripGuideRules.keys(plan(1));

    test('percent is resolved over total', () {
      expect(TripGuideRules.percent(0, 4), 0);
      expect(TripGuideRules.percent(1, 4), 25);
      expect(TripGuideRules.percent(4, 4), 100);
      expect(TripGuideRules.percent(0, 0), 0);
    });

    test('cursor resumes at the stored step', () {
      expect(TripGuideRules.cursor(keys, 'taxi', const {}), 2);
    });

    test('cursor falls back to the first unresolved step', () {
      final choices = {'gettingThere': TripGuideChoice.find, 'stay:1': TripGuideChoice.skip};
      expect(TripGuideRules.cursor(keys, null, choices), 2);
      expect(TripGuideRules.cursor(keys, 'bogus', choices), 2);
    });

    test('everything resolved means finish', () {
      final all = {for (final k in keys) k: TripGuideChoice.skip};
      expect(TripGuideRules.cursor(keys, null, all), keys.length);
    });
  });

  group('card kind and next', () {
    TripGuideCard kind({
      bool finish = false,
      bool nudge = false,
      bool reopen = false,
      TripGuideChoice? choice,
      int shortlisted = 0,
      bool noReply = false,
      bool rowOpen = false,
    }) =>
        TripGuideRules.cardKind(
          finish: finish,
          nudge: nudge,
          reopen: reopen,
          choice: choice,
          shortlisted: shortlisted,
          noReply: noReply,
          rowOpen: rowOpen,
        );

    test('question by default', () => expect(kind(), TripGuideCard.question));

    test('review once something is shortlisted', () {
      expect(kind(choice: TripGuideChoice.find, shortlisted: 2), TripGuideCard.review);
      expect(kind(choice: TripGuideChoice.own, shortlisted: 2), TripGuideCard.question);
    });

    test('nudge and reopen win over the question', () {
      expect(kind(nudge: true), TripGuideCard.nudge);
      expect(kind(reopen: true), TripGuideCard.reopened);
      expect(kind(choice: TripGuideChoice.find, noReply: true, rowOpen: true), TripGuideCard.reopened);
      expect(kind(choice: TripGuideChoice.find, noReply: true, rowOpen: false), TripGuideCard.question);
    });

    test('finish wins', () => expect(kind(finish: true, nudge: true), TripGuideCard.finish));

    test('next needs a choice and skip counts', () {
      expect(TripGuideRules.canNext(TripGuideCard.question, null), isFalse);
      expect(TripGuideRules.canNext(TripGuideCard.question, TripGuideChoice.skip), isTrue);
      expect(TripGuideRules.canNext(TripGuideCard.question, TripGuideChoice.own), isTrue);
      expect(TripGuideRules.canNext(TripGuideCard.review, TripGuideChoice.find), isFalse);
    });
  });

  test('step keys follow the contract regex', () {
    for (final ok in ['gettingThere', 'comingBack', 'taxi', 'stay:1', 'stay:12', 'between:2', 'between:20']) {
      expect(TripGuideRules.isStepKey(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'stay:0', 'stay:100', 'between:1', 'finish', 'stay', null]) {
      expect(TripGuideRules.isStepKey(bad), isFalse, reason: '$bad');
    }
  });
}
