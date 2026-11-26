import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../social_strings_a.dart';

abstract final class SocialArtA {
  static const String _hub = 'assets/images/design/hub/';
  static const String male = '${_hub}man_raising_hand_3d_default.png';
  static const String female = '${_hub}woman_raising_hand_3d_default.png';
  static const String parachute = '${_hub}parachute_3d.png';
  static const String automobile = '${BuddyArt.dir}automobile.png';

  static const Map<String, String> _interests = {
    'Mountains': ListingArt.mountain,
    'Treks': ListingArt.backpack,
    'Beaches': ListingArt.beach,
    'Adventure': parachute,
    'Food': ListingArt.potOfFood,
    'Culture': ListingArt.classicalBuilding,
    'Photography': ListingArt.camera,
    'Spiritual': ListingArt.hinduTemple,
    'Road trips': automobile,
    'Camping': ListingArt.camping,
  };

  static const Map<String, String> _skills = {
    'Photographer': ListingArt.camera,
    'Driver': automobile,
    'Cook': ListingArt.potOfFood,
    'Tour guide': ListingArt.worldMap,
    'Content creator': ListingArt.mobilePhone,
    'First aid': ListingArt.shield,
  };

  static String interest(String v) => _interests[v] ?? ListingArt.compass;

  static String skill(String v) => _skills[v] ?? ListingArt.star;

  static String gender(String v) => switch (v) {
        'Male' => male,
        'Female' => female,
        _ => ListingArt.panda,
      };
}

abstract final class SocialButtonsA {
  static const double midHeight = 44;
  static const double midFont = 14;
  static const double smallHeight = 36;
  static const double smallFont = 13;
}

class ChoiceArtChip extends StatelessWidget {
  const ChoiceArtChip({super.key, required this.label, required this.art, required this.selected, required this.onTap, this.error = false});

  final String label;
  final String art;
  final bool selected;
  final VoidCallback onTap;
  final bool error;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(18), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final fg = selected ? DesignColors.onPrimary : Ink3D.sub;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Container(
        padding: DS.insets(l: 8, t: 6, r: 12, b: 6),
        decoration: BoxDecoration(
          gradient: selected ? tone.gradient : null,
          color: selected ? null : DesignColors.surface,
          borderRadius: radius,
          border: selected ? null : Border.all(color: error ? DesignColors.statusAttention : Form3D.outline, width: DS.s(1.5)),
          boxShadow: selected ? tone.glow(blur: 0, dy: 4) : DS.shadows(Form3D.cardShadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 22, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
            Gap.h(6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, fg, letterSpacing: 0))),
            if (selected) ...[Gap.h(4), Icon(Icons.check_rounded, size: DS.s(14), color: DesignColors.onPrimary)],
          ],
        ),
      ),
    );
  }
}

enum TagKind { interest, place, skill }

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.text, required this.kind, this.onRemove, this.small = false});

  final String text;
  final TagKind kind;
  final VoidCallback? onRemove;
  final bool small;

  static (Color, Color) colorsOf(TagKind kind) => switch (kind) {
        TagKind.interest => BuddyLook.note[NoteToneColor.indigo]!,
        TagKind.place => BuddyLook.note[NoteToneColor.teal]!,
        TagKind.skill => (DesignColors.amberTagBg, DesignColors.amberTagText),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsOf(kind);
    final remove = onRemove;
    final chip = Container(
      padding: small ? DS.sym(h: 9, v: 3) : DS.insets(l: 12, t: 6, r: remove == null ? 12 : 6, b: 6),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(small ? 11.5 : 13.5, FontWeight.w600, fg, letterSpacing: 0))),
          if (remove != null) Padding(padding: DS.insets(l: 6, r: 2), child: Icon(Icons.close_rounded, size: DS.s(15), color: fg)),
        ],
      ),
    );
    if (remove == null) return chip;
    return Tap3D(onTap: remove, label: SocialStringsA.removeTag(text), exclude: true, child: chip);
  }
}

class DashedAddChip extends StatelessWidget {
  const DashedAddChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: label,
        exclude: true,
        child: CustomPaint(
          painter: DashedRRectPainter(
            line: Form3D.wash(ListingTone.indigo, Alpha.half),
            fill: Colors.transparent,
            radius: DS.circular(10),
            stroke: DS.s(1.5),
            dash: DS.s(5),
            gap: DS.s(3),
          ),
          child: Padding(
            padding: DS.sym(h: 12, v: 5),
            child: Text('+ $label', maxLines: 1, style: Ink3D.text(13.5, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0)),
          ),
        ),
      );
}

class GenderGlyph extends StatelessWidget {
  const GenderGlyph({super.key, required this.gender, this.color = DesignColors.onPrimary, this.size = 18, this.badge = false});

  final String gender;
  final Color color;
  final double size;
  final bool badge;

  static Color inkOf(String gender) => gender == 'Female' ? DesignColors.genderFemale : DesignColors.genderMale;

  @override
  Widget build(BuildContext context) {
    final icon = switch (gender) {
      'Male' => Icons.male_rounded,
      'Female' => Icons.female_rounded,
      _ => null,
    };
    if (icon == null) return const SizedBox.shrink();
    if (!badge) return Semantics(label: gender, child: Icon(icon, size: DS.s(size), color: color));
    final onDark = color == DesignColors.onPrimary;
    return Semantics(
      label: gender,
      child: Container(
        padding: DS.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, color: onDark ? DesignColors.onPrimary : inkOf(gender).withValues(alpha: Alpha.v18)),
        child: Icon(icon, size: DS.s(size), color: onDark ? inkOf(gender) : color),
      ),
    );
  }
}
