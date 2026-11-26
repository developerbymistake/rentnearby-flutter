import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';

/// Back button, then the title with a small 3D icon in one row; optional trailing.
class IconTitleHeader extends StatelessWidget {
  const IconTitleHeader({super.key, required this.tone, required this.title, required this.art, required this.onBack, this.trailing});

  static const double button = 46;

  final ListingTone tone;
  final String title;
  final String art;
  final VoidCallback onBack;
  final Widget? trailing;

  static double heightFor(BuildContext context) => DS.s(10) + DS.s(button);

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(10), DS.s(18), 0),
      child: SizedBox(
        height: DS.s(button),
        child: Row(
          children: [
            ChatRoundButton3D(icon: Icons.chevron_left_rounded, onTap: onBack, tooltip: 'Back', tone: tone, size: button),
            Gap.h(12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, softWrap: false, style: Ink3D.text(narrow ? 24 : 28, FontWeight.w700, Ink3D.title, height: 1.2)),
                      ),
                    ),
                  ),
                  Gap.h(10),
                  ExcludeSemantics(child: RoundIconButton3D(key: const ValueKey('icon_title_art'), asset: art, size: button)),
                ],
              ),
            ),
            if (trailing != null) ...[Gap.h(12), trailing!],
          ],
        ),
      ),
    );
  }
}
