import 'package:flutter/foundation.dart';

import 'intro_story_cast.dart';
import 'intro_story_math.dart';

class IntroRepaint extends ChangeNotifier {
  void bump() => notifyListeners();
}

class IntroStoryState {
  final IntroRepaint frame = IntroRepaint();
  final IntroRepaint scroll = IntroRepaint();
  final IntroPaletteMix palette = IntroPaletteMix();
  final CastFrame cast = CastFrame();
  final List<double> tl = List<double>.of(IntroStory.trailRestart);

  double p = 0;
  double t = 0;
  double idle = 0;
  double pit = 0;
  double artIn = 0;
  double? _arrS;
  double _pv = 0;
  double _paletteQ = -1;
  bool reduce = false;
  bool _frozen = false;
  double? _frozenArrT;

  double get q => storyQ(p);
  double get e0 => smooth(clamp01(p));
  double get s => storyS(q);
  double get d => s + idle;
  bool get frozen => _frozen;

  double get arrT {
    if (_frozen) return _frozenArrT ?? (p >= .9 ? 0 : -1);
    if (reduce) return p >= .9 ? IntroStory.arrivalSeconds : -1;
    final a = _arrS;
    return a == null ? -1 : t - a;
  }

  IntroArrival get arrival => IntroArrival.at(arrT, p);

  double get pitch => pit.clamp(-3.5, 3.5) + arrival.lean;

  void setProgress(double value) {
    final next = value.clamp(0.0, 5.0);
    if (next == p && _paletteQ >= 0) return;
    p = next;
    _trackArrival();
    if (q < 1.9) _restartTrail();
    _paletteQ = q;
    palette.update(q);
    _solve();
    scroll.bump();
    frame.bump();
  }

  void tick(double dt) {
    if (_frozen) return;
    t += dt;
    final wi = idleWeightOf(q);
    final idleStep = IntroStory.idleSpeed * wi * dt;
    idle += idleStep;
    _trackArrival();
    final v = (storyS(q + .01) - storyS(q - .01)) / .02;
    final acc = v - _pv;
    _pv = v;
    pit += ((-acc * .02) - pit) * .15;
    if (q < 1.9) _restartTrail();
    if (q >= 1.9 && q <= 2.1) {
      tl[1] += dt * .07;
      tl[2] += dt * .07;
    }
    var scrollChanged = idleStep != 0;
    if (artIn < 1 && artReady) {
      artIn = clamp01(artIn + dt / .2);
      scrollChanged = true;
    }
    _solve();
    if (scrollChanged) scroll.bump();
    frame.bump();
  }

  bool artReady = false;

  void onArtReady() {
    artReady = true;
    if (reduce || _frozen) artIn = 1;
    scroll.bump();
    frame.bump();
  }

  void _trackArrival() {
    if (p < .6) {
      _arrS = null;
    } else if (p >= .9 && _arrS == null) {
      _arrS = t;
    }
  }

  void _restartTrail() {
    tl[0] = IntroStory.trailRestart[0];
    tl[1] = IntroStory.trailRestart[1];
    tl[2] = IntroStory.trailRestart[2];
  }

  void _solve() {
    final t0 = reduce && !_frozen ? _restTime : t;
    solveCast(cast, q: q, t: t0, s: s, tl: tl, excited: arrival.excited);
  }

  double get _restTime => p.round() == 0 ? 6.0 : 3.0;

  double get time => reduce && !_frozen ? _restTime : t;

  @visibleForTesting
  void debugFreeze(double time, {double? arrT}) {
    _frozen = true;
    t = time;
    _frozenArrT = arrT;
    idle = 0;
    pit = 0;
    _pv = (storyS(q + .01) - storyS(q - .01)) / .02;
    artIn = artReady ? 1 : 0;
    _solve();
    scroll.bump();
    frame.bump();
  }

  void dispose() {
    frame.dispose();
    scroll.dispose();
  }
}
