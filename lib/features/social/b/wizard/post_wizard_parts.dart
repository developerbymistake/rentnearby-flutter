import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../widgets/social_widgets_b.dart';

class WizardQuestion extends StatelessWidget {
  const WizardQuestion({super.key, required this.title, required this.sub});

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.gapInsets(l: 22, t: 18, r: 22, b: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0))),
            Gap.v(4),
            Text(sub, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );
}

class WizardNote extends StatelessWidget {
  const WizardNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.gapInsets(l: 22, t: 12, r: 22),
        child: Text(text, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, height: 1.45, letterSpacing: 0)),
      );
}

class WizardHeader extends StatelessWidget {
  const WizardHeader({super.key, required this.title, required this.tabs, required this.step, required this.saved, required this.savedLabel, required this.onClose, required this.closeLabel});

  final String title;
  final List<String> tabs;
  final int step;
  final bool saved;
  final String savedLabel;
  final VoidCallback onClose;
  final String closeLabel;

  static const Key closeKey = ValueKey('post_wizard_close');

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), MediaQuery.paddingOf(context).top + DS.s(10), DS.s(18), DS.s(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(label: closeLabel, button: true, excludeSemantics: true, child: KitRoundButton(key: closeKey, icon: Icons.close_rounded, onTap: onClose)),
              Gap.h(8),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
              if (saved)
                Row(
                  key: const ValueKey('post_draft_saved'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: DS.s(16), color: SocialLookB.seatsText),
                    Gap.h(4),
                    Text(savedLabel, style: Ink3D.text(12.5, FontWeight.w600, SocialLookB.seatsText, letterSpacing: 0)),
                  ],
                ),
            ],
          ),
          Gap.v(14),
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: DS.s(5),
                        decoration: BoxDecoration(color: i <= step ? tone.g2 : Form3D.todo, borderRadius: DS.circular(3)),
                      ),
                      Gap.v(8),
                      Row(
                        children: [
                          if (i < step) ...[Icon(Icons.check_rounded, size: DS.s(15), color: SocialLookB.seatsText), Gap.h(4)],
                          Flexible(
                            child: Text(
                              tabs[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ink3D.text(14, i == step ? FontWeight.w600 : FontWeight.w500, i == step ? Ink3D.title : Ink3D.sub, letterSpacing: 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class WizardBottomBar extends StatelessWidget {
  const WizardBottomBar({super.key, required this.label, required this.onNext, this.onBack, this.backLabel = '', this.teal = false, this.loading = false});

  final String label;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String backLabel;
  final bool teal;
  final bool loading;

  static const Key nextKey = ValueKey('post_wizard_next');
  static const Key backKey = ValueKey('post_wizard_back');

  @override
  Widget build(BuildContext context) {
    final tone = teal ? ListingTone.teal : ListingTone.indigo;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(12), DS.s(18), DS.s(16) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: DesignColors.surface, boxShadow: DS.shadows(Ink3D.topEdge)),
      child: Row(
        children: [
          if (onBack != null) ...[
            Semantics(label: backLabel, button: true, excludeSemantics: true, child: KitRoundButton(key: backKey, icon: Icons.chevron_left_rounded, onTap: onBack, size: 48)),
            Gap.h(12),
          ],
          Expanded(child: GradientPillButton(key: nextKey, tone: tone, label: label, loading: loading, enabled: onNext != null, onTap: onNext)),
        ],
      ),
    );
  }
}
