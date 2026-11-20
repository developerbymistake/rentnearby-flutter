import 'package:flutter/material.dart';

import '../../../../design/extra/art_3d.dart';
import '../buddy_format.dart';
import '../buddy_look.dart';
import '../models/person_models.dart';
import '../strings_shared.dart';

class MoneyName extends StatelessWidget {
  const MoneyName({super.key, required this.person, this.showYou = true, this.style, this.maxLines = 1});

  final MoneyPerson person;
  final bool showYou;
  final TextStyle? style;
  final int maxLines;

  static List<InlineSpan> spans(MoneyPerson person, TextStyle base, {bool showYou = true}) {
    if (person.isDeleted) return [TextSpan(text: BuddyFormat.deletedName, style: base)];
    final light = base.copyWith(fontWeight: FontWeight.w400, color: BuddyLook.greyText);
    return [
      TextSpan(text: person.name, style: base),
      if (person.last4.isNotEmpty) TextSpan(text: ' ${person.last4}', style: light),
      if (showYou && person.isMe) TextSpan(text: ' ${BuddySharedStrings.you}', style: light),
      if (person.isFormer) TextSpan(text: ' ${BuddySharedStrings.left}', style: light),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? Ink3D.text(15, FontWeight.w600, Ink3D.title);
    return Text.rich(
      TextSpan(children: spans(person, base, showYou: showYou)),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
