import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';
import 'gate_keys.dart';
import 'plan_gate.dart';

class PlusChip extends StatelessWidget {
  const PlusChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return Container(
      key: GateKeys.plusChip,
      padding: DS.sym(h: 7, v: 1),
      decoration: BoxDecoration(
        color: OwnerLook.plus,
        borderRadius: DS.circular(8),
      ),
      child: Text(
        OwnerSharedStrings.plus,
        style: Ink3D.text(
          10,
          FontWeight.w700,
          DesignColors.onPrimary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class SeePlusButton extends StatelessWidget {
  const SeePlusButton({
    super.key,
    this.label = OwnerSharedStrings.seePlus,
    this.onPressed,
    this.compact = true,
    this.taxi = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final bool taxi;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return KeyedSubtree(
      key: GateKeys.seePlus,
      child: PrimaryButton(
        label: label,
        compact: compact,
        expand: false,
        tone: taxi ? OwnerLook.taxi.kit : OwnerLook.stay.kit,
        onPressed: onPressed ?? PlanGate.seePlus,
      ),
    );
  }
}

abstract final class SoftLock {
  static Widget row({
    required String text,
    String? sub,
    bool taxi = false,
    VoidCallback? onTap,
    Widget? unlocked,
  }) => _SoftLockRow(
    text: text,
    sub: sub,
    taxi: taxi,
    onTap: onTap,
    unlocked: unlocked,
  );

  static Widget strip({required String text, bool taxi = false, VoidCallback? onTap}) => _PlanStrip(text: text, taxi: taxi, onTap: onTap);

  static Widget card({
    required Widget child,
    required String lockedTitle,
    String? lockedBody,
    bool taxi = false,
  }) => _SoftLockCard(
    lockedTitle: lockedTitle,
    lockedBody: lockedBody,
    taxi: taxi,
    child: child,
  );

  static Widget arrow({
    required Widget unlocked,
    required bool locked,
    VoidCallback? onLockedTap,
  }) => _SoftLockArrow(
    unlocked: unlocked,
    locked: locked,
    onLockedTap: onLockedTap,
  );
}

class _SoftLockRow extends StatelessWidget {
  const _SoftLockRow({
    required this.text,
    this.sub,
    required this.taxi,
    this.onTap,
    this.unlocked,
  });

  final String text;
  final String? sub;
  final bool taxi;
  final VoidCallback? onTap;
  final Widget? unlocked;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return unlocked ?? const SizedBox.shrink();
    final look = taxi ? OwnerLook.taxi : OwnerLook.stay;
    return InkWell(
      key: GateKeys.softRow,
      onTap: onTap ?? PlanGate.seePlus,
      borderRadius: DS.circular(14),
      child: Container(
        padding: DS.sym(h: 14, v: 10),
        decoration: BoxDecoration(
          color: look.lockFill,
          borderRadius: DS.circular(14),
          border: Border.all(color: look.lockLine),
        ),
        child: Row(
          children: [
            Art3D(asset: ListingArt.locked, size: 26),
            Gap.h(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: Ink3D.text(
                      13,
                      FontWeight.w600,
                      look.lockText,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: Ink3D.text(
                        12,
                        FontWeight.w500,
                        Ink3D.grey,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
            ),
            Gap.h(8),
            SeePlusButton(taxi: taxi, onPressed: onTap),
          ],
        ),
      ),
    );
  }
}

class _PlanStrip extends StatelessWidget {
  const _PlanStrip({required this.text, required this.taxi, this.onTap});

  final String text;
  final bool taxi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    final look = taxi ? OwnerLook.taxi : OwnerLook.stay;
    final tap = onTap ?? PlanGate.seePlus;
    return InkWell(
      key: GateKeys.planStrip,
      onTap: tap,
      borderRadius: DS.circular(14),
      child: Container(
        padding: DS.sym(h: 14, v: 10),
        decoration: BoxDecoration(
          color: look.lockFill,
          borderRadius: DS.circular(14),
          border: Border.all(color: look.lockLine),
        ),
        child: Row(
          children: [
            Art3D(asset: ListingArt.crown, size: 26),
            Gap.h(10),
            Expanded(
              child: Text(
                text,
                style: Ink3D.text(
                  13,
                  FontWeight.w600,
                  look.lockText,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            Gap.h(8),
            SeePlusButton(taxi: taxi, onPressed: tap),
          ],
        ),
      ),
    );
  }
}

class _SoftLockCard extends StatelessWidget {
  const _SoftLockCard({
    required this.child,
    required this.lockedTitle,
    this.lockedBody,
    required this.taxi,
  });

  final Widget child;
  final String lockedTitle;
  final String? lockedBody;
  final bool taxi;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return child;
    return KeyedSubtree(
      key: GateKeys.softCard,
      child: Stack(
        children: [
          Opacity(
            opacity: Alpha.v40,
            child: IgnorePointer(child: child),
          ),
          Positioned.fill(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: DS.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Art3D(asset: ListingArt.locked, size: 32),
                      Gap.v(6),
                      Text(
                        lockedTitle,
                        textAlign: TextAlign.center,
                        style: Ink3D.text(
                          14,
                          FontWeight.w700,
                          Ink3D.title,
                          letterSpacing: 0,
                        ),
                      ),
                      if (lockedBody != null) ...[
                        Gap.v(2),
                        Text(
                          lockedBody!,
                          textAlign: TextAlign.center,
                          style: Ink3D.text(
                            12,
                            FontWeight.w500,
                            Ink3D.grey,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      Gap.v(8),
                      SeePlusButton(taxi: taxi),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftLockArrow extends StatelessWidget {
  const _SoftLockArrow({
    required this.unlocked,
    required this.locked,
    this.onLockedTap,
  });

  final Widget unlocked;
  final bool locked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    if (!locked || !PlanGate.canUpgrade) return unlocked;
    return InkWell(
      key: GateKeys.softArrow,
      onTap: onLockedTap ?? PlanGate.seePlus,
      borderRadius: DS.circular(12),
      child: Padding(
        padding: DS.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: DS.s(16), color: Ink3D.hint),
            Gap.h(4),
            const PlusChip(),
          ],
        ),
      ),
    );
  }
}
