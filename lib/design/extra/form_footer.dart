import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class FormFooter extends StatelessWidget {
  const FormFooter({
    super.key,
    required this.tone,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.primaryEnabled = true,
    this.primaryDanger = false,
    this.secondaryLabel,
    this.onSecondary,
    this.note,
    this.top,
    this.primaryKey,
    this.secondaryKey,
  });

  final ListingTone tone;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool primaryEnabled;
  final bool primaryDanger;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? note;
  final Widget? top;
  final Key? primaryKey;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final s = secondaryLabel;
    final n = note;
    final primary = GradientPillButton(key: primaryKey, tone: tone, label: primaryLabel, onTap: onPrimary, loading: primaryLoading, enabled: primaryEnabled, danger: primaryDanger);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16)), boxShadow: Ink3D.topEdge),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?top,
            if (s == null || s.isEmpty)
              primary
            else
              PillButtonRow(children: [WhitePillButton(key: secondaryKey, tone: tone, label: s, onTap: onSecondary), primary]),
            if (n != null && n.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(n, maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Form3D.muted, letterSpacing: 0)),
              ),
          ],
        ),
      ),
    );
  }
}
