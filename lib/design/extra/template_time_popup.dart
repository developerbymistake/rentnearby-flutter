import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';

class TemplateTimePopup extends StatefulWidget {
  const TemplateTimePopup({
    super.key,
    required this.initial,
    this.label = 'Time',
    this.applyLabel = 'Apply',
    this.tone = KitTone.brand,
    this.onApply,
  });

  final TimeOfDay initial;
  final String label;
  final String applyLabel;
  final KitTone tone;
  final ValueChanged<TimeOfDay>? onApply;

  static Future<TimeOfDay?> pick(
    BuildContext context, {
    required TimeOfDay initial,
    String label = 'Time',
    KitTone tone = KitTone.brand,
    bool useRootNavigator = true,
  }) {
    TimeOfDay? result;
    return showDialog<TimeOfDay>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: DesignColors.scrim,
      builder: (ctx) => TemplateTimePopup(
        initial: initial,
        label: label,
        tone: tone,
        onApply: (t) => result = t,
      ),
    ).then((_) => result);
  }

  @override
  State<TemplateTimePopup> createState() => _TemplateTimePopupState();
}

class _TemplateTimePopupState extends State<TemplateTimePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.fastOutSlowIn,
  );
  late int _hour12 = widget.initial.hourOfPeriod == 0
      ? 12
      : widget.initial.hourOfPeriod;
  late int _minute = widget.initial.minute;
  late bool _pm = widget.initial.period == DayPeriod.pm;
  late final FixedExtentScrollController _hc = FixedExtentScrollController(
    initialItem: _hour12 - 1,
  );
  late final FixedExtentScrollController _mc = FixedExtentScrollController(
    initialItem: _minute,
  );
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
    _hc.dispose();
    _mc.dispose();
    super.dispose();
  }

  TimeOfDay get _value =>
      TimeOfDay(hour: (_hour12 % 12) + (_pm ? 12 : 0), minute: _minute);

  void _apply() {
    widget.onApply?.call(_value);
    Navigator.of(context).pop();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final accent = widget.tone.accentDark;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(_fade),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                    boxShadow: [
                      ShadowTokens.tint(
                        DesignColors.textGrey,
                        const ShadowSpec(0.2, Offset(4, 4), 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          children: [
                            Text(
                              widget.label,
                              style: TypeTokens.style(
                                16,
                                FontWeight.w400,
                                color: DesignColors.tint(
                                  DesignColors.textGrey,
                                  Alpha.high,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_two(_hour12)}:${_two(_minute)} ${_pm ? 'PM' : 'AM'}',
                              style: TypeTokens.style(
                                22,
                                FontWeight.w700,
                                color: DesignColors.textStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IgnorePointer(
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignColors.tint(accent, Alpha.tint),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _wheel(
                                    _hc,
                                    12,
                                    (i) => _two(i + 1),
                                    (i) => setState(() => _hour12 = i + 1),
                                  ),
                                ),
                                Text(
                                  ':',
                                  style: TypeTokens.style(
                                    22,
                                    FontWeight.w700,
                                    color: DesignColors.textStrong,
                                  ),
                                ),
                                Expanded(
                                  child: _wheel(
                                    _mc,
                                    60,
                                    _two,
                                    (i) => setState(() => _minute = i),
                                  ),
                                ),
                                Expanded(child: _periodToggle(accent)),
                                const SizedBox(width: 24),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: PrimaryButton(
                          label: widget.applyLabel,
                          tone: widget.tone,
                          onPressed: _apply,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wheel(
    FixedExtentScrollController c,
    int count,
    String Function(int) label,
    ValueChanged<int> onChanged,
  ) => ListWheelScrollView.useDelegate(
    controller: c,
    itemExtent: 44,
    perspective: 0.003,
    diameterRatio: 1.8,
    physics: const FixedExtentScrollPhysics(),
    onSelectedItemChanged: (i) {
      HapticFeedback.selectionClick();
      onChanged(i % count);
    },
    childDelegate: ListWheelChildLoopingListDelegate(
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(
              label(i),
              style: TypeTokens.style(
                20,
                FontWeight.w600,
                color: DesignColors.textStrong,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _periodToggle(Color accent) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _periodChip('AM', !_pm, accent, () => setState(() => _pm = false)),
      const SizedBox(height: 8),
      _periodChip('PM', _pm, accent, () => setState(() => _pm = true)),
    ],
  );

  Widget _periodChip(String t, bool on, Color accent, VoidCallback tap) =>
      GestureDetector(
        onTap: tap,
        child: PressScale(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            width: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? accent : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(22)),
              border: Border.all(color: on ? accent : DesignColors.divider),
            ),
            child: Text(
              t,
              style: TypeTokens.style(
                14,
                FontWeight.w700,
                color: on ? DesignColors.onPrimary : DesignColors.textGrey,
              ),
            ),
          ),
        ),
      );
}
