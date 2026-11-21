import 'package:get/get.dart';

import '../../../config/shell_kind.dart';

typedef TeardownFn = void Function();

abstract final class ShellTeardown {
  static final Map<ShellKind, List<TeardownFn>> _steps = {};

  static void register(ShellKind kind, TeardownFn step) => (_steps[kind] ??= <TeardownFn>[]).add(step);

  static void reset() => _steps.clear();

  static void deleteTagged<T>(String tag) {
    if (Get.isRegistered<T>(tag: tag)) Get.delete<T>(tag: tag, force: true);
  }

  static void run(ShellKind kind) {
    final steps = _steps.remove(kind) ?? const <TeardownFn>[];
    for (final s in steps) {
      try {
        s();
      } catch (_) {}
    }
  }
}
