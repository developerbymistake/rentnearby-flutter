import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/config/module_palette.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'sheet_frame.dart';
import 'stay_setup_kit.dart';
import 'template_motion.dart';

class JobsKit {
  JobsKit._();

  static const Color accent = DesignColors.dinnerEnd;
  static const Color accentLight = DesignColors.ringLight;
  static const Color tint = DesignColors.statusOwnSoft;
  static const LinearGradient gradient = DesignGradients.dinner;
  static const ModulePalette palette = ModulePalette(
    accent: accent,
    accentDark: accent,
    accentLight: accentLight,
    surface: DesignColors.scaffold,
    gradient: gradient,
  );

  static const String _dir = 'assets/images/design/travel3d/';
  static const String backpack = '${_dir}backpack.png';

  static const SystemUiOverlayStyle darkIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static const BorderRadius dialogRadius = CardRadius.tile;
  static const BorderRadius sheetRadius = CardRadius.sheet;

  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = DesignColors.textStrong,
    double letterSpacing = 0.2,
    double? height,
  }) =>
      TypeTokens.style(size, weight, color: color, letterSpacing: letterSpacing, height: height);

  static List<BoxShadow> pillShadow() => ShadowTokens.elev2;

  static List<BoxShadow> barShadow() => ShadowTokens.elev2;

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String content,
    required String cancelLabel,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => KitDialogFrame(
        title: title,
        body: content,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        tone: KitTone.jobs,
        destructive: true,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    return ok == true;
  }

  static Future<int?> pickOption(
    BuildContext context, {
    required String title,
    required List<String> labels,
    required int selectedIndex,
  }) {
    return SheetFrame.show<int>(
      context,
      builder: (sheetCtx) => SheetFrame(
        title: title,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _OptionList(labels: labels, selectedIndex: selectedIndex),
      ),
    );
  }
}

class _OptionList extends StatefulWidget {
  const _OptionList({required this.labels, required this.selectedIndex});

  final List<String> labels;
  final int selectedIndex;

  @override
  State<_OptionList> createState() => _OptionListState();
}

class _OptionListState extends State<_OptionList> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cap = 8;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.labels.length; i++) _row(i, cap),
      ],
    );
  }

  Widget _row(int i, int cap) {
    final on = i == widget.selectedIndex;
    final row = Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: () => Navigator.pop(context, i),
        splashColor: DesignColors.tint(JobsKit.accent, Alpha.tint),
        highlightColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: KitMetrics.touch + 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(
                widget.labels[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: JobsKit.text(16,
                    weight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? JobsKit.accent : DesignColors.textStrong),
              ),
            ),
            if (on) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 20, color: JobsKit.accent),
            ],
          ]),
        ),
      ),
      const Divider(height: 1, color: DesignColors.dividerSoft),
    ]);
    if (i >= cap) return row;
    return TemplateEntrance(animation: templateInterval(_c, i, cap), animationController: _c, child: row);
  }
}

class JobsCircleButton extends StatelessWidget {
  const JobsCircleButton({super.key, required this.icon, required this.onTap, this.size = 34});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: onTap != null,
      child: SizedBox(
        width: KitMetrics.touch,
        height: KitMetrics.touch,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: DesignColors.surface,
              shape: BoxShape.circle,
              boxShadow: JobsKit.pillShadow(),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                splashColor: DesignColors.tint(JobsKit.accent, Alpha.soft),
                highlightColor: Colors.transparent,
                child: Icon(icon, size: 16, color: DesignColors.textStrong),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JobsTopBar extends StatelessWidget {
  const JobsTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  final Widget title;
  final Widget subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  static Widget titleText(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: JobsKit.text(22, weight: FontWeight.w700, letterSpacing: 1.2),
      );

  static Widget subtitleText(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: JobsKit.text(14, color: DesignColors.textSecondary, letterSpacing: 0),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: JobsKit.darkIcons,
      child: Container(
        decoration: BoxDecoration(color: DesignColors.surface, boxShadow: JobsKit.barShadow()),
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, 12),
        child: Row(children: [
          JobsCircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [title, const SizedBox(height: 2), subtitle],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}

class JobsTag extends StatelessWidget {
  const JobsTag(this.label, {super.key, this.filled = false, this.color = JobsKit.accent, this.background});

  final String label;
  final bool filled;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? (filled ? color : color.withValues(alpha: Alpha.tint)),
        borderRadius: CardRadius.pill,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(11, FontWeight.w600,
            color: filled ? DesignColors.onPrimary : color, chip: true),
      ),
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
    final fg = selected ? DesignColors.onPrimary : DesignColors.textPrimary;
    return PressScale(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200, minHeight: KitMetrics.touch),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: selected ? KitTone.jobs.gradient : null,
              color: selected ? null : DesignColors.chipBackground,
              borderRadius: CardRadius.pill,
              boxShadow: selected ? ShadowTokens.glow(KitTone.jobs.glow) : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: CardRadius.pill,
                onTap: onTap,
                splashColor: DesignColors.tint(JobsKit.accent, Alpha.soft),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JobsKit.text(13, weight: FontWeight.w600, color: fg)),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JobsOptionWrap extends StatelessWidget {
  const JobsOptionWrap({super.key, required this.labels, required this.isActive, required this.onTap});

  final List<String> labels;
  final bool Function(int) isActive;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (var i = 0; i < labels.length; i++)
            KitChoiceChip(
              label: labels[i],
              selected: isActive(i),
              tone: KitTone.jobs,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class JobsEmpty extends StatelessWidget {
  const JobsEmpty({
    super.key,
    required this.iconAsset,
    required this.title,
    this.subtitle,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.extras = const [],
  });

  final String iconAsset;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;
  final List<Widget> extras;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: ShadowTokens.elev2,
        ),
        child: TemplateStagger(children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                DesignColors.tint(JobsKit.accent, Alpha.soft),
                DesignColors.tint(JobsKit.accent, Alpha.faint),
              ], begin: DesignGradients.begin, end: DesignGradients.end),
            ),
            child: Image.asset(iconAsset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: JobsKit.text(16, weight: FontWeight.w700, color: DesignColors.textStrong)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: JobsKit.text(14, weight: FontWeight.w400, color: TypeTokens.secondary)),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: retryLabel, onPressed: onRetry, tone: KitTone.jobs, expand: false),
          ],
          ...extras,
        ]),
      ),
    );
  }
}

class JobsRowEntrance extends StatefulWidget {
  const JobsRowEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<JobsRowEntrance> createState() => _JobsRowEntranceState();
}

class _JobsRowEntranceState extends State<JobsRowEntrance> with SingleTickerProviderStateMixin {
  static const int _cap = 8;
  AnimationController? _c;
  Animation<double>? _a;

  @override
  void initState() {
    super.initState();
    if (widget.index < _cap) {
      final c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
      _c = c;
      _a = templateInterval(c, widget.index, _cap);
      c.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final a = _a;
    if (c == null || a == null) return widget.child;
    return TemplateEntrance(animation: a, animationController: c, child: widget.child);
  }
}

class JobsPlaceholderCard extends StatelessWidget {
  const JobsPlaceholderCard({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ClipRRect(
        borderRadius: CardRadius.tile,
        child: TemplatePlaceholder(height: height, radius: 0),
      ),
    );
  }
}

class JobsSwitchStyle {
  JobsSwitchStyle._();
  static const Color thumb = JobsKit.accent;
  static final Color track = DesignColors.tint(JobsKit.accent, Alpha.half);
}
