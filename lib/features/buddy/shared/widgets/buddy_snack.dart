import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

class BuddySnackBar extends StatelessWidget {
  const BuddySnackBar({super.key, required this.text, this.icon = BuddySnack.tick, this.actionLabel, this.onAction});

  final String text;
  final String icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(54)),
          padding: DS.sym(h: 16),
          decoration: BoxDecoration(
            color: BuddyLook.snackBg,
            borderRadius: DS.circular(14),
            boxShadow: [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v25), offset: DS.shadowOffset(const Offset(0, 6)), blurRadius: DS.shadowBlur(16))],
          ),
          child: Row(
            children: [
              Container(
                width: DS.s(28),
                height: DS.s(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: BuddyLook.teal.gradient),
                child: icon == BuddySnack.tick
                    ? Icon(Icons.check_rounded, size: DS.s(16), color: DesignColors.onPrimary)
                    : Text(icon, textScaler: TextScaler.noScaling, style: Ink3D.text(14, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
              ),
              Gap.h(12),
              Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, DesignColors.onPrimary, letterSpacing: 0))),
              if (actionLabel != null)
                Tap3D(
                  onTap: onAction,
                  label: actionLabel,
                  exclude: true,
                  child: Container(
                    constraints: BoxConstraints(minHeight: DS.s(40)),
                    padding: DS.insets(l: 12),
                    alignment: Alignment.center,
                    child: Text(actionLabel!, style: Ink3D.text(13.5, FontWeight.w700, BuddyLook.snackAction, letterSpacing: 0)),
                  ),
                ),
            ],
          ),
        ),
      );
}

abstract final class BuddySnack {
  static const String tick = '✔';
  static const Duration duration = Duration(seconds: 4);
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static void show(BuildContext context, String text, {String icon = tick, String? actionLabel, VoidCallback? onAction, double bottom = 24}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    final entry = OverlayEntry(
      builder: (c) => Positioned(
        left: DS.s(18),
        right: DS.s(18),
        bottom: DS.s(bottom) + MediaQuery.paddingOf(c).bottom,
        child: Material(
          type: MaterialType.transparency,
          child: BuddySnackBar(
            text: text,
            icon: icon,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () {
                    hide();
                    onAction();
                  },
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, hide);
  }
}
