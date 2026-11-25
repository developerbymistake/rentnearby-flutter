import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';
import 'gate_keys.dart';
import 'owner_manage_card.dart';

class OwnerInactive extends StatelessWidget {
  const OwnerInactive({super.key, required this.child, required this.reason, required this.onDelete, this.busy = false, this.taxi = false});

  final Widget child;
  final String reason;
  final VoidCallback onDelete;
  final bool busy;
  final bool taxi;

  @override
  Widget build(BuildContext context) => Column(
        key: GateKeys.inactiveRow,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(opacity: Alpha.v72, child: IgnorePointer(child: child)),
          Padding(
            padding: DS.insets(l: 18, t: 8, r: 18),
            child: Row(
              children: [
                Expanded(child: Text(reason, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, height: 1.35, letterSpacing: 0))),
                Gap.h(8),
                WhitePillButton(
                  tone: taxi ? OwnerLook.taxi.tone : OwnerLook.stay.tone,
                  label: OwnerSharedStrings.delete,
                  danger: true,
                  expand: false,
                  height: 42,
                  fontSize: 12.5,
                  onTap: busy ? null : onDelete,
                ),
              ],
            ),
          ),
        ],
      );
}

class OwnerInactiveCard extends StatelessWidget {
  const OwnerInactiveCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.sub,
    required this.reason,
    required this.editLabels,
    required this.onDelete,
    this.busy = false,
    this.taxi = false,
    this.margin,
  });

  final String eyebrow;
  final String title;
  final String? sub;
  final String reason;
  final List<String> editLabels;
  final VoidCallback onDelete;
  final bool busy;
  final bool taxi;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final tone = taxi ? OwnerLook.taxi.tone : OwnerLook.stay.tone;
    return KeyedSubtree(
      key: GateKeys.inactiveRow,
      child: OwnerManageCard(
        margin: margin,
        eyebrow: eyebrow,
        chip: OwnerSharedStrings.inactive,
        title: title,
        sub: sub,
        muted: true,
        footer: Text(reason, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, height: 1.35, letterSpacing: 0)),
        actions: [
          for (final label in editLabels) WhitePillButton(tone: tone, label: label, height: 42, fontSize: 12.5, enabled: false, onTap: null),
          WhitePillButton(tone: tone, label: OwnerSharedStrings.delete, danger: true, height: 42, fontSize: 12.5, onTap: busy ? null : onDelete),
        ],
      ),
    );
  }
}
