import 'package:flutter/material.dart';
import '../design/design.dart';

class DetailTitleRow extends StatelessWidget {
  final Color accent;
  final String tag;
  final IconData icon;
  final String title;
  final String caption;
  final String value;
  final String unit;
  final String? secondTag;
  final String? iconAsset;

  const DetailTitleRow({
    super.key,
    required this.accent,
    required this.tag,
    required this.icon,
    required this.title,
    required this.caption,
    required this.value,
    this.unit = '',
    this.secondTag,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final filledTag = Container(
      padding: DS.sym(h: 9, v: 3),
      decoration: BoxDecoration(color: accent, borderRadius: DS.circular(8)),
      child: Text(tag,
          style: FitnessAppTheme.caption.copyWith(
              fontSize: DS.f(11), fontWeight: FontWeight.w700, letterSpacing: 0.6, color: FitnessAppTheme.white)),
    );
    return LayoutBuilder(
        builder: (context, constraints) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (secondTag == null)
                    filledTag
                  else
                    Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [
                      filledTag,
                      Container(
                        padding: DS.sym(h: 9, v: 2),
                        decoration: BoxDecoration(
                          borderRadius: DS.circular(8),
                          border: Border.all(color: accent),
                        ),
                        child: Text(secondTag!,
                            style: FitnessAppTheme.caption.copyWith(
                                fontSize: DS.f(11), fontWeight: FontWeight.w700, letterSpacing: 0.4, color: accent)),
                      ),
                    ]),
                  Gap.v(6),
                  Row(children: [
                    if (iconAsset != null) TravelIcon(iconAsset!, size: 24) else Icon(icon, size: DS.s(22), color: accent),
                    SizedBox(width: DS.s(8)),
                    Flexible(
                      child: Text(title, style: FitnessAppTheme.headline.copyWith(fontSize: DS.f(22))),
                    ),
                  ]),
                ]),
              ),
              Gap.h(12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.caption
                          .copyWith(fontSize: DS.f(11), fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: value),
                        if (unit.isNotEmpty)
                          TextSpan(
                              text: unit,
                              style: TextStyle(fontFamily: FitnessAppTheme.fontName,
                                  fontSize: DS.f(11), fontWeight: FontWeight.w600, color: FitnessAppTheme.lightText)),
                      ]),
                      maxLines: 1,
                      softWrap: false,
                      style: FitnessAppTheme.title
                          .copyWith(fontSize: DS.f(20), fontWeight: FontWeight.w800, color: PickKit.gold, height: 1.2),
                    ),
                  ),
                ]),
              ),
            ]));
  }
}

class DetailChipRow extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String label;
  final double? distanceKm;
  final String? iconAsset;

  const DetailChipRow(
      {super.key, required this.accent, required this.icon, required this.label, this.distanceKm, this.iconAsset});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: DS.sym(h: 10, v: 4),
            decoration: BoxDecoration(color: accent.withValues(alpha: Alpha.v10), borderRadius: DS.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (iconAsset != null) TravelIcon(iconAsset!, size: 16) else Icon(icon, size: DS.s(13), color: accent),
              SizedBox(width: DS.s(5)),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: DS.f(12), fontWeight: FontWeight.w500, color: accent)),
              ),
            ]),
          ),
        ),
      ),
      if (distanceKm != null) ...[
        Gap.h(8),
        const TravelIcon(TravelIcon.place, size: 14),
        SizedBox(width: DS.s(4)),
        Text('${distanceKm!.toStringAsFixed(1)} km away', style: FitnessAppTheme.caption.copyWith(fontSize: DS.f(12))),
      ],
    ]);
  }
}
