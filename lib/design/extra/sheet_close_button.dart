import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';

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
          width: 44,
          height: 44,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: DesignColors.scaffold, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: DesignColors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
