import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../design/design.dart';
import 'intro_story_math.dart';

enum IntroArt { panda, fox, lion, taxi, tree, house, canoe, camping, framedPicture, mountain }

class IntroStoryArt {
  IntroStoryArt._();

  static final IntroStoryArt instance = IntroStoryArt._();

  static const Map<IntroArt, (String, double)> _spec = {
    IntroArt.panda: (ListingArt.panda, 48 * 1.24),
    IntroArt.fox: (ListingArt.fox, 48 * 1.24),
    IntroArt.lion: (ListingArt.lion, 48 * 1.24),
    IntroArt.taxi: (ListingArt.taxi, 150),
    IntroArt.tree: (ListingArt.tree, 84),
    IntroArt.house: (ListingArt.houseWithGarden, 74),
    IntroArt.canoe: (ListingArt.canoe, 72),
    IntroArt.camping: (ListingArt.camping, 92),
    IntroArt.framedPicture: (ListingArt.framedPicture, 48),
    IntroArt.mountain: (ListingArt.mountain, 40),
  };

  final List<ImageInfo?> _infos = List<ImageInfo?>.filled(IntroArt.values.length, null);
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  Future<void>? _loading;
  double _scale = 0;
  int _generation = 0;

  ui.Image? operator [](IntroArt a) => _infos[a.index]?.image;

  static void warm() {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return;
    final width = view.physicalSize.width / view.devicePixelRatio;
    if (width <= 0) return;
    unawaited(instance.load(width / IntroStory.sceneW, view.devicePixelRatio));
  }

  Future<void> load(double k, double dpr) {
    final scale = k * dpr;
    final pending = _loading;
    if (pending != null && scale <= _scale) return pending;
    _scale = scale;
    final future = _loadAll(scale, ++_generation);
    _loading = future;
    return future;
  }

  Future<void> _loadAll(double scale, int generation) async {
    final jobs = <Future<void>>[];
    for (final a in IntroArt.values) {
      final (path, size) = _spec[a]!;
      jobs.add(_resolve(a, path, (size * scale).ceil(), generation));
    }
    await Future.wait(jobs);
    if (generation == _generation) ready.value = true;
  }

  Future<void> _resolve(IntroArt a, String path, int width, int generation) {
    final done = Completer<void>();
    final stream = ResizeImage(AssetImage(path), width: width).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (generation != _generation) {
        info.dispose();
      } else {
        _infos[a.index]?.dispose();
        _infos[a.index] = info;
      }
      if (!done.isCompleted) done.complete();
    }, onError: (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    });
    stream.addListener(listener);
    return done.future;
  }

  void release() {
    for (var i = 0; i < _infos.length; i++) {
      _infos[i]?.dispose();
      _infos[i] = null;
    }
    _loading = null;
    _scale = 0;
    _generation++;
    ready.value = false;
  }
}
