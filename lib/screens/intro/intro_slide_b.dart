import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';
import '../../design/extra/ext_auth.dart';
import 'intro_strings.dart';
import 'intro_widgets.dart';

class IntroSlideAsk extends StatefulWidget {
  const IntroSlideAsk({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideAsk> createState() => _AskState();
}

class _AskState extends IntroSlideState<IntroSlideAsk> {
  bool _accepted = false;
  int _style = 2;

  @override
  bool activeOf(IntroSlideAsk w) => w.isActive;

  @override
  void resetTaps() => setState(() {
    _accepted = false;
    _style = 2;
  });

  void _onAccept() {
    if (_accepted) {
      interacted();
      setState(() => _accepted = false);
      return;
    }
    HapticFeedback.mediumImpact();
    const IntroInteractionNotification().dispatch(context);
    setState(() => _accepted = true);
  }

  void _pick(int i) {
    setState(() => _style = i);
    interacted();
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[2];
    return IntroSlideFrame(
      index: 2,
      title: IntroStrings.stayTitle,
      entrance: entrance,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reveal(
            0,
            Text(
              IntroStrings.stayTimes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(13, FontWeight.w600, DesignColors.onPrimary),
            ),
          ),
          const SizedBox(height: 8),
          reveal(
            1,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  for (var i = 0; i < IntroStrings.stayStyles.length; i++)
                    Semantics(
                      button: true,
                      selected: _style == i,
                      label: IntroStrings.stayStyles[i],
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pick(i),
                        child: IntroChip3D(
                          tone: tone,
                          label: IntroStrings.stayStyles[i],
                          on: _style == i,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          reveal(
            2,
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _accepted ? 0.95 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        IntroStrings.stayConfirmed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(13, FontWeight.w600, DesignColors.onPrimary),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: _accepted
                        ? IntroStrings.reserved
                        : IntroStrings.reserve,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onAccept,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _accepted
                            ? IntroPill3D(
                                key: const ValueKey('reserved'),
                                tone: tone,
                                label: IntroStrings.reserved,
                                icon: Icons.check_rounded,
                              )
                            : IntroPill3D(
                                key: const ValueKey('reserve'),
                                tone: tone,
                                label: IntroStrings.reserve,
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

class IntroSlideLive extends StatefulWidget {
  const IntroSlideLive({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideLive> createState() => _LiveState();
}

class _LiveState extends IntroSlideState<IntroSlideLive> {
  bool _thirdDone = false;
  int _shares = 0;

  @override
  bool activeOf(IntroSlideLive w) => w.isActive;

  @override
  void resetTaps() => setState(() {
    _thirdDone = false;
    _shares = 0;
  });

  void _onThirdDot() {
    interacted();
    setState(() => _thirdDone = !_thirdDone);
  }

  void _onShare() {
    interacted();
    if (!reduce) setState(() => _shares++);
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[4];
    final rows = IntroStrings.todayRows;
    return IntroSlideFrame(
      index: 4,
      title: IntroStrings.todayTitle,
      entrance: entrance,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reveal(0, IntroRow3D(tone: tone, label: rows[0], done: true)),
          const SizedBox(height: 8),
          reveal(1, IntroRow3D(tone: tone, label: rows[1], done: true)),
          const SizedBox(height: 8),
          reveal(
            2,
            Semantics(
              button: true,
              toggled: _thirdDone,
              label: rows[2],
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onThirdDot,
                child: IntroRow3D(tone: tone, label: rows[2], done: _thirdDone),
              ),
            ),
          ),
          const SizedBox(height: 8),
          reveal(
            3,
            SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: IntroPill3D(
                      tone: tone,
                      label: _thirdDone
                          ? IntroStrings.todayDone
                          : IntroStrings.todayProgress,
                      ghost: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: IntroStrings.shareTrip,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onShare,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_shares),
                        tween: Tween<double>(
                          begin: _shares == 0 ? null : 0.9,
                          end: 1,
                        ),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        builder: (context, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: IntroPill3D(
                          tone: tone,
                          label: IntroStrings.shareTrip,
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

class IntroSlideStart extends StatefulWidget {
  const IntroSlideStart({
    super.key,
    required this.isActive,
    required this.progress,
  });
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideStart> createState() => _StartState();
}

class _StartState extends IntroSlideState<IntroSlideStart> {
  int _taps = 0;

  @override
  bool activeOf(IntroSlideStart w) => w.isActive;

  @override
  void resetTaps() => setState(() => _taps = 0);

  void _onMedallion() {
    interacted();
    if (!reduce) setState(() => _taps++);
  }

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[5];
    return IntroSlideFrame(
      index: 5,
      title: IntroStrings.nextTrip,
      entrance: entrance,
      child: reveal(
        1,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onMedallion,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_taps),
            tween: Tween<double>(begin: _taps == 0 ? null : 0.9, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: IntroRing3D(tone: tone, label: IntroStrings.ringValue),
          ),
        ),
      ),
    );
  }
}
