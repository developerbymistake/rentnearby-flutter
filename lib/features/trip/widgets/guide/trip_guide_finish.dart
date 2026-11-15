import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';

class TripGuideFinish extends StatelessWidget {
  const TripGuideFinish({
    super.key,
    required this.onSummary,
    required this.onBack,
    required this.title,
    this.subtitle = '',
    this.stepText = '',
    this.arranged = true,
    this.percent,
    this.pendingNames = const [],
  });

  final bool arranged;
  final VoidCallback onSummary;
  final VoidCallback onBack;
  final String title;
  final String subtitle;
  final String stepText;
  final int? percent;
  final List<String> pendingNames;

  @override
  Widget build(BuildContext context) {
    final done = arranged && pendingNames.isEmpty;
    final tone = done ? ListingTone.forest : ListingTone.cF;
    final card = done
        ? WorkoutCard(
            tone: ListingTone.forest,
            art: ListingArt.luggage,
            eyebrow: TripStringsGuide.finishName,
            title: TripStringsGuide.finishTitle,
            subtitle: TripStringsGuide.finishBody,
            ctaLabel: TripStringsGuide.openSummary,
            trailing: WorkoutTrailing.ring,
            progress: 1,
            minHeight: DS.s(200),
            margin: DS.sym(h: 18),
            semanticsLabel: '${TripStringsGuide.finishTitle}. ${TripStringsGuide.openSummary}',
            onTap: onSummary,
          )
        : WorkoutCard(
            tone: ListingTone.cF,
            art: ListingArt.calendar,
            eyebrow: percent == null ? '' : TripStringsGuide.percent(percent!.clamp(0, 100)),
            title: TripStringsGuide.finishSavedTitle,
            subtitle: TripStringsGuide.finishSavedBody,
            ctaLabel: TripStringsGuide.seeStillToDo,
            minHeight: DS.s(170),
            margin: DS.sym(h: 18),
            semanticsLabel: '${TripStringsGuide.finishSavedTitle}. ${TripStringsGuide.seeStillToDo}',
            onTap: onSummary,
          );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DesignColors.scaffold, DesignColors.surface])),
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, DS.s(12), 0, DS.s(24) + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: DS.sym(h: 18),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: TripStringsGuide.previous,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: TripStringsGuide.previous,
                    excludeFromSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack,
                      child: Container(
                        width: DS.s(44),
                        height: DS.s(44),
                        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(14), boxShadow: DS.shadows(Ink3D.softShadow)),
                        child: Icon(Icons.chevron_left_rounded, size: DS.s(26), color: Ink3D.hint),
                      ),
                    ),
                  ),
                ),
                Gap.h(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, height: 1.3)),
                      if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
                if (stepText.isNotEmpty) ...[
                  Gap.h(10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: DS.s(96)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: DS.sym(h: 12, v: 5),
                        decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(14)),
                        child: Text(stepText, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, tone.text, letterSpacing: 0)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Gap.v(14 + 6 * scale),
          if (pendingNames.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(18), 0, DS.s(18), DS.gv(12)),
              child: Text(
                '${TripStringsGuide.pendingTag}: ${pendingNames.join(', ')}',
                style: Ink3D.text(13, FontWeight.w600, Ink3D.grey, letterSpacing: 0),
              ),
            ),
          card,
        ],
      ),
    );
  }
}
