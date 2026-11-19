import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

ListingTone tripListTone(KitTone tone) => identical(tone, KitTone.taxi) ? ListingTone.coral : ListingTone.forest;

class TripListTopBar extends StatelessWidget {
  const TripListTopBar({
    super.key,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.skipLabel,
    this.onSkip,
  });

  final ListingTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String? skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final skip = skipLabel;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: DS.gv(6)),
      child: TopBar3D(
        tone: tone,
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        trailing: skip == null ? null : TripSkipPill(label: skip, onTap: onSkip, tone: tone),
      ),
    );
  }
}

class TripSkipPill extends StatelessWidget {
  const TripSkipPill({super.key, required this.label, required this.onTap, required this.tone});

  final String label;
  final VoidCallback? onTap;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: PressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(46), minWidth: DS.s(46)),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: DS.sym(h: 16, v: 10),
                decoration: BoxDecoration(color: DesignColors.surface,borderRadius: DS.circular(22), boxShadow: DS.shadows(Ink3D.softShadow)),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, tone.text, letterSpacing: 0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
