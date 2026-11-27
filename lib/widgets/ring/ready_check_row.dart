import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import 'ring_strings.dart';

export 'ring_strings.dart';

/// One item of a ring readiness checklist (taxi requests, stay enquiries).
class ReadyCheckRow extends StatelessWidget {
  const ReadyCheckRow({super.key, required this.tone, required this.title, required this.text, required this.done, this.extra, this.actionKey, this.onFix});

  final ListingTone tone;
  final String title;
  final String text;
  final String? extra;
  final bool done;
  final Key? actionKey;
  final Future<bool> Function()? onFix;

  @override
  Widget build(BuildContext context) {
    final accent = done ? AppColors.successText : tone.text;
    return Container(
      padding: EdgeInsets.all(DS.s(14)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.error_rounded, size: DS.s(26), color: accent),
            Gap.h(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
                Gap.v(2),
                Text(text, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.35)),
                if (extra != null) ...[Gap.v(4), Text(extra!, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0, height: 1.35))],
              ]),
            ),
            Gap.h(8),
            Text(done ? RingReadyStrings.done : RingReadyStrings.fix, style: Ink3D.text(12.5, FontWeight.w700, accent)),
          ]),
          if (!done && onFix != null) ...[
            Gap.v(10),
            Align(
              alignment: Alignment.centerRight,
              child: Tap3D(
                tapKey: actionKey,
                onTap: () => onFix!(),
                label: RingReadyStrings.openSettings,
                exclude: true,
                child: Container(
                  constraints: BoxConstraints(minHeight: DS.s(36)),
                  padding: EdgeInsets.symmetric(horizontal: DS.s(18), vertical: DS.s(6)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(18), boxShadow: DS.shadows(Form3D.glow(tone))),
                  child: Text(RingReadyStrings.openSettings, maxLines: 1, softWrap: false, style: Ink3D.text(13.5, FontWeight.w700, Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
