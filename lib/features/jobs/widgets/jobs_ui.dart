import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import 'package:bakhli/design/extra/jobs_kit.dart' show JobsKit;

abstract final class JobsUi {
  static const KitTone tone = KitTone.jobs;

  static ListingTone get look => JobsLook.page;

  static const KitTone danger = KitTone.danger;

  static const List<KitTone> _avatarTones = [KitTone.jobs, KitTone.stay, KitTone.taxi, KitTone.brand];

  static KitTone avatarTone(String seed) {
    var sum = 0;
    for (final u in seed.codeUnits) {
      sum += u;
    }
    return _avatarTones[sum % _avatarTones.length];
  }

  static String initialOf(String a, [String b = '']) {
    for (final s in [a, b]) {
      for (final r in s.runes) {
        final ch = String.fromCharCode(r);
        if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) return ch.toUpperCase();
      }
    }
    return '';
  }

  static const String roleIcon = JobsKit.backpack;
  static const String experienceIcon = 'assets/images/design/travel3d/mountain.png';
  static const String shiftIcon = 'assets/images/design/travel3d/sunrise.png';

  static InputDecoration input(String hint, {String? prefix}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: KitMetrics.tileSmall,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TypeTokens.style(14, FontWeight.w400, color: DesignColors.textMuted),
      prefixText: prefix,
      prefixStyle: TypeTokens.body,
      filled: true,
      fillColor: DesignColors.scaffold,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(DesignColors.borderSoft),
      enabledBorder: border(DesignColors.borderSoft),
      disabledBorder: border(DesignColors.borderSoft),
      focusedBorder: border(tone.accentDark, 1.5),
    );
  }
}

class JobsAvatar extends StatelessWidget {
  const JobsAvatar({super.key, required this.seed, required this.initial, this.dimmed = false, this.size = ListRow.tileSize});

  final String seed;
  final String initial;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = JobsUi.avatarTone(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: KitMetrics.tileSmall,
        gradient: dimmed ? null : t.gradient,
        color: dimmed ? DesignColors.surfaceMuted : null,
      ),
      child: Stack(
        children: [
          Center(
            child: initial.isEmpty
                ? TravelIcon(JobsKit.backpack, size: size * 0.5)
                : Text(
                    initial,
                    textScaler: TextScaler.noScaling,
                    style: TypeTokens.style(28, FontWeight.w800,
                        color: dimmed ? DesignColors.textMuted : DesignColors.textInverse),
                  ),
          ),
          if (initial.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dimmed ? DesignColors.surface : DesignColors.tint(DesignColors.surface, Alpha.high),
                ),
                child: Center(child: TravelIcon(JobsKit.backpack, size: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

class JobsChoiceChip extends StatelessWidget {
  const JobsChoiceChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: ChoicePill(tone: JobsUi.look, label: label, selected: selected, outlined: true, height: 36, onTap: onTap),
    );
  }
}

class JobsChoiceWrap extends StatelessWidget {
  const JobsChoiceWrap({super.key, required this.labels, required this.isActive, required this.onTap});

  final List<String> labels;
  final bool Function(int) isActive;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          JobsChoiceChip(label: labels[i], selected: isActive(i), onTap: () => onTap(i)),
      ],
    );
  }
}

class JobsDropdownChip extends StatelessWidget {
  const JobsDropdownChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? DesignColors.textInverse : DesignColors.textPrimary;
    return PressScale(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch, maxWidth: 220),
        child: InkWell(
          onTap: onTap,
          borderRadius: CardRadius.pill,
          splashColor: DesignColors.tint(JobsUi.tone.accentDark, Alpha.soft),
          highlightColor: Colors.transparent,
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              decoration: BoxDecoration(
                gradient: selected ? JobsUi.tone.gradient : null,
                color: selected ? null : DesignColors.surface,
                borderRadius: CardRadius.pill,
                border: Border.all(color: selected ? Colors.transparent : DesignColors.borderSoft, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(14, FontWeight.w600, color: fg)),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: fg),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

Future<int?> showJobsOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> labels,
  required int selectedIndex,
  String art = ListingArt.clipboard,
}) {
  return Sheet3D.show<int>(
    context,
    builder: (ctx) => Sheet3D(
      tone: JobsUi.look,
      art: art,
      title: title,
      size: SheetSize.list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            JobsOptionRow(tone: JobsUi.look, label: labels[i], selected: i == selectedIndex, divider: i > 0, onTap: () => Navigator.pop(ctx, i)),
        ],
      ),
    ),
  );
}

Future<bool> showJobsConfirm(
  BuildContext context, {
  required String title,
  required String content,
  required String cancelLabel,
  required String confirmLabel,
  String art = ListingArt.luggage,
}) async {
  final ok = await Dialog3D.show<bool>(
    context,
    builder: (ctx) => Dialog3D(
      tone: JobsUi.look,
      art: art,
      title: title,
      body: content,
      tight: true,
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.pop(ctx, false),
      primaryLabel: confirmLabel,
      primaryDanger: true,
      onPrimary: () => Navigator.pop(ctx, true),
    ),
  );
  return ok == true;
}
