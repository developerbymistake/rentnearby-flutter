import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/jobs_kit.dart' show JobsKit;

abstract final class JobsUi {
  static const KitTone tone = KitTone.jobs;

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
    return SelectionPop(
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: KitChoiceChip(label: label, selected: selected, onTap: onTap, tone: JobsUi.tone),
      ),
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
      runSpacing: 4,
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
}) {
  return SheetFrame.show<int>(
    context,
    builder: (ctx) => SheetFrame(
      title: title,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            i < 8
                ? KitCardEntrance(index: i, offset: 30, child: _OptionRow(label: labels[i], on: i == selectedIndex, last: i == labels.length - 1, onTap: () => Navigator.pop(ctx, i)))
                : _OptionRow(label: labels[i], on: i == selectedIndex, last: i == labels.length - 1, onTap: () => Navigator.pop(ctx, i)),
        ],
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.on, required this.last, required this.onTap});

  final String label;
  final bool on;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap,
        splashColor: DesignColors.tint(JobsUi.tone.accentDark, Alpha.soft),
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(16, on ? FontWeight.w700 : FontWeight.w400,
                        color: on ? JobsUi.tone.accentDark : DesignColors.textPrimary)),
              ),
            ),
            if (on) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 22, color: JobsUi.tone.accentDark),
            ],
          ]),
        ),
      ),
      if (!last) const Divider(height: 1, color: DesignColors.dividerSoft),
    ]);
  }
}

Future<bool> showJobsConfirm(
  BuildContext context, {
  required String title,
  required String content,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: DesignColors.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 24),
      child: EntranceOnce(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: CardRadius.hero,
            boxShadow: ShadowTokens.elev3,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27)),
                const SizedBox(height: 8),
                Text(content, style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: SecondaryButton(
                      label: cancelLabel,
                      neutral: true,
                      tone: JobsUi.tone,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: confirmLabel,
                      tone: JobsUi.danger,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return ok == true;
}
