import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../data/owner_error_types.dart';
import '../data/owner_result.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';

sealed class OwnerLoad<T> {
  const OwnerLoad();

  T? get valueOrNull => switch (this) {
        OwnerLoadData<T>(:final value) => value,
        _ => null,
      };

  bool get isLoading => this is OwnerLoadLoading<T>;
}

class OwnerLoadLoading<T> extends OwnerLoad<T> {
  const OwnerLoadLoading();
}

class OwnerLoadData<T> extends OwnerLoad<T> {
  const OwnerLoadData(this.value, {this.stale = false});
  final T value;
  final bool stale;
}

class OwnerLoadEmpty<T> extends OwnerLoad<T> {
  const OwnerLoadEmpty();
}

class OwnerLoadError<T> extends OwnerLoad<T> {
  const OwnerLoadError({this.message});
  final String? message;
}

class OwnerLoadOffline<T> extends OwnerLoad<T> {
  const OwnerLoadOffline();
}

class OwnerLoadPaused<T> extends OwnerLoad<T> {
  const OwnerLoadPaused(this.reason);
  final String? reason;
}

class OwnerLoadLocked<T> extends OwnerLoad<T> {
  const OwnerLoadLocked(this.key);
  final String key;
}

abstract final class OwnerLoads {
  static OwnerLoad<T> from<T>(OwnerResult<T> r, {T? saved, bool Function(T value)? isEmpty}) {
    switch (r) {
      case OwnerOk<T>(:final value):
        if (isEmpty != null && isEmpty(value)) return OwnerLoadEmpty<T>();
        return OwnerLoadData<T>(value);
      case OwnerOffline<T>():
        return saved != null ? OwnerLoadData<T>(saved, stale: true) : OwnerLoadOffline<T>();
      case OwnerRefused<T>():
        if (OwnerRefusal.paused(r)) return OwnerLoadPaused<T>(r.message);
        final locked = OwnerRefusal.lockedKey(r);
        if (locked != null) return OwnerLoadLocked<T>(locked);
        return saved != null ? OwnerLoadData<T>(saved, stale: true) : OwnerLoadError<T>(message: r.message);
      // A failure's text can be an exception string; the screen shows its own words instead (FX-28).
      case OwnerFailed<T>():
        return saved != null ? OwnerLoadData<T>(saved, stale: true) : OwnerLoadError<T>();
    }
  }
}

class OwnerStateWords {
  const OwnerStateWords({
    this.errorTitle = OwnerSharedStrings.couldNotLoad,
    this.errorBody,
    this.retry = OwnerSharedStrings.tryAgain,
    this.offlineTitle = OwnerSharedStrings.noConnection,
    this.emptyTitle = '',
    this.emptyBody,
    this.pausedTitle = '',
    this.pausedBody,
  });

  final String errorTitle;
  final String? errorBody;
  final String retry;
  final String offlineTitle;
  final String emptyTitle;
  final String? emptyBody;
  final String pausedTitle;
  final String? pausedBody;
}

class OwnerStateView<T> extends StatelessWidget {
  const OwnerStateView({
    super.key,
    required this.load,
    required this.look,
    required this.words,
    required this.data,
    this.onRetry,
    this.skeleton,
    this.locked,
  });

  final OwnerLoad<T> load;
  final OwnerLook look;
  final OwnerStateWords words;
  final Widget Function(BuildContext context, T value, bool stale) data;
  final VoidCallback? onRetry;
  final Widget? skeleton;
  final Widget Function(BuildContext context, String key)? locked;

  @override
  Widget build(BuildContext context) {
    final l = load;
    return switch (l) {
      OwnerLoadLoading<T>() => skeleton ?? const OwnerSkeletonList(),
      OwnerLoadData<T>(:final value, :final stale) => data(context, value, stale),
      OwnerLoadEmpty<T>() => StateCard(title: words.emptyTitle, message: words.emptyBody, kit: look.kit),
      OwnerLoadError<T>() => StateCard.error(
          title: words.errorTitle, message: words.errorBody, kit: look.kit, actionLabel: words.retry, onAction: onRetry),
      OwnerLoadOffline<T>() => StateCard.error(title: words.offlineTitle, kit: look.kit, actionLabel: words.retry, onAction: onRetry),
      OwnerLoadPaused<T>() => StateCard(title: words.pausedTitle, message: words.pausedBody ?? l.reason, kit: look.kit),
      OwnerLoadLocked<T>(:final key) => locked?.call(context, key) ?? const SizedBox.shrink(),
    };
  }
}

class OwnerSkeletonList extends StatelessWidget {
  const OwnerSkeletonList({super.key, this.rows = 3});

  final int rows;

  // Rows that fit a short body (FX-32): never more than [rows], at least one.
  static int fitRows(double maxHeight, int rows) {
    if (!maxHeight.isFinite) return rows;
    final row = DS.s(72) + DS.s(12);
    final fit = ((maxHeight - DS.s(24)) / row).floor();
    return fit.clamp(1, rows);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = fitRows(c.maxHeight, rows);
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: DS.sym(h: 18, v: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) Gap.v(12),
                SkeletonBox(height: DS.s(72), radius: DS.radius(16)),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class OwnerStaleLine extends StatelessWidget {
  const OwnerStaleLine({super.key, this.text = OwnerSharedStrings.showingLast});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.sym(h: 18, v: 6),
        child: Text(text, style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
      );
}
