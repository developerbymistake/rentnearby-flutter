import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../social_safety_strings.dart';

class SafetyGuidelinesSheet extends StatefulWidget {
  const SafetyGuidelinesSheet({super.key, this.firstName = '', this.group = false, this.readOnly = false, this.accept});

  static const Key understoodKey = ValueKey('safety_understood');
  static const Key closeKey = ValueKey('safety_close');
  static const Key footerKey = ValueKey('safety_footer');
  static const Key rowsKey = ValueKey('safety_rows');

  final String firstName;
  final bool group;
  final bool readOnly;

  /// Returns null when the server saved the acceptance, else the message to show.
  final Future<String?> Function()? accept;

  /// true only when the person tapped Understood and the server saved it.
  /// Closing or swiping the sheet away returns false and nothing is sent.
  static Future<bool> ask(BuildContext context, {required String firstName, required bool group, required Future<String?> Function() accept}) async {
    final r = await SheetFrame.show<bool>(context, builder: (_) => SafetyGuidelinesSheet(firstName: firstName, group: group, accept: accept));
    return r == true;
  }

  static Future<void> showReadOnly(BuildContext context) => SheetFrame.show<void>(context, builder: (_) => const SafetyGuidelinesSheet(readOnly: true));

  static const List<({String art, String title, String line})> rows = [
    (art: ListingArt.moneyBag, title: SocialSafetyStrings.moneyTitle, line: SocialSafetyStrings.moneyLine),
    (art: ListingArt.locked, title: SocialSafetyStrings.detailsTitle, line: SocialSafetyStrings.detailsLine),
    (art: ListingArt.star, title: SocialSafetyStrings.kindTitle, line: SocialSafetyStrings.kindLine),
    (art: ListingArt.roundPushpin, title: SocialSafetyStrings.meetTitle, line: SocialSafetyStrings.meetLine),
    (art: ListingArt.alarmClock, title: SocialSafetyStrings.disappearTitle, line: SocialSafetyStrings.disappearLine),
  ];

  @override
  State<SafetyGuidelinesSheet> createState() => _SafetyGuidelinesSheetState();
}

class _SafetyGuidelinesSheetState extends State<SafetyGuidelinesSheet> {
  bool _busy = false;

  Future<void> _understood() async {
    final accept = widget.accept;
    if (_busy || accept == null) return;
    setState(() => _busy = true);
    final error = await accept();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
    AppToast.error(error);
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    final title = readOnly ? SocialSafetyStrings.tipsRow : (widget.group ? SocialSafetyStrings.groupTitle : SocialSafetyStrings.title(widget.firstName));
    return BuddySheet.frame(
      art: ListingArt.shield,
      title: title,
      subtitle: SocialSafetyStrings.intro,
      tone: ListingTone.indigo,
      closeEnabled: !_busy,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(SocialSafetyStrings.footer, key: SafetyGuidelinesSheet.footerKey, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0, height: 1.35)),
          Gap.v(12),
          GradientPillButton(
            key: readOnly ? SafetyGuidelinesSheet.closeKey : SafetyGuidelinesSheet.understoodKey,
            tone: ListingTone.indigo,
            label: readOnly ? SocialSafetyStrings.close : SocialSafetyStrings.understood,
            loading: _busy,
            onTap: readOnly ? () => Navigator.of(context).pop() : _understood,
          ),
        ],
      ),
      child: WhiteCard3D(
        key: SafetyGuidelinesSheet.rowsKey,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < SafetyGuidelinesSheet.rows.length; i++)
              IconRow3D(
                art: SafetyGuidelinesSheet.rows[i].art,
                title: SafetyGuidelinesSheet.rows[i].title,
                divider: i > 0,
                trailing: const SizedBox.shrink(),
                subtitleChild: Text(SafetyGuidelinesSheet.rows[i].line, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0, height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}
