import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../expense_look.dart';

enum FieldTone { normal, on, bad, ok }

abstract final class ExpenseShape {
  static BorderRadius corner(double tr) => DS.br(tr >= 36 ? CardRadius.hero : tr >= 26 ? CardRadius.tile : CardRadius.card);

  static Color border(FieldTone t) => switch (t) {
        FieldTone.on => ExpenseLook.fieldOn,
        FieldTone.bad => ExpenseLook.fieldBad,
        FieldTone.ok => ExpenseLook.okBorder,
        FieldTone.normal => ExpenseLook.fieldBorder,
      };

  static List<BoxShadow> card() => BuddyLook.cardShadows(DS.size);
}

class ExpenseFieldLabel extends StatelessWidget {
  const ExpenseFieldLabel(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 2, t: 10, r: 2, b: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w700, ExpenseLook.label, letterSpacing: 0))),
            if (hint != null) Text(hint!, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );
}

class ExpenseFieldBox extends StatelessWidget {
  const ExpenseFieldBox({super.key, required this.child, this.tone = FieldTone.normal, this.tall = false, this.onTap, this.label, this.tapKey});

  final Widget child;
  final FieldTone tone;
  final bool tall;
  final VoidCallback? onTap;
  final String? label;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      constraints: BoxConstraints(minHeight: DS.s(tall ? 50 : 44)),
      padding: DS.sym(h: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: ExpenseShape.corner(24),
        border: Border.all(color: ExpenseShape.border(tone), width: DS.s(2)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Tap3D(tapKey: tapKey, onTap: onTap, label: label, exclude: label != null, child: box);
  }
}

class ExpenseLine extends StatelessWidget {
  const ExpenseLine(this.text, {super.key, this.tone = FieldLineTone.bad});

  static const String tick = '✔';

  final String text;
  final FieldLineTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      FieldLineTone.bad => BuddyLook.dangerText,
      FieldLineTone.ok => ExpenseLook.okText,
      FieldLineTone.rose => BuddyLook.roseEnd,
    };
    return Padding(
      padding: DS.insets(l: 4, t: 8, r: 4),
      child: Semantics(
        liveRegion: tone == FieldLineTone.bad,
        label: text,
        excludeSemantics: true,
        child: text.startsWith(tick)
            ? Row(children: [
                Icon(Icons.check_rounded, size: DS.s(15), color: color),
                Gap.h(4),
                Flexible(child: Text(text.substring(tick.length).trimLeft(), style: Ink3D.text(12.5, FontWeight.w700, color, letterSpacing: 0))),
              ])
            : Text(text, style: Ink3D.text(12.5, FontWeight.w700, color, letterSpacing: 0)),
      ),
    );
  }
}

enum FieldLineTone { bad, ok, rose }

class ExpenseStrip extends StatelessWidget {
  const ExpenseStrip({super.key, required this.child, this.amber = false, this.action});

  final Widget child;
  final bool amber;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.insets(t: 12, b: 2),
        padding: DS.insets(l: 16, t: 10, r: action == null ? 16 : 12, b: 10),
        decoration: BoxDecoration(color: amber ? ExpenseLook.amberBg : ExpenseLook.dangerBg, borderRadius: ExpenseShape.corner(24)),
        child: Row(children: [Expanded(child: child), if (action != null) ...[Gap.h(10), action!]]),
      );
}

class ExpenseArtTile extends StatelessWidget {
  const ExpenseArtTile({super.key, required this.asset, this.size = 44, this.art = 38});

  final String asset;
  final double size;
  final double art;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: DS.s(size),
        height: DS.s(size),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: ExpenseLook.roseTint, borderRadius: DS.circular(14)))),
            Positioned(
              left: DS.s(4),
              top: -DS.s(2),
              child: ExcludeSemantics(child: Art3D(asset: asset, size: art, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
            ),
          ],
        ),
      );
}
