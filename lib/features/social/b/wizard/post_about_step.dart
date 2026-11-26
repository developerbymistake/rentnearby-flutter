import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../shared/social_formats.dart';
import '../models/post_draft.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'post_trip_controller.dart';
import 'post_wizard_parts.dart';

class PostAboutStep extends StatefulWidget {
  const PostAboutStep({super.key, required this.c});

  final PostTripController c;

  static const Key textKey = ValueKey('post_text');
  static const Key editKey = ValueKey('post_edit_answers');
  static const Key tipsKey = ValueKey('post_write_tips');
  static const Key chipsKey = ValueKey('post_about_chips');

  @override
  State<PostAboutStep> createState() => _PostAboutStepState();
}

class _PostAboutStepState extends State<PostAboutStep> {
  late final TextEditingController _text = TextEditingController(text: widget.c.draft.value.text);
  Worker? _sync;

  PostTripController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _sync = ever<PostDraft>(c.draft, (d) {
      if (_text.text != d.text) {
        _text.value = TextEditingValue(text: d.text, selection: TextSelection.collapsed(offset: d.text.length));
      }
    });
  }

  @override
  void dispose() {
    _sync?.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _tips() async {
    final line = await Sheet3D.show<String>(
      context,
      builder: (s) => Sheet3D(
        tone: ListingTone.indigo,
        title: SocialStringsB.writeTipsTitle,
        subtitle: SocialStringsB.writeTipsBody,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < SocialStringsB.writeTips.length; i++) ...[
              if (i > 0) Gap.v(10),
              Tap3D(
                tapKey: ValueKey('post_tip_$i'),
                onTap: () => Navigator.of(s).pop(SocialStringsB.writeTips[i]),
                label: SocialStringsB.writeTips[i],
                exclude: true,
                child: Container(
                  padding: DS.sym(h: 14, v: 12),
                  decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.br(CardRadius.card)),
                  child: Text(SocialStringsB.writeTips[i], style: Ink3D.text(14, FontWeight.w400, Ink3D.body, height: 1.4, letterSpacing: 0)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (line != null) c.addLine(line);
  }

  Widget _summary(PostDraft d) {
    final first = d.cities.isEmpty ? null : d.cities.first;
    final seed = SocialLookB.seedOf(first?.cityKey ?? 0, d.cityLine);
    final line = '${SocialFormats.days(d.days)} · ${SocialStringsB.whenLower(d.whenKind, d.withinMonths, d.startDate)} · ${SocialStringsB.whoLower(d.joinGender)}';
    return Container(
      margin: DS.gapInsets(l: 18, t: 8, r: 18),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Tap3D(
        tapKey: PostAboutStep.editKey,
        onTap: () => c.goTo(PostTripController.stepWhen),
        label: SocialStringsB.editAnswers,
        exclude: true,
        child: Padding(
          padding: DS.insets(l: 14, t: 10, r: 14, b: 10),
          child: Row(
            children: [
              Container(
                width: DS.s(52),
                height: DS.s(52),
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: SocialLookB.toneOf(seed).gradient, borderRadius: DS.circular(10)),
                child: TripCoverArt(cityKey: first?.cityKey ?? 0, seed: seed, size: 38),
              ),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.cityLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, size: DS.s(20), color: ListingTone.indigo.g2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = c.draft.value;
      final chips = c.postChips;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WizardQuestion(title: SocialStringsB.aboutTitle, sub: SocialStringsB.aboutSub),
          _summary(d),
          Container(
            margin: DS.gapInsets(l: 18, t: 12, r: 18),
            padding: DS.insets(l: 16, t: 14, r: 16, b: 12),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), border: Border.all(color: BuddyLook.tealStart, width: DS.s(2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: PostAboutStep.textKey,
                  controller: _text,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: c.setText,
                  inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(PostDraft.maxText)],
                  style: Ink3D.text(15, FontWeight.w400, Ink3D.body, height: 1.5, letterSpacing: 0),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                Gap.v(10),
                Row(
                  children: [
                    Tap3D(
                      tapKey: PostAboutStep.tipsKey,
                      onTap: _tips,
                      label: SocialStringsB.whatToWrite,
                      exclude: true,
                      child: Text(SocialStringsB.whatToWrite, style: Ink3D.text(12.5, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0).copyWith(decoration: TextDecoration.underline)),
                    ),
                    const Spacer(),
                    Text(SocialStringsB.counter(d.text.characters.length, PostDraft.maxText), style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ],
            ),
          ),
          if (d.text.trim().isEmpty) WizardNote(text: SocialStringsB.textRequired),
          SmallLabel(text: SocialStringsB.addToPost, padding: DS.gapInsets(l: 22, t: 16, r: 22, b: 10)),
          Padding(
            padding: DS.insets(l: 18, r: 18),
            child: Wrap(
              key: PostAboutStep.chipsKey,
              spacing: DS.gh(10),
              runSpacing: DS.gv(10),
              children: [
                for (final chip in chips)
                  SocialPickChip(
                    key: ValueKey('post_chip_$chip'),
                    label: chip,
                    selected: d.chips.contains(chip),
                    trailing: d.chips.contains(chip) ? Icons.check_rounded : null,
                    onTap: () => c.toggleChip(chip),
                  ),
              ],
            ),
          ),
          WizardNote(text: SocialStringsB.aboutNote(c.limits)),
        ],
      );
    });
  }
}
