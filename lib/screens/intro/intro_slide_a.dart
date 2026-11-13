import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../design/extra/ext_auth.dart';
import 'intro_strings.dart';
import 'intro_widgets.dart';

class IntroSlidePick extends StatefulWidget {
  const IntroSlidePick({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  static const List<bool> defaults = [
    false,
    true,
    false,
    false,
    true,
    false,
    true,
    false,
  ];

  @override
  State<IntroSlidePick> createState() => _PickState();
}

class _PickState extends IntroSlideState<IntroSlidePick> {
  List<bool> _picked = List<bool>.of(IntroSlidePick.defaults);

  @override
  bool activeOf(IntroSlidePick w) => w.isActive;

  @override
  void resetTaps() =>
      setState(() => _picked = List<bool>.of(IntroSlidePick.defaults));

  void _toggle(int i) {
    setState(() => _picked[i] = !_picked[i]);
    interacted();
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[0];
    final n = _picked.where((p) => p).length;
    return IntroSlideFrame(
      index: 0,
      title: IntroStrings.stylesPicked(n),
      entrance: entrance,
      child: reveal(
        1,
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < IntroStrings.travelStyles.length; i++)
              Semantics(
                button: true,
                selected: _picked[i],
                label: IntroStrings.travelStyles[i],
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggle(i),
                  child: IntroChip3D(
                    tone: tone,
                    label: IntroStrings.travelStyles[i],
                    on: _picked[i],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class IntroSlidePlan extends StatefulWidget {
  const IntroSlidePlan({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlidePlan> createState() => _PlanState();
}

class _PlanState extends IntroSlideState<IntroSlidePlan> {
  int _focusDay = 0;

  @override
  bool activeOf(IntroSlidePlan w) => w.isActive;

  @override
  void resetTaps() => setState(() => _focusDay = 0);

  void _selectDay(int d) {
    setState(() => _focusDay = _focusDay == d ? 0 : d);
    interacted();
  }

  Widget _dayPill(ListingTone tone, int d) {
    final label = d == 1 ? IntroStrings.day1 : IntroStrings.day2;
    final focused = _focusDay == d;
    return Semantics(
      button: true,
      selected: focused,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectDay(d),
        child: IntroPill3D(tone: tone, label: label, ghost: !focused),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[1];
    final first = _focusDay != 2;
    return IntroSlideFrame(
      index: 1,
      title: first ? IntroStrings.day1 : IntroStrings.day2,
      entrance: entrance,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reveal(
            1,
            IntroTrack3D(
              tone: tone,
              labels: first
                  ? const [
                      IntroStrings.nodeA,
                      IntroStrings.nodeB,
                      IntroStrings.nodeC,
                    ]
                  : const [IntroStrings.nodeB, IntroStrings.nodeC],
              carAt: first ? 0.2 : 0.5,
              carArt: ListingArt.taxi,
              tag: IntroStrings.yourRide,
            ),
          ),
          const SizedBox(height: 8),
          reveal(
            2,
            Align(
              alignment: Alignment.centerLeft,
              child: _focusDay == 0
                  ? _dayPill(tone, 2)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: _dayPill(tone, 1)),
                          const SizedBox(width: 8),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: _dayPill(tone, 2)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroSlideTaxi extends StatefulWidget {
  const IntroSlideTaxi({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideTaxi> createState() => _TaxiState();
}

class _TaxiState extends IntroSlideState<IntroSlideTaxi> {
  int _car = 0;
  int _pulse = 0;

  @override
  bool activeOf(IntroSlideTaxi w) => w.isActive;

  @override
  void resetTaps() => setState(() => _car = 0);

  void _select(int i) {
    setState(() {
      _car = i;
      if (!reduce) _pulse++;
    });
    interacted();
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[3];
    return IntroSlideFrame(
      index: 3,
      title: IntroStrings.ridesTitle,
      entrance: entrance,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < IntroStrings.rideRows.length; i++) ...[
            reveal(
              i,
              IntroRow3D(
                tone: tone,
                label: IntroStrings.rideRows[i],
                done: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          reveal(
            3,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  for (var i = 0; i < IntroStrings.carTypes.length; i++)
                    Semantics(
                      button: true,
                      selected: _car == i,
                      label: IntroStrings.carTypes[i],
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _select(i),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_car == i ? _pulse : -1),
                          tween: Tween<double>(begin: _car == i && _pulse > 0 ? 0.9 : null, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (context, v, child) => Transform.scale(scale: v, child: child),
                          child: IntroChip3D(
                            tone: tone,
                            label: IntroStrings.carTypes[i],
                            on: _car == i,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
