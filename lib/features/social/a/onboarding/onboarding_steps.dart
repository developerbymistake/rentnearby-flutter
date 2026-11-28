import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/profile_photo_strings.dart';
import '../../../../controllers/profile_photo_controller.dart';
import '../../../../design/design.dart';
import '../../../../design/extra/ext_auth.dart';
import '../../../../utils/input_formatters.dart';
import '../../../../widgets/profile_photo_circle.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../b/social_strings_b.dart';
import '../../shared/social_formats.dart';
import '../edit/home_city_sheet.dart';
import '../edit/place_picker_sheet.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import 'onboarding_controller.dart';

class OnboardingStepDots extends StatelessWidget {
  const OnboardingStepDots({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final white = DesignColors.onPrimary;
    final children = <Widget>[];
    for (var i = 0; i < OnboardingController.stepCount; i++) {
      final done = i < step;
      final current = i == step;
      children.add(Container(
        key: ValueKey('ob_dot_$i'),
        width: DS.s(30),
        height: DS.s(30),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || current ? white : white.withValues(alpha: Alpha.v25),
          boxShadow: current ? [BoxShadow(color: white.withValues(alpha: Alpha.scrim), spreadRadius: DS.s(4))] : null,
        ),
        child: done
            ? Icon(Icons.check_rounded, size: DS.s(16), color: ListingTone.indigo.g2)
            : Text('${i + 1}', style: Ink3D.text(13, FontWeight.w700, current ? BuddyLook.indigoText : white, letterSpacing: 0)),
      ));
      if (i < OnboardingController.stepCount - 1) {
        children.add(Expanded(
          child: Container(
            height: DS.s(3),
            margin: DS.sym(h: 4),
            decoration: BoxDecoration(color: i < step ? white : white.withValues(alpha: Alpha.v30), borderRadius: DS.circular(2)),
          ),
        ));
      }
    }
    return Semantics(
      label: SocialStringsA.stepOf(step + 1, OnboardingController.stepCount),
      child: ExcludeSemantics(child: Row(children: children)),
    );
  }
}

class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, this.step = 0, this.onBack, this.onMenu, this.title = SocialStringsA.obTitle, this.subtitle, this.showSteps = true});

  final int step;
  final VoidCallback? onBack;
  final void Function(Rect anchor)? onMenu;
  final String title;
  final String? subtitle;
  final bool showSteps;

  static const double edge = 18;
  static const double cardGap = 24;
  static const double buttonSize = 46;
  static const Key backKey = ValueKey('ob_back');
  static const Key menuKey = ValueKey('ob_menu');
  static const Key titleKey = ValueKey('ob_title');

  static String subtitleOf(int step) => switch (step) {
        0 => SocialStringsA.obStep1,
        1 => SocialStringsA.obStep2,
        _ => SocialStringsA.obStep3,
      };

  Widget _round(Color white, {required Key key, required IconData icon, required String label, required VoidCallback onTap}) => Tap3D(
        tapKey: key,
        onTap: onTap,
        label: label,
        exclude: true,
        child: Container(
          width: DS.s(buttonSize),
          height: DS.s(buttonSize),
          decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v25)),
          child: Icon(icon, size: DS.s(icon == Icons.more_vert_rounded ? 24 : 28), color: white),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final white = DesignColors.onPrimary;
    final back = onBack;
    final menu = onMenu;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(edge), MediaQuery.paddingOf(context).top + DS.s(14), DS.s(edge), DS.s(22)),
      decoration: BoxDecoration(
        gradient: ListingTone.indigo.gradient,
        borderRadius: DS.br(const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (back != null) ...[
                _round(white, key: backKey, icon: Icons.chevron_left_rounded, label: SocialStringsB.back, onTap: back),
                Gap.h(12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, key: titleKey, style: Ink3D.text(24, FontWeight.w700, white, height: 1.15, letterSpacing: 0)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: DS.s(4)),
                      child: Text(subtitle ?? subtitleOf(step), style: Ink3D.text(14, FontWeight.w400, white.withValues(alpha: Alpha.v92), letterSpacing: 0)),
                    ),
                  ],
                ),
              ),
              if (menu != null)
                Builder(
                  builder: (ctx) => _round(white, key: menuKey, icon: Icons.more_vert_rounded, label: SocialStringsA.obMenu, onTap: () {
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box == null || !box.hasSize) return;
                    menu(box.localToGlobal(Offset.zero) & box.size);
                  }),
                ),
            ],
          ),
          if (showSteps) ...[
            Gap.v(16),
            OnboardingStepDots(step: step),
          ],
        ],
      ),
    );
  }
}

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.insets(l: OnboardingHeader.edge, r: OnboardingHeader.edge),
        padding: DS.insets(l: 16, t: 18, r: 16, b: 20),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: AuthInk.cardRadius, boxShadow: AuthInk.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class OnboardingFieldLabel extends StatelessWidget {
  const OnboardingFieldLabel(this.text, {super.key, this.top = true});

  final String text;
  final bool top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(4), top ? DS.gv(20) : 0, DS.s(4), DS.gv(10)),
        child: Text(text, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub)),
      );
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.text, required this.count, required this.ok, this.top = true});

  final String text;
  final String count;
  final bool ok;
  final bool top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(4), top ? DS.gv(20) : 0, DS.s(4), DS.gv(10)),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub))),
            Text(count, style: Ink3D.text(12.5, FontWeight.w600, ok ? TagChip.colorsOf(TagKind.place).$2 : AuthInk.warn, letterSpacing: 0)),
          ],
        ),
      );
}

