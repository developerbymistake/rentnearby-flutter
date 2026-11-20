import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/hub/hub_tokens.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../viewer_look.dart';
import '../viewer_strings.dart';

class ViewerHubCard extends StatelessWidget {
  const ViewerHubCard({super.key, required this.children, this.onTap});

  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = HubTokens.cardRadius(68);
    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: Container(
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: HubTokens.cardShadow),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: DesignColors.surface,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: DS.insets(l: 18, t: 20, r: 18, b: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewerCardTitle extends StatelessWidget {
  const ViewerCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(right: DS.s(50)),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, HubTokens.ink, height: 1.5, letterSpacing: 0)),
      );
}

class ViewerMetaRow extends StatelessWidget {
  const ViewerMetaRow({super.key, required this.badge, required this.tone, required this.line, this.bottom = 10});

  final String badge;
  final BuddyBadgeTone tone;
  final String line;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: DS.s(4), bottom: DS.s(bottom)),
        child: Wrap(
          spacing: DS.gh(8),
          runSpacing: DS.gv(4),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BuddyBadge(badge, tone: tone),
            Text(line, style: Ink3D.text(12, FontWeight.w400, HubTokens.grey, letterSpacing: 0)),
          ],
        ),
      );
}

class ViewerFootStrip extends StatelessWidget {
  const ViewerFootStrip({super.key, required this.small, required this.title, required this.onTap, this.rose = false, this.top = 14});

  final String small;
  final String title;
  final VoidCallback onTap;
  final bool rose;
  final double top;

  @override
  Widget build(BuildContext context) {
    final radius = HubTokens.cardRadius(30);
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(top)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: rose ? ViewerLook.roseGradient : ViewerLook.tealGradient,
          boxShadow: DS.shadows(rose ? ViewerLook.roseStrip : ViewerLook.tealStrip),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: DS.insets(l: 16, t: 13, r: 12, b: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(small, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, DesignColors.tint(DesignColors.surface, Alpha.v93), height: 1.5, letterSpacing: 0)),
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
                      ],
                    ),
                  ),
                  Gap.h(10),
                  Container(
                    width: DS.s(38),
                    height: DS.s(38),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ViewerLook.goBg, shape: BoxShape.circle, boxShadow: DS.shadows(ViewerLook.goShadow)),
                    child: Text(ViewerStrings.arrow, style: Ink3D.text(20, FontWeight.w400, rose ? ViewerLook.roseText : BuddyLook.tealEnd, height: 1, letterSpacing: 0)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewerBarState {
  const ViewerBarState(this.caption, this.fraction);

  final String caption;
  final double fraction;

  static ViewerBarState of(String state) => switch (state.toLowerCase()) {
        'booked' || 'completed' => const ViewerBarState(ViewerStrings.booked, 1),
        'arranging' => const ViewerBarState(ViewerStrings.arranging, 0.5),
        _ => const ViewerBarState(ViewerStrings.notAdded, 0),
      };
}

class ViewerBars extends StatelessWidget {
  const ViewerBars({super.key, required this.stay, required this.taxi});

  final ViewerBarState stay;
  final ViewerBarState taxi;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: DS.gv(6)),
        padding: EdgeInsets.only(top: DS.s(12)),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: HubTokens.line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Bar(label: ViewerStrings.stay, state: stay, from: ViewerLook.stayFrom, to: ViewerLook.stayTo)),
            Gap.h(10),
            Expanded(child: _Bar(label: ViewerStrings.taxi, state: taxi, from: ViewerLook.taxiFrom, to: ViewerLook.taxiTo)),
            Gap.h(10),
            Expanded(child: _Bar(label: ViewerStrings.plan, state: const ViewerBarState(ViewerStrings.saved, 1), from: ViewerLook.planFrom, to: ViewerLook.planTo)),
          ],
        ),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.state, required this.from, required this.to});

  final String label;
  final ViewerBarState state;
  final Color from;
  final Color to;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ink3D.text(11.5, FontWeight.w600, HubTokens.sub, height: 1.5, letterSpacing: 0)),
          Container(
            width: double.infinity,
            height: DS.s(6),
            margin: EdgeInsets.only(top: DS.gv(5), bottom: DS.gv(4)),
            decoration: BoxDecoration(color: HubTokens.trackBar, borderRadius: DS.circular(4)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.fraction,
              child: DecoratedBox(decoration: BoxDecoration(borderRadius: DS.circular(4), gradient: LinearGradient(colors: [from, to]))),
            ),
          ),
          Text(state.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w400, HubTokens.grey, height: 2, letterSpacing: 0)),
        ],
      );
}
