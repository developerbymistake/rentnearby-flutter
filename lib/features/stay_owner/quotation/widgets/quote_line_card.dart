import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../model/quote_draft.dart';
import '../model/quote_money.dart';

abstract final class QuoteText {
  static TextStyle get head => TypeTokens.bodyStrong;
  static TextStyle get body => TypeTokens.body;
  static TextStyle get small => TypeTokens.caption;
  static TextStyle get label => TypeTokens.label;
  static TextStyle get amount => TypeTokens.bodyStrong;
  static TextStyle get total => TypeTokens.title.copyWith(color: StayLook.greenText);
  static TextStyle get error => FieldMessage.errorStyle;
  static TextStyle get hint => FieldMessage.helperStyle;
}

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, this.title, this.chip, this.child, this.margin, this.padding});

  final String? title;
  final Widget? chip;
  final Widget? child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? DS.insets(l: 18, t: 12, r: 18),
        padding: padding ?? DS.all(14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.tile), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: DS.insets(b: 8),
                child: Row(children: [
                  Expanded(child: Semantics(header: true, child: Text(title!, style: QuoteText.head))),
                  ?chip,
                ]),
              ),
            ?child,
          ],
        ),
      );
}

class QuoteSumRow extends StatelessWidget {
  const QuoteSumRow({super.key, required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.sym(v: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? QuoteText.head : QuoteText.body.copyWith(color: Ink3D.sub))),
          Text(value, style: strong ? QuoteText.total : QuoteText.amount),
        ]),
      );
}

class QuoteIconTap extends StatelessWidget {
  const QuoteIconTap({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: DS.s(40),
            height: DS.s(40),
            child: Center(
              child: Container(
                width: DS.s(28),
                height: DS.s(28),
                decoration: BoxDecoration(color: StayLook.rowLine, shape: BoxShape.circle),
                child: Icon(icon, size: DS.s(15), color: color ?? Ink3D.sub),
              ),
            ),
          ),
        ),
      );
}

class QuoteLineCard extends StatelessWidget {
  const QuoteLineCard({super.key, required this.line, required this.onEdit, required this.onRemove});

  final QuoteLine line;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        child: Container(
          padding: DS.sym(v: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: StayLook.rowLine, width: DS.s(1)))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.description, style: QuoteText.head),
                    Gap.v(2),
                    Text(StayQuoteStrings.lineSub(QuoteMoney.inr(line.rate), line.qty, line.nights), style: QuoteText.small),
                    Gap.v(3),
                    Text(QuoteMoney.inr(line.amount), style: QuoteText.amount),
                  ],
                ),
              ),
              QuoteIconTap(icon: Icons.edit_rounded, label: StayQuoteStrings.edit, color: StayLook.indigoText, onTap: onEdit),
              QuoteIconTap(icon: Icons.close_rounded, label: StayQuoteStrings.remove, onTap: onRemove),
            ],
          ),
        ),
      );
}

class QuoteChipTap extends StatelessWidget {
  const QuoteChipTap({super.key, required this.label, required this.onTap, this.on = false});

  final String label;
  final VoidCallback? onTap;
  final bool on;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: DS.circular(10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(36)),
            child: Center(
              widthFactor: 1,
              child: StaySoftChip(
                label: label,
                bg: on ? StayLook.greenSoft : StayLook.rowLine,
                fg: on ? StayLook.greenText : Ink3D.sub,
              ),
            ),
          ),
        ),
      );
}
