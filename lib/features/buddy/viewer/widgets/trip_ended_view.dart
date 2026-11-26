import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../viewer_look.dart';

class ViewerHalo extends StatelessWidget {
  const ViewerHalo({super.key, required this.art, this.color = ViewerLook.tealHalo});

  final String art;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: DS.s(120),
        height: DS.s(120),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: ExcludeSemantics(child: Art3D(asset: art, size: 92, shadowBlur: 6, shadowOffset: const Offset(5, 8))),
      );
}

class ViewerStateHero extends StatelessWidget {
  const ViewerStateHero({super.key, required this.art, this.haloColor = ViewerLook.tealHalo, this.small, required this.title, this.line, this.top = 24});

  final String art;
  final Color haloColor;
  final String? small;
  final String title;
  final String? line;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 26, t: top, r: 26),
        child: Column(
          children: [
            ViewerHalo(art: art, color: haloColor),
            if (small != null) ...[
              Gap.v(14),
              Text(small!, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0.6)),
            ],
            Padding(
              padding: EdgeInsets.only(top: DS.s(small == null ? 14 : 4)),
              child: Text(title, key: const ValueKey('viewer_state_title'), textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, ViewerLook.ink, height: 1.3, letterSpacing: 0)),
            ),
            if (line != null && line!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: DS.s(6)),
                child: Text(line!, key: const ValueKey('viewer_state_line'), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, ViewerLook.sub, height: 1.5, letterSpacing: 0)),
              ),
          ],
        ),
      );
}

class ViewerGhostCard extends StatelessWidget {
  const ViewerGhostCard({super.key, required this.title, required this.line});

  final String title;
  final String line;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: Alpha.v75,
        child: Container(
          key: const ValueKey('viewer_ghost'),
          margin: DS.insets(l: 18, t: 20, r: 18),
          padding: DS.sym(h: 18, v: 14),
          decoration: BoxDecoration(
            color: ViewerLook.ghostBg,
            borderRadius: DS.br(CardRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, ViewerLook.ghostTitle, letterSpacing: 0)),
              if (line.isNotEmpty) Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, ViewerLook.grey, letterSpacing: 0)),
            ],
          ),
        ),
      );
}

class TripEndedView extends StatelessWidget {
  const TripEndedView({super.key, required this.art, required this.haloColor, required this.title, this.line, this.ghostTitle, this.ghostLine = ''});

  final String art;
  final Color haloColor;
  final String title;
  final String? line;
  final String? ghostTitle;
  final String ghostLine;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewerStateHero(art: art, haloColor: haloColor, title: title, line: line, top: 60),
          if (ghostTitle != null && ghostTitle!.isNotEmpty) ViewerGhostCard(title: ghostTitle!, line: ghostLine),
        ],
      );
}