class SelectPill extends StatelessWidget {
  const SelectPill({super.key, required this.text, required this.hint, required this.onTap, this.pillKey, this.leadingArt});

  final String? text;
  final String hint;
  final VoidCallback onTap;
  final Key? pillKey;
  final String? leadingArt;

  @override
  Widget build(BuildContext context) {
    final v = text;
    return Tap3D(
      tapKey: pillKey,
      onTap: onTap,
      label: v ?? hint,
      exclude: true,
      child: Container(
        height: DS.s(60),
        padding: DS.sym(h: 20),
        decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(30)),
        child: Row(
          children: [
            if (leadingArt != null) ...[
              ExcludeSemantics(child: Art3D(asset: leadingArt!, size: 18, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
              Gap.h(8),
            ],
            Expanded(
              child: Text(v ?? hint,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: v == null ? AuthPillInput.hintStyle : AuthPillInput.nameStyle),
            ),
            Icon(Icons.expand_more_rounded, size: DS.s(22), color: Form3D.hint),
          ],
        ),
      ),
    );
  }
}

abstract final class ChoiceSheet {
  static Future<T?> pick<T>(BuildContext context, {required String title, required List<T> values, required String Function(T) label, T? selected}) =>
      BuddySheet.show<T>(
        context,
        title: title,
        art: ListingArt.calendar,
        builder: (c) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final v in values)
              Tap3D(
                onTap: () => Navigator.of(c).pop(v),
                label: label(v),
                selected: v == selected,
                exclude: true,
                child: Padding(
                  padding: DS.sym(h: 6, v: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label(v),
                            style: Ink3D.text(16, v == selected ? FontWeight.w700 : FontWeight.w500, v == selected ? BuddyLook.indigoText : Ink3D.title, letterSpacing: 0)),
                      ),
                      if (v == selected) Icon(Icons.check_rounded, size: DS.s(20), color: BuddyLook.indigoText),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class GenderCards extends StatelessWidget {
  const GenderCards({super.key, required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Row(
      children: [
        for (var i = 0; i < SocialStringsA.genders.length; i++) ...[
          if (i > 0) Gap.h(12),
          Expanded(child: _card(SocialStringsA.genders[i], tone)),
        ],
      ],
    );
  }

  Widget _card(String g, ListingTone tone) {
    final on = g == selected;
    return Tap3D(
      tapKey: ValueKey('ob_gender_$g'),
      onTap: () => onPick(g),
      label: g,
      selected: on,
      exclude: true,
      child: Container(
        height: DS.s(112),
        padding: EdgeInsets.only(bottom: DS.s(10)),
        decoration: BoxDecoration(
          gradient: on ? tone.gradient : null,
          color: on ? null : Form3D.fill,
          borderRadius: DS.br(CardRadius.card),
          boxShadow: on ? tone.glow(blur: 10, dy: 6) : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ExcludeSemantics(child: Art3D(asset: SocialArtA.gender(g), size: 58, shadowBlur: 4, shadowOffset: const Offset(3, 5))),
                Gap.v(6),
                Text(g, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.body, letterSpacing: 0)),
              ],
            ),
            if (on)
              Positioned(
                right: DS.s(8),
                top: DS.s(8),
                child: Container(
                  width: DS.s(26),
                  height: DS.s(26),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.surface, boxShadow: DS.shadows(Form3D.badge)),
                  child: Icon(Icons.check_rounded, size: DS.s(16), color: tone.g2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Step 1 photo: dashed circle on the left, "Add a photo" + why on the right. Tap = [onTap] (a failed upload re-picks).
class OnboardingPhotoRow extends StatelessWidget {
  const OnboardingPhotoRow({super.key, required this.controller, required this.onTap, this.url});

  final ProfilePhotoController controller;
  final VoidCallback onTap;
  final String? url;

  static final ListingTone _tone = ListingTone.indigo;
  static const double _photo = 96;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final local = controller.localPath.value;
      final busy = controller.busy.value;
      final failed = controller.failed.value && local != null;
      final outer = DS.s(_photo + _gap * 2);
      return Semantics(
        button: true,
        enabled: !busy,
        label: ProfilePhotoStrings.semProfilePhoto,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : onTap,
          child: Row(
            children: [
              SizedBox.square(
                dimension: outer,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DashedRRectPainter(
                          line: Form3D.wash(_tone, Alpha.half),
                          fill: Colors.transparent,
                          radius: DS.circular(_photo / 2 + _gap),
                          stroke: DS.s(1.5),
                          dash: DS.s(5),
                          gap: DS.s(3),
                        ),
                      ),
                    ),
                    Center(
                      child: ProfilePhotoCircle(
                        size: DS.s(_photo),
                        url: url,
                        localPath: local,
                        placeholderPath: controller.placeholderPath,
                        busy: busy,
                        progress: busy ? controller.progress.value : null,
                        ring: false,
                        fallback: ColoredBox(
                          color: AuthInk.page,
                          child: Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.camera, size: 56, shadowBlur: 3, shadowOffset: const Offset(2, 4)))),
                        ),
                      ),
                    ),
                    if (!busy) Positioned(right: 0, bottom: 0, child: ProfileRoundButton(icon: Icons.photo_camera_rounded, color: _tone.g2)),
                  ],
                ),
              ),
              Gap.h(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SocialStringsA.addPhoto, style: Ink3D.text(13, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0)),
                    Gap.v(2),
                    failed
                        ? Text(ProfilePhotoStrings.uploadFailed, style: Ink3D.text(13, FontWeight.w600, AuthInk.badText, height: 1.5))
                        : Text(SocialStringsA.addPhotoWhy, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class OnboardingStepYou extends StatelessWidget {
  const OnboardingStepYou({
    super.key,
    required this.c,
    required this.photo,
    required this.onPhoto,
    required this.nameCtrl,
    required this.nameFocus,
    this.photoUrl,
  });

  final OnboardingController c;
  final ProfilePhotoController photo;
  final VoidCallback onPhoto;
  final TextEditingController nameCtrl;
  final FocusNode nameFocus;
  final String? photoUrl;

  Future<void> _pickMonth(BuildContext context) async {
    final m = await ChoiceSheet.pick<int>(context,
        title: SocialStringsA.month, values: List.generate(12, (i) => i + 1), label: SocialFormats.monthName, selected: c.birthMonth.value);
    if (m != null) c.birthMonth.value = m;
  }

  Future<void> _pickYear(BuildContext context) async {
    final y = await ChoiceSheet.pick<int>(context, title: SocialStringsA.year, values: c.years, label: (v) => '$v', selected: c.birthYear.value);
    if (y != null) c.birthYear.value = y;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingCard(
      children: [
        OnboardingPhotoRow(controller: photo, onTap: onPhoto, url: photoUrl),
        const OnboardingFieldLabel(SocialStringsA.fullName),
        AuthPillInput(
          tone: ListingTone.indigo,
          focusNode: nameFocus,
          leadingArt: ListingArt.profile,
          child: TextField(
            key: const ValueKey('ob_name'),
            controller: nameCtrl,
            focusNode: nameFocus,
            textCapitalization: TextCapitalization.words,
            maxLength: ProfileRules.nameMax,
            inputFormatters: noEmojiInputFormatters,
            style: AuthPillInput.nameStyle,
            cursorColor: ListingTone.indigo.g2,
            decoration: AuthPillInput.decoration(SocialStringsA.fullNameHint),
            onChanged: (v) => c.name.value = v,
          ),
        ),
        const OnboardingFieldLabel(SocialStringsA.gender),
        Obx(() => GenderCards(selected: c.gender.value, onPick: (g) => c.gender.value = g)),
        const OnboardingFieldLabel(SocialStringsA.birth),
        Obx(() => Row(
              children: [
                Expanded(
                  child: SelectPill(
                    pillKey: const ValueKey('ob_month'),
                    text: c.birthMonth.value == null ? null : SocialFormats.monthName(c.birthMonth.value!),
                    hint: SocialStringsA.month,
                    onTap: () => _pickMonth(context),
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: SelectPill(
                    pillKey: const ValueKey('ob_year'),
                    text: c.birthYear.value?.toString(),
                    hint: SocialStringsA.year,
                    onTap: () => _pickYear(context),
                  ),
                ),
              ],
            )),
        Padding(
          padding: EdgeInsets.fromLTRB(DS.s(4), DS.gv(8), 0, 0),
          child: Text(SocialStringsA.birthHelp, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
        ),
      ],
    );
  }
}

class OnboardingStepStyle extends StatelessWidget {
  const OnboardingStepStyle({super.key, required this.c});

  final OnboardingController c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingCard(
          children: [
            Obx(() => _CountLabel(
                  text: SocialStringsA.interestsLabel,
                  count: SocialStringsA.ofThree(c.interests.length),
                  ok: c.interests.length >= ProfileRules.interestsMin,
                  top: false,
                )),
            Obx(() => ChoiceTileGrid(
                  children: [
                    for (final i in c.interestOptions)
                      ChoiceArtTile(key: ValueKey('ob_int_$i'), label: i, art: SocialArtA.interest(i), selected: c.interests.contains(i), onTap: () => c.toggleInterest(i)),
                  ],
                )),
          ],
        ),
        SizedBox(height: DS.gv(16)),
        OnboardingCard(
          children: [
            Obx(() => _CountLabel(
                  text: SocialStringsA.skillsLabel,
                  count: SocialStringsA.picked(c.skills.length),
                  ok: c.skills.length >= ProfileRules.skillsMin,
                  top: false,
                )),
            Obx(() => ChoiceTileGrid(
                  children: [
                    for (final s in c.skillOptions)
                      ChoiceArtTile(key: ValueKey('ob_skill_$s'), label: s, art: SocialArtA.skill(s), selected: c.skills.contains(s), onTap: () => c.toggleSkill(s)),
                  ],
                )),
          ],
        ),
      ],
    );
  }
}

class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({
    super.key,
    required this.name,
    this.city,
    required this.about,
    required this.interests,
    required this.places,
    required this.skills,
    this.gender,
    this.photoUrl,
  });

  final String name;
  final String? city;
  final String about;
  final List<String> interests;
  final List<String> places;
  final List<String> skills;
  final String? gender;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final white = DesignColors.onPrimary;
    final shownPlaces = places.length > 2 ? [...places.take(2), '+${places.length - 2}'] : places;
    final shownSkills = skills.length > 1 ? [skills.first, '+${skills.length - 1}'] : skills;
    final g = gender ?? '';
    final initial = name.trim().isEmpty ? '' : name.trim().substring(0, 1).toUpperCase();
    return Container(
      key: const ValueKey('ob_preview'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: tone.glow(blur: 14, dy: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: DS.sym(h: 16, v: 14),
            decoration: BoxDecoration(gradient: tone.gradient),
            child: Row(
              children: [
                ProfilePhotoCircle(
                  size: DS.s(56),
                  url: photoUrl,
                  ringColor: white.withValues(alpha: Alpha.v72),
                  ringWidth: DS.s(2),
                  fallback: ColoredBox(
                    color: white.withValues(alpha: Alpha.v25),
                    child: Center(child: Text(initial, style: Ink3D.text(22, FontWeight.w700, white, letterSpacing: 0))),
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(SocialFormats.shortName(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, white, letterSpacing: 0))),
                        Gap.h(6),
                        if (g == SocialStringsA.male || g == SocialStringsA.female)
                          Container(
                            padding: DS.all(2),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignColors.surface),
                            child: GenderGlyph(gender: g, color: GenderGlyph.inkOf(g), size: 14),
                          ),
                      ]),
                      Text(city ?? SocialStringsA.traveller, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w400, white.withValues(alpha: Alpha.v92), letterSpacing: 0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: DS.insets(l: 16, t: 12, r: 16, b: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (about.trim().isNotEmpty) Text(about, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.body, height: 1.45, letterSpacing: 0)),
                Gap.v(8),
                Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [for (final i in interests) TagChip(text: i, kind: TagKind.interest, small: true)]),
                Gap.v(6),
                Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [
                  for (final p in shownPlaces) TagChip(text: p, kind: TagKind.place, small: true),
                  for (final s in shownSkills) TagChip(text: s, kind: TagKind.skill, small: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingStepAbout extends StatelessWidget {
  const OnboardingStepAbout({super.key, required this.c, required this.aboutCtrl, this.photoUrl});

  static const Key counterKey = ValueKey('ob_about_counter');

  final OnboardingController c;
  final TextEditingController aboutCtrl;
  final String? photoUrl;

  Future<void> _addPlace(BuildContext context) async {
    final p = await PlacePickerSheet.pick(context);
    if (p != null) c.addPlace(p);
  }

  Future<void> _pickHome(BuildContext context) async {
    final h = await HomeCitySheet.pick(context);
    if (h != null) c.pickHomeCity(h);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingCard(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(4), 0, DS.s(4), DS.gv(10)),
              child: Row(
                children: [
                  ExcludeSemantics(child: Art3D(asset: ListingArt.houseWithGarden, size: 18, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
                  Gap.h(8),
                  Expanded(child: Text(SocialStringsA.homeCity, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub))),
                  Flexible(
                    child: Text(SocialStringsA.homeCityHint,
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ),
                ],
              ),
            ),
            Obx(() {
              final city = c.homeCity.value;
              final state = c.homeState.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectPill(
                    pillKey: const ValueKey('ob_home_city'),
                    leadingArt: ListingArt.roundPushpin,
                    text: city == null || city.isEmpty ? null : PickedHome(city: city, state: state ?? '').label,
                    hint: SocialStringsA.addHomeCity,
                    onTap: () => _pickHome(context),
                  ),
                  if (c.homeCityFromGps)
                    Padding(
                      padding: EdgeInsets.fromLTRB(DS.s(4), DS.gv(8), 0, 0),
                      child: Text(SocialStringsA.homeCityFound, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ),
                ],
              );
            }),
          ],
        ),
        SizedBox(height: DS.gv(16)),
        OnboardingCard(
          children: [
            Obx(() => _CountLabel(
                  text: SocialStringsA.placesLabel,
                  count: SocialStringsA.placesAdded(c.places.length),
                  ok: c.places.length >= ProfileRules.placesMin,
                  top: false,
                )),
            Tap3D(
              tapKey: const ValueKey('ob_add_place'),
              onTap: () => _addPlace(context),
              label: SocialStringsA.addPlaceHint,
              exclude: true,
              child: Container(
                height: DS.s(62),
                padding: DS.sym(h: 18),
                decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(31)),
                child: Row(
                  children: [
                    ExcludeSemantics(child: Art3D(asset: ListingArt.search, size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
                    Gap.h(12),
                    Expanded(child: Text(SocialStringsA.addPlaceHint, maxLines: 1, style: AuthPillInput.hintStyle)),
                  ],
                ),
              ),
            ),
            Obx(() => c.places.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(top: DS.gv(10)),
                    child: ChoiceTileGrid(
                      children: [for (final p in c.places) PlaceTile(key: ValueKey('ob_place_$p'), text: p, onRemove: () => c.removePlace(p))],
                    ),
                  )),
          ],
        ),
        SizedBox(height: DS.gv(16)),
        OnboardingCard(
          children: [
            Obx(() => Padding(
                  padding: EdgeInsets.fromLTRB(DS.s(4), 0, DS.s(4), DS.gv(10)),
                  child: Row(
                    children: [
                      Expanded(child: Text(SocialStringsA.aboutYou, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub))),
                      Text('${c.about.value.length}/${ProfileRules.aboutMax}', key: OnboardingStepAbout.counterKey, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                )),
            Obx(() {
              final filled = c.about.value.trim().isNotEmpty;
              return Container(
                padding: DS.sym(h: 16, v: 10),
                constraints: BoxConstraints(minHeight: DS.s(84)),
                decoration: BoxDecoration(
                  borderRadius: DS.br(CardRadius.card),
                  border: Border.all(color: filled ? BuddyLook.tealStart : Form3D.outline, width: DS.s(2)),
                ),
                child: TextField(
                  key: const ValueKey('ob_about'),
                  controller: aboutCtrl,
                  maxLength: ProfileRules.aboutMax,
                  maxLines: 3,
                  minLines: 2,
                  inputFormatters: noEmojiInputFormatters,
                  style: Ink3D.text(16, FontWeight.w400, Ink3D.body, height: 1.45, letterSpacing: 0),
                  decoration: AuthPillInput.decoration(SocialStringsA.aboutHint).copyWith(hintStyle: Ink3D.text(16, FontWeight.w400, Form3D.hint, letterSpacing: 0)),
                  onChanged: (v) => c.about.value = v,
                ),
              );
            }),
            Obx(() => c.about.value.trim().isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(DS.s(4), DS.gv(6), DS.s(4), 0),
                    child: Text(SocialStringsA.needed, style: Ink3D.text(12, FontWeight.w500, AuthInk.warn, letterSpacing: 0)),
                  )
                : const SizedBox.shrink()),
            Obx(() {
              if (c.about.value.trim().isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(DS.s(4), DS.gv(16), DS.s(4), DS.gv(14)),
                    child: Text(SocialStringsA.howOthersSee, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
                  ),
                  ProfilePreviewCard(
                    name: c.trimmedName,
                    city: c.homeCity.value,
                    about: c.about.value,
                    interests: c.interests.toList(),
                    places: c.places.toList(),
                    skills: c.skills.toList(),
                    gender: c.gender.value,
                    photoUrl: photoUrl,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class OnboardingBottom extends StatelessWidget {
  const OnboardingBottom({super.key, required this.label, required this.enabled, required this.loading, required this.onTap, this.hint, this.link});

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  final String? hint;
  final Widget? link;

  static const Key buttonKey = ValueKey('ob_next');

  @override
  Widget build(BuildContext context) {
    final h = hint;
    return Container(
      color: AuthInk.page,
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(12), DS.s(18), DS.s(18) + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h != null && h.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: DS.gv(10)),
              child: Text(h, key: const ValueKey('ob_hint'), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, AuthInk.warn, letterSpacing: 0)),
            ),
          GradientPillButton(key: buttonKey, tone: ListingTone.indigo, label: label, onTap: onTap, enabled: enabled, loading: loading),
          ?link,
        ],
      ),
    );
  }
}
