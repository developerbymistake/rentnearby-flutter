import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';

enum ToastKind { success, error, warning, info }

class _ToastLook {
  const _ToastLook(this.g1, this.g2, this.color, this.glyph);

  final Color g1;
  final Color g2;
  final Color color;
  final String glyph;

  static _ToastLook of(ToastKind kind) => switch (kind) {
    ToastKind.success => const _ToastLook(Color(0xFF66BB6A), Color(0xFF2E7D32), Color(0xFF2E7D32), ''),
    ToastKind.error => const _ToastLook(Color(0xFFFA7D82), Color(0xFFE0525C), Color(0xFFE0525C), '!'),
    ToastKind.warning => const _ToastLook(Color(0xFFFFC371), Color(0xFFFF8A3D), Color(0xFFE67000), '!'),
    ToastKind.info => const _ToastLook(Color(0xFF738AE6), Color(0xFF5C5EDD), Color(0xFF5C5EDD), 'i'),
  };
}

class Toast3D extends StatelessWidget {
  const Toast3D({super.key, required this.kind, required this.message, this.compact = false});

  final ToastKind kind;
  final String message;
  final bool compact;

  static Color colorOf(ToastKind kind) => _ToastLook.of(kind).color;

  @override
  Widget build(BuildContext context) {
    final look = _ToastLook.of(kind);
    final glyph = compact ? 30.0 : 36.0;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 46 : 62),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 6 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: look.color.withValues(alpha: 0.4), width: 1.4),
            boxShadow: const [BoxShadow(color: Color(0x24000000), offset: Offset(0, 6), blurRadius: 16)],
          ),
          child: Row(
            children: [
              Container(
                width: glyph,
                height: glyph,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [look.g1, look.g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: look.color.withValues(alpha: 0.4), offset: const Offset(2, 4), blurRadius: 8)],
                ),
                child: look.glyph.isEmpty
                    ? Icon(Icons.check_rounded, size: glyph * 0.56, color: Colors.white)
                    : Text(
                        look.glyph,
                        textScaler: TextScaler.noScaling,
                        style: Ink3D.text(16, FontWeight.w700, Colors.white, height: 1, letterSpacing: 0),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(13.5, FontWeight.w600, look.color, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoDataToast3D extends StatelessWidget {
  const NoDataToast3D({super.key, required this.title, required this.subtitle, required this.accent, this.art});

  final String title;
  final String subtitle;
  final Color accent;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E8EE)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25), offset: const Offset(0, 6), blurRadius: 16)],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    Positioned(
                      left: -4,
                      top: -10,
                      child: Art3D(asset: art ?? ListingArt.compass, size: 54, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.title)),
                    Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToastDock extends StatefulWidget {
  const ToastDock({super.key, this.margin = const EdgeInsets.only(bottom: 4)});

  final EdgeInsets margin;

  @override
  State<ToastDock> createState() => _ToastDockState();
}

class _ToastDockState extends _ToastHostState<ToastDock> {
  @override
  bool get isDock => true;

  @override
  EdgeInsets get margin => widget.margin;
}

class ToastSlot extends StatefulWidget {
  const ToastSlot({super.key, this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 0)});

  final EdgeInsets margin;

  @override
  State<ToastSlot> createState() => _ToastSlotState();
}

class _ToastSlotState extends _ToastHostState<ToastSlot> {
  @override
  bool get isDock => false;

  @override
  EdgeInsets get margin => widget.margin;
}

abstract class _ToastHostState<T extends StatefulWidget> extends State<T> {
  bool get isDock;
  EdgeInsets get margin;

  ModalRoute<dynamic>? _route;
  ToastKind? _kind;
  String _message = '';
  int _serial = 0;
  Timer? _timer;

  bool get usable => mounted && (_route?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    ToastLane._hosts.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    ToastLane._hosts.remove(this);
    super.dispose();
  }

  void present(ToastKind kind, String message, Duration duration) {
    _timer?.cancel();
    setState(() {
      _kind = kind;
      _message = message;
      _serial++;
    });
    _timer = Timer(duration, () {
      if (mounted) setState(() => _kind = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final kind = _kind;
    final child = kind == null
        ? const SizedBox(key: ValueKey<int>(0), width: double.infinity)
        : Padding(
            key: ValueKey<int>(_serial),
            padding: margin,
            child: Toast3D(kind: kind, message: _message),
          );
    if (still) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: isDock ? Alignment.bottomCenter : Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
        child: child,
      ),
    );
  }
}

abstract final class ToastLane {
  static final List<_ToastHostState<StatefulWidget>> _hosts = [];

  // A dock on the top route wins over a slot; hosts under a sheet or dialog do not count.
  static bool showInHost(ToastKind kind, String message, {Duration duration = const Duration(seconds: 4)}) {
    _ToastHostState<StatefulWidget>? pick;
    for (final h in _hosts.reversed) {
      if (!h.usable) continue;
      if (h.isDock) {
        pick = h;
        break;
      }
      pick ??= h;
    }
    if (pick == null) return false;
    pick.present(kind, message, duration);
    return true;
  }

  static double topOffset(BuildContext context) => MediaQuery.paddingOf(context).top + 8;
}
