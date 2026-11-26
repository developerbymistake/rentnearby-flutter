import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_chat.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/segment_tabs.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_nav.dart';
import '../models/post_draft.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'post_trip_controller.dart';
import 'post_wizard_parts.dart';

class PostWhenStep extends StatelessWidget {
  const PostWhenStep({super.key, required this.c});

  final PostTripController c;

  static const Key howLongKey = ValueKey('post_how_long');
  static const Key withinKey = ValueKey('post_within');
  static const Key calendarKey = ValueKey('post_pick_calendar');
  static const Key genderLockKey = ValueKey('post_gender_lock');
  static const Key whoKey = ValueKey('post_who');

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickCalendar(BuildContext context) async {
    final today = _today();
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: c.draft.value.startDate ?? today,
      first: today,
      last: today.add(const Duration(days: PostDraft.startAheadDays)),
      label: SocialStringsB.startDate,
    );
    if (picked != null) c.setDate(picked);
  }

  Future<void> _pickDays(BuildContext context) async {
    final current = c.draft.value.days;
    final picked = await Sheet3D.show<int>(
      context,
      builder: (s) => Sheet3D(
        tone: ListingTone.indigo,
        title: SocialStringsB.howLong,
        subtitle: SocialStringsB.howLongSub,
        child: Wrap(
          spacing: DS.gh(10),
          runSpacing: DS.gv(10),
          children: [
            for (var d = 1; d <= SocialFormats.moreDays; d++)
              SocialPickChip(key: ValueKey('post_days_$d'), label: SocialStringsB.daysOption(d), selected: d == current, onTap: () => Navigator.of(s).pop(d)),
          ],
        ),
      ),
    );
    if (picked != null) c.setDays(picked);
  }

  // Spec 23.8: the month window is one dropdown row like How long?, the options open in the same sheet look.
  Future<void> _pickMonths(BuildContext context) async {
    final current = c.draft.value.withinMonths;
    final picked = await Sheet3D.show<int>(
      context,
      builder: (s) => Sheet3D(
        tone: ListingTone.indigo,
        title: SocialStringsB.withinTheNext,
        subtitle: SocialStringsB.withinSub(PostDraft.maxMonths),
        child: Wrap(
          spacing: DS.gh(10),
          runSpacing: DS.gv(10),
          children: [
            for (var n = 1; n <= PostDraft.maxMonths; n++)
              SocialPickChip(key: ValueKey('post_months_$n'), label: SocialStringsB.monthsChip(n), selected: n == current, onTap: () => Navigator.of(s).pop(n)),
          ],
        ),
      ),
    );
    if (picked != null) c.setMonths(picked);
  }

  Widget _label(String text) => SmallLabel(text: text, padding: DS.gapInsets(l: 22, t: 16, r: 22, b: 8));

  Widget _dateStrip(BuildContext context, DateTime? selected) {
    final today = _today();
    final tone = ListingTone.indigo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: DS.insets(l: 18, t: 14, r: 18, b: 4),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) Gap.h(9),
                Builder(builder: (_) {
                  final day = today.add(Duration(days: i));
                  final on = selected != null && selected.year == day.year && selected.month == day.month && selected.day == day.day;
                  final fg = on ? DesignColors.onPrimary : Ink3D.body;
                  return Tap3D(
                    tapKey: ValueKey('post_date_$i'),
                    onTap: () => c.setDate(day),
                    selected: on,
                    label: '${i == 0 ? SocialStringsB.today : _weekdays[day.weekday - 1]} ${day.day}',
                    exclude: true,
                    child: Container(
                      width: DS.s(62),
                      padding: DS.sym(v: 8),
                      decoration: BoxDecoration(
                        gradient: on ? tone.gradient : null,
                        color: on ? null : DesignColors.surface,
                        borderRadius: DS.br(CardRadius.card),
                        boxShadow: on ? tone.glow(blur: 0, dy: 4) : DS.shadows(Form3D.cardShadow),
                      ),
                      child: Column(
                        children: [
                          Text(i == 0 ? SocialStringsB.today : _weekdays[day.weekday - 1], maxLines: 1, style: Ink3D.text(12.5, FontWeight.w400, fg, letterSpacing: 0)),
                          Text('${day.day}', maxLines: 1, style: Ink3D.text(20, FontWeight.w700, fg, letterSpacing: 0)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        Tap3D(
          tapKey: calendarKey,
          onTap: () => _pickCalendar(context),
          label: SocialStringsB.pickFromCalendar,
          exclude: true,
          child: Padding(
            padding: DS.gapInsets(l: 22, t: 8, r: 22, b: 4),
            child: Text(
              selected == null || selected.difference(today).inDays < 6 ? SocialStringsB.pickFromCalendar : '${selected.day} ${SocialFormats.monthName(selected.month)} · ${SocialStringsB.pickFromCalendar}',
              style: Ink3D.text(14, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }

  // One row family for both dropdown choices of the step (Within the next, How long?): same card, width, edge and gaps.
  Widget _pickRow({required Key key, required String title, required String sub, required String value, required VoidCallback onTap}) => Container(
        margin: DS.gapInsets(l: 18, t: 16, r: 18),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
        child: Tap3D(
          tapKey: key,
          onTap: onTap,
          label: '$title $value',
          exclude: true,
          child: Padding(
            padding: DS.insets(l: 16, t: 12, r: 12, b: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Text(sub, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
                Container(
                  padding: DS.sym(h: 14, v: 8),
                  decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.br(CardRadius.card)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(value, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Gap.h(6),
                      Icon(Icons.expand_more_rounded, size: DS.s(20), color: Ink3D.sub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _lockBox() => Container(
        key: genderLockKey,
        margin: DS.gapInsets(l: 18, t: 14, r: 18),
        padding: DS.insets(l: 14, t: 12, r: 16, b: 12),
        decoration: BoxDecoration(color: ChatLook3D.bannerFill, borderRadius: DS.br(CardRadius.card), border: Border.all(color: DesignColors.amberNoteBorder, width: DS.s(1.5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.star, size: 26, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
            Gap.h(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${SocialStringsB.genderLockTitle} ', style: Ink3D.text(13.5, FontWeight.w600, ChatLook3D.bannerText, height: 1.5, letterSpacing: 0)),
                    TextSpan(text: SocialStringsB.genderLockBody, style: Ink3D.text(13.5, FontWeight.w400, ChatLook3D.bannerText, height: 1.5, letterSpacing: 0)),
                  ])),
                  Tap3D(
                    tapKey: const ValueKey('post_gender_see_plus'),
                    onTap: () => SocialNav.openPlus(from: 'genderOnly'),
                    label: SocialStringsB.seePlus,
                    exclude: true,
                    child: Padding(
                      padding: DS.insets(t: 4, b: 2),
                      child: Text(SocialStringsB.seePlus, style: Ink3D.text(13.5, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0).copyWith(decoration: TextDecoration.underline)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = c.draft.value;
      final locked = c.genderLocked.value;
      final whoIndex = SocialStringsB.joinCodes.indexOf(d.joinGender);
      final city = d.cities.isEmpty ? '' : d.cities.first.name;
      final seatIndex = SocialStringsB.seatValues.indexOf(d.seats);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WizardQuestion(title: SocialStringsB.whenTitle(city), sub: SocialStringsB.whenSub),
          SegmentTabs(
            key: const ValueKey('post_when_kind'),
            labels: const [SocialStringsB.roughly, SocialStringsB.exactDate],
            selected: d.isExact ? 1 : 0,
            tone: ListingTone.indigo,
            margin: DS.gapInsets(l: 18, t: 8, r: 18),
            onTap: (i) => c.setWhenKind(i == 1 ? PostDraft.exact : PostDraft.within),
          ),
          if (!d.isExact) ...[
            _pickRow(
              key: withinKey,
              title: SocialStringsB.withinTheNext,
              sub: SocialStringsB.withinSub(PostDraft.maxMonths),
              value: SocialStringsB.monthsChip(d.withinMonths),
              onTap: () => _pickMonths(context),
            ),
            WizardNote(text: SocialStringsB.windowNote),
          ] else
            _dateStrip(context, d.startDate),
          _pickRow(key: howLongKey, title: SocialStringsB.howLong, sub: SocialStringsB.howLongSub, value: SocialFormats.days(d.days), onTap: () => _pickDays(context)),
          _label(SocialStringsB.whoCanJoin),
          SegmentTabs(
            key: whoKey,
            labels: SocialStringsB.joinLabels,
            selected: whoIndex < 0 ? 0 : whoIndex,
            tone: ListingTone.indigo,
            locked: c.canWomenOnly ? const {} : const {SocialStringsB.womenIndex},
            margin: DS.insets(l: 18, r: 18),
            onTap: (i) => c.setJoinGender(SocialStringsB.joinCodes[i]),
          ),
          if (locked) _lockBox(),
          _label(SocialStringsB.seats),
          SegmentTabs(
            key: const ValueKey('post_seats'),
            labels: SocialStringsB.seatLabels,
            selected: seatIndex < 0 ? 2 : seatIndex,
            tone: ListingTone.indigo,
            margin: DS.insets(l: 18, r: 18),
            onTap: (i) => c.setSeats(SocialStringsB.seatValues[i]),
          ),
        ],
      );
    });
  }
}
