import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
      padding: DS.all(12),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(TripLook.cardShadowSoft)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(number: 1, title: TripStringsTaxiStatus.stepFinding, sub: findingSub, state: _stateOf(0, at)),
          _Step(number: 2, title: TripStringsTaxiStatus.stepChoose, sub: TripStringsTaxiStatus.stepChooseSub, state: _stateOf(1, at)),
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
    final row = Container(
      key: ValueKey('taxi_step_$number'),
      padding: DS.all(12),
      decoration: BoxDecoration(color: active ? ListingPalette.indigo.tint : null, borderRadius: DS.br(CardRadius.tile)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: Ink3D.text(14.5, FontWeight.w700, active ? DesignColors.primary : Ink3D.title, letterSpacing: 0),
                ),
                Text(
                  sub,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return state == _StepState.todo ? Opacity(opacity: 0.6, child: row) : row;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.number, required this.state});

  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final box = DS.s(32);
    final number = Text('${this.number}', style: Ink3D.text(13, FontWeight.w700, state == _StepState.active ? DesignColors.textInverse : TripLook.mutedText, letterSpacing: 0));
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          _StepState.done => TaxiStatusLook.goodSoft,
          _StepState.active => null,
          _StepState.todo => Ink3D.line,
        },
        gradient: state == _StepState.active ? ListingTone.indigo.gradient : null,
      ),
      child: state == _StepState.done ? Icon(Icons.check_rounded, size: DS.s(16), color: DesignColors.goodInk) : number,
    );
  }
}
