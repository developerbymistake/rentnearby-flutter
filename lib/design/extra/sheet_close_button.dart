import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';
import 'package:bakhli/design/tokens/design_scale.dart';

class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onTap, this.enabled = true});

  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Close',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? (onTap ?? () => Navigator.of(context).maybePop()) : null,
        child: SizedBox(
          width: DS.s(44),
          height: DS.s(44),
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: DS.s(28),
                height: DS.s(28),
                decoration: const BoxDecoration(color: DesignColors.scaffold, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: DS.s(16), color: DesignColors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
