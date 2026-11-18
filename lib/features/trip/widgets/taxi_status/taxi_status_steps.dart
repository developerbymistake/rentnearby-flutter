import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../trip_strings_taxi_status.dart';

enum TaxiStepStage { finding, choosing, booked }

class TaxiStatusSteps extends StatelessWidget {
  const TaxiStatusSteps({super.key, required this.stage, required this.findingSub});

  final TaxiStepStage stage;
  final String findingSub;

  @override
  Widget build(BuildContext context) {
    final at = stage.index;
    return Container(
      padding: DS.sym(h: 12, v: 12),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(
        children: [
          _Step(number: 1, title: TripStringsTaxiStatus.stepFinding, sub: findingSub, state: _stateOf(0, at)),
          Gap.v(6),
          _Step(number: 2, title: TripStringsTaxiStatus.stepChoose, sub: TripStringsTaxiStatus.stepChooseSub, state: _stateOf(1, at)),
          Gap.v(6),
          _Step(number: 3, title: TripStringsTaxiStatus.stepBooked, sub: TripStringsTaxiStatus.stepBookedSub, state: _stateOf(2, at)),
        ],
      ),
    );
  }

  static _StepState _stateOf(int index, int at) => index < at ? _StepState.done : (index == at ? _StepState.active : _StepState.todo);
}

enum _StepState { done, active, todo }

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.sub, required this.state});

  final int number;
  final String title;
  final String sub;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StepState.active;
    final todo = state == _StepState.todo;
    return Container(
      key: ValueKey('taxi_step_$number'),
      padding: DS.sym(h: 14, v: 10),
      decoration: BoxDecoration(color: active ? DesignColors.surfaceTint : null, borderRadius: DS.circular(12)),
      child: Row(
        children: [
          _Dot(number: number, state: state),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(15, FontWeight.w700, active ? DesignColors.primary : (todo ? DesignColors.textMuted : Ink3D.title)),
                ),
                Text(
                  sub,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(13, FontWeight.w400, todo ? DesignColors.textDisabled : Ink3D.copy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.number, required this.state});

  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final box = DS.s(40);
    return switch (state) {
      _StepState.done => Container(
          width: box,
          height: box,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignColors.successSoft),
          child: Icon(Icons.check_rounded, size: DS.s(20), color: DesignColors.success),
        ),
      _StepState.active => Container(
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: ListingTone.indigo.gradient),
          child: Text('$number', style: Ink3D.text(15, FontWeight.w700, DesignColors.textInverse)),
        ),
      _StepState.todo => Container(
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignColors.chipBackground),
          child: Text('$number', style: Ink3D.text(15, FontWeight.w700, DesignColors.textDisabled)),
        ),
    };
  }
}
