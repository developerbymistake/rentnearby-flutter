import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/profile_photo_strings.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/profile_photo_controller.dart';
import '../../../../design/design.dart';
import '../../../../design/extra/ext_auth.dart';
import '../../../../utils/input_formatters.dart';
import '../../../../widgets/profile_photo_circle.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_bottom_bar.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../onboarding/onboarding_controller.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import 'edit_profile_controller.dart';
import 'place_picker_sheet.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const Key saveKey = ValueKey('edit_save');
  static const Key removePhotoKey = ValueKey('edit_remove_photo');

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final String _tag = 'edit-profile-${identityHashCode(this)}';
  late final EditProfileController c = Get.put(EditProfileController(), tag: _tag);
  final _nameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  Worker? _seedWorker;

  @override
  void initState() {
    super.initState();
    _syncText();
    _seedWorker = ever<MyProfile?>(c.original, (_) => _syncText());
  }

  void _syncText() {
    if (_nameCtrl.text != c.name.value) _nameCtrl.text = c.name.value;
    if (_aboutCtrl.text != c.about.value) _aboutCtrl.text = c.about.value;
  }

  @override
  void dispose() {
    _seedWorker?.dispose();
    Get.delete<EditProfileController>(tag: _tag);
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final error = await c.save();
    if (!mounted) return;
    if (error == null) {
      BuddySnack.show(context, SocialStringsA.saved);
    } else {
      BuddySnack.show(context, error, danger: true);
    }
  }

  Future<void> _addPlace() async {
    final p = await PlacePickerSheet.pick(context);
    if (p != null) c.addPlace(p);
  }

  Future<void> _pickHome() async {
    final h = await PlacePickerSheet.pickHome(context);
    if (h == null) return;
    c.homeCity.value = h.city;
    c.homeState.value = h.state;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = c.original.value;
      return BuddyPage(
        title: SocialStringsA.editTitle,
        subtitle: SocialStringsA.editSub,
        bottomBar: p == null
            ? null
            : BuddyBottomBar(
                children: [
                  Obx(() {
                  final n = c.changeCount;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GradientPillButton(key: EditProfileScreen.saveKey, tone: BuddyLook.teal, label: SocialStringsA.save, onTap: _save, enabled: c.canSave, loading: c.saving.value),
                      Gap.v(8),
                      Text(n == 0 ? SocialStringsA.changeToSave : SocialStringsA.changes(n),
                          textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  );
                }),
                ],
              ),
        body: p == null
            ? (c.loading.value
                ? Padding(padding: DS.gapInsets(l: 18, t: 8, r: 18), child: SkeletonBox(height: DS.s(160), borderRadius: DS.circular(28)))
                : Padding(
                    padding: DS.gapInsets(t: 40),
                    child: StateCard.error(title: SocialStringsA.profileLoadFailed, actionLabel: SocialStrings.retry, onAction: c.reload),
                  ))
            : _form(p),
      );
    });
  }

  Widget _form(MyProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoCard(p),
        _EditCard(
          art: ListingArt.memo,
          title: SocialStringsA.about,
          hint: Obx(() => _hintText('${c.about.value.length}/${ProfileRules.aboutMax}')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => Container(
                    padding: DS.sym(h: 14, v: 8),
                    decoration: BoxDecoration(
                      borderRadius: DS.circular(18),
                      border: Border.all(color: c.about.value != p.about ? BuddyLook.tealStart : Form3D.outline, width: DS.s(2)),
                    ),
                    child: TextField(
                      key: const ValueKey('edit_about'),
                      controller: _aboutCtrl,
                      maxLength: ProfileRules.aboutMax,
                      minLines: 2,
                      maxLines: 4,
                      inputFormatters: noEmojiInputFormatters,
                      style: Ink3D.text(15, FontWeight.w400, Ink3D.body, height: 1.45, letterSpacing: 0),
                      decoration: AuthPillInput.decoration(SocialStringsA.aboutHint).copyWith(hintStyle: Ink3D.text(15, FontWeight.w400, Form3D.hint, letterSpacing: 0)),
                      onChanged: (v) => c.about.value = v,
                    ),
                  )),
              Gap.v(10),
              Obx(() => Wrap(
                spacing: DS.gh(8),
                runSpacing: DS.gv(8),
                children: [
                  for (final e in c.aboutExamples.where((e) => !c.about.value.contains(e)))
                    Tap3D(
                      onTap: () {
                        c.addAboutLine(e);
                        _aboutCtrl.text = c.about.value;
                        _aboutCtrl.selection = TextSelection.collapsed(offset: _aboutCtrl.text.length);
                      },
                      label: e,
                      exclude: true,
                      child: Container(
                        padding: DS.sym(h: 12, v: 6),
                        decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(14)),
                        child: Text('+ $e', style: Ink3D.text(13, FontWeight.w500, Ink3D.sub, letterSpacing: 0)),
                      ),
                    ),
                ],
              )),
            ],
          ),
        ),
        _EditCard(
          art: ListingArt.mountain,
          title: SocialStringsA.interests,
          hint: Obx(() => _hintText(SocialStringsA.interestsHint(c.interests.length))),
          child: Obx(() => Wrap(
                spacing: DS.gh(9),
                runSpacing: DS.gv(9),
                children: [
                  for (final i in c.interestOptions)
                    ChoiceArtChip(label: i, art: SocialArtA.interest(i), selected: c.interests.contains(i), onTap: () => c.toggleInterest(i)),
                ],
              )),
        ),
        _EditCard(
          art: ListingArt.camera,
          title: SocialStringsA.skills,
          hint: _hintText(SocialStringsA.atLeastOne),
          child: Obx(() => Wrap(
                spacing: DS.gh(9),
                runSpacing: DS.gv(9),
                children: [
                  for (final s in c.skillOptions)
                    ChoiceArtChip(label: s, art: SocialArtA.skill(s), selected: c.skills.contains(s), onTap: () => c.toggleSkill(s)),
                ],
              )),
        ),
        _EditCard(
          art: ListingArt.roundPushpin,
          title: SocialStringsA.placesCard,
          hint: Obx(() => _hintText(SocialStringsA.placesCount(c.places.length))),
          child: Obx(() => Wrap(
                spacing: DS.gh(8),
                runSpacing: DS.gv(8),
                children: [
                  for (final pl in c.places) TagChip(text: pl, kind: TagKind.place, onRemove: () => c.places.remove(pl)),
                  DashedAddChip(label: SocialStringsA.addPlace, onTap: _addPlace),
                ],
              )),
        ),
        _EditCard(
          art: ListingArt.houseWithGarden,
          title: SocialStringsA.homeCity,
          hint: _hintText(SocialStringsA.homeCityHint),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final city = c.homeCity.value;
                final label = city == null || city.isEmpty ? null : PickedHome(city: city, state: c.homeState.value ?? '').label;
                return Row(
                  children: [
                    if (label != null) Flexible(child: TagChip(text: label, kind: TagKind.place)),
                    if (label != null) Gap.h(10),
                    _textLink(
                      label == null ? SocialStringsA.addHomeCity : SocialStringsA.change,
                      _pickHome,
                      Ink3D.text(13.5, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0),
                    ),
                  ],
                );
              }),
              Gap.v(8),
              Text(SocialStringsA.homeCityNote, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            ],
          ),
        ),
        Gap.v(12),
      ],
    );
  }

  Widget _textLink(String label, VoidCallback? onTap, TextStyle style, {Key? key}) => Tap3D(
        tapKey: key,
        onTap: onTap,
        label: label,
        exclude: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      );

  static TextStyle get _pillText => Ink3D.text(14, FontWeight.w600, Ink3D.grey, letterSpacing: 0);

  static double _pillNeed(BuildContext context, String text, {required bool glyph}) {
    final tp = TextPainter(text: TextSpan(text: text, style: _pillText), textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context), maxLines: 1)
      ..layout();
    final width = DS.s(10) * 2 + (glyph ? DS.s(16) + DS.gh(6) : 0) + tp.width + DS.gh(6) + DS.s(14);
    tp.dispose();
    return width;
  }

  Widget _lockedPills(MyProfile p, String birth) {
    final gender = _lockedPill(p.gender, leading: GenderGlyph(gender: p.gender, color: Ink3D.grey, size: 16));
    final born = _lockedPill(birth);
    return LayoutBuilder(builder: (context, box) {
      final gap = DS.gh(8);
      final rowNeed = gap + math.max(_pillNeed(context, p.gender, glyph: true) * 23 / 10, _pillNeed(context, birth, glyph: false) * 23 / 13);
      if (box.maxWidth >= rowNeed) {
        return Row(
          children: [
            Expanded(key: const ValueKey('edit_locked_gender'), flex: 10, child: gender),
            Gap.h(8),
            Expanded(key: const ValueKey('edit_locked_birth'), flex: 13, child: born),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(key: const ValueKey('edit_locked_gender'), child: gender),
          Gap.v(8),
          KeyedSubtree(key: const ValueKey('edit_locked_birth'), child: born),
        ],
      );
    });
  }

  Widget _hintText(String t) => Text(t, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0));

  Widget _lockedPill(String text, {Widget? leading}) => Container(
        height: DS.s(42),
        padding: DS.sym(h: 10),
        decoration: BoxDecoration(color: BuddyLook.pillOff, borderRadius: DS.circular(21)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ?leading,
            if (leading != null) Gap.h(6),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _pillText)),
            Gap.h(6),
            Icon(Icons.lock_rounded, size: DS.s(14), color: Form3D.hint),
          ],
        ),
      );

  Widget _photoCard(MyProfile p) {
    final photo = ProfilePhotoController.ensure();
    final auth = Get.find<AuthController>();
    final month = SocialFormats.monthName(p.birthMonth);
    final birth = '${month.length >= 3 ? month.substring(0, 3) : month} ${p.birthYear}';
    return Container(
      margin: DS.gapInsets(l: 18, t: 4, r: 18),
      padding: DS.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
        boxShadow: BuddyLook.cardShadows(DS.size),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final busy = photo.busy.value;
            final failed = photo.failed.value && photo.localPath.value != null;
            return Tap3D(
              onTap: busy ? null : () => failed ? photo.retryChange() : photo.change(context),
              label: SocialStringsA.changePhoto,
              exclude: true,
              child: SizedBox.square(
                dimension: DS.s(96),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfilePhotoCircle(
                      size: DS.s(96),
                      url: auth.user.value?.profilePhotoUrl,
                      localPath: busy ? photo.localPath.value : null,
                      placeholderPath: photo.placeholderPath,
                      busy: busy,
                      failed: failed,
                      ringColor: ListingTone.indigo.g2.withValues(alpha: Alpha.v25),
                      ringWidth: DS.s(3),
                      failColor: ListingTone.coral.g1,
                      fallback: ColoredBox(
                        color: TagChip.colorsOf(TagKind.interest).$1,
                        child: Center(child: Text(p.initial, style: Ink3D.text(28, FontWeight.w700, BuddyLook.indigoText, letterSpacing: 0))),
                      ),
                    ),
                    if (!busy && !failed)
                      Positioned(right: -DS.s(2), bottom: -DS.s(2), child: ProfileRoundButton(icon: Icons.photo_camera_rounded, color: ListingTone.indigo.g2)),
                  ],
                ),
              ),
            );
          }),
          Gap.h(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: DS.s(50),
                  padding: DS.sym(h: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(25)),
                  child: TextField(
                    key: const ValueKey('edit_name'),
                    controller: _nameCtrl,
                    maxLength: ProfileRules.nameMax,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: noEmojiInputFormatters,
                    style: Ink3D.text(16, FontWeight.w600, Ink3D.body, letterSpacing: 0),
                    decoration: AuthPillInput.decoration(SocialStringsA.fullNameHint).copyWith(hintStyle: Ink3D.text(16, FontWeight.w400, Form3D.hint, letterSpacing: 0)),
                    onChanged: (v) => c.name.value = v,
                  ),
                ),
                Gap.v(8),
                _lockedPills(p, birth),
                Gap.v(6),
                Text(SocialStringsA.lockedNote, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.4, letterSpacing: 0)),
                Obx(() {
                  final busy = photo.busy.value;
                  final hasPhoto = auth.user.value?.profilePhotoUrl != null;
                  return Wrap(
                    spacing: DS.gh(14),
                    children: [
                      _textLink(SocialStringsA.changePhoto, busy ? null : () => photo.change(context),
                          Ink3D.text(13, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0)),
                      if (hasPhoto)
                        _textLink(ProfilePhotoStrings.remove, busy ? null : photo.remove,
                            Ink3D.text(13, FontWeight.w600, BuddyLook.note[NoteToneColor.danger]!.$2, letterSpacing: 0),
                            key: EditProfileScreen.removePhotoKey),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({required this.art, required this.title, required this.hint, required this.child});

  final String art;
  final String title;
  final Widget hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.gapInsets(l: 18, t: 20, r: 18),
        padding: DS.insets(l: 16, t: 16, r: 16, b: 18),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
          boxShadow: BuddyLook.cardShadows(DS.size),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: DS.s(40),
                  height: DS.s(40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(decoration: BoxDecoration(color: ListingTone.indigo.g2.withValues(alpha: Alpha.tint), borderRadius: DS.circular(12))),
                      ),
                      Positioned(left: -DS.s(1), top: -DS.s(6), child: ExcludeSemantics(child: Art3D(asset: art, size: 44, shadowBlur: 3, shadowOffset: const Offset(2, 4)))),
                    ],
                  ),
                ),
                Gap.h(10),
                Expanded(child: Text(title, style: Ink3D.text(16, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                hint,
              ],
            ),
            Gap.v(10),
            child,
          ],
        ),
      );
}
