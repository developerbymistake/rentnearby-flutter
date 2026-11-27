import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/scan/scan_rules.dart';
import '../social_strings_a.dart';

class UsernameEntrySheet extends StatefulWidget {
  const UsernameEntrySheet({super.key});

  static const Key fieldKey = ValueKey('username_entry_field');
  static const Key findKey = ValueKey('username_entry_find');

  static Future<String?> show(BuildContext context) => SheetFrame.show<String>(context, builder: (_) => const UsernameEntrySheet());

  @override
  State<UsernameEntrySheet> createState() => _UsernameEntrySheetState();
}

class _UsernameEntrySheetState extends State<UsernameEntrySheet> {
  final _ctrl = TextEditingController();
  bool _bad = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final username = ScanRules.normalize(_ctrl.text);
    if (!ScanRules.isBakhliUsername(username)) {
      setState(() => _bad = true);
      return;
    }
    Navigator.of(context).pop(username);
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: SocialStringsA.findByUsername,
        subtitle: SocialStringsA.findByUsernameLine,
        tone: ListingTone.indigo,
        footer: GradientPillButton(key: UsernameEntrySheet.findKey, tone: ListingTone.indigo, label: SocialStringsA.find, onTap: _submit),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetSearchField(
              key: UsernameEntrySheet.fieldKey,
              tone: ListingTone.indigo,
              controller: _ctrl,
              hint: SocialStringsA.usernameHint,
              leadingArt: ListingArt.search,
              autofocus: true,
              inputFormatters: noEmojiInputFormatters,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                if (_bad) setState(() => _bad = false);
              },
              onSubmitted: (_) => _submit(),
              margin: DS.gapInsets(t: 6),
            ),
            if (_bad)
              Padding(
                padding: DS.gapInsets(l: 4, t: 8),
                child: Text(SocialStringsA.usernameBad, style: Ink3D.text(12.5, FontWeight.w400, Form3D.errorText, letterSpacing: 0)),
              ),
          ],
        ),
      );
}
