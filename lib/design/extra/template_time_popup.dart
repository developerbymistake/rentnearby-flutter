import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'pill_buttons_3d.dart';
import 'state_card.dart';

class TemplateTimePopup extends StatefulWidget {
  const TemplateTimePopup({
    super.key,
    required this.initial,
    this.label = 'Time',
    this.applyLabel = 'Apply',
    this.tone = KitTone.brand,
    this.onApply,
    this.art,
  });

  final TimeOfDay initial;
  final String label;
  final String applyLabel;
  final KitTone tone;
  final ValueChanged<TimeOfDay>? onApply;
  final String? art;

  static Future<TimeOfDay?> pick(
    BuildContext context, {
    required TimeOfDay initial,
    String label = 'Time',
    KitTone tone = KitTone.brand,
    bool useRootNavigator = true,
    String? art,
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
        art: art,
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
    final tone = listingToneOf(widget.tone);
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(_fade),
        child: Dialog3D(
          tone: tone,
          art: widget.art ?? (identical(tone, ListingTone.coral) ? ListingArt.taxi : (identical(tone, ListingTone.forest) ? ListingArt.hotel : ListingArt.calendar)),
          label: widget.label,
          title: '${_two(_hour12)}:${_two(_minute)} ${_pm ? 'PM' : 'AM'}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(22)),
                child: MediaQuery.withNoTextScaling(
                  child: SizedBox(
                    height: 148,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _column(_hc, 12, (i) => _two(i + 1), _hour12 - 1, (i) => setState(() => _hour12 = i + 1), 'Hour'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(':', style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1)),
                      ),
                      _column(_mc, 60, _two, _minute, (i) => setState(() => _minute = i), 'Minute'),
                    ],
                  ),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _periodChip('AM', !_pm, tone, () => setState(() => _pm = false))),
                  const SizedBox(width: 10),
                  Expanded(child: _periodChip('PM', _pm, tone, () => setState(() => _pm = true))),
                ],
              ),
            ],
          ),
          primaryLabel: widget.applyLabel,
          onPrimary: _apply,
        ),
      ),
    );
  }

  Widget _column(FixedExtentScrollController c, int count, String Function(int) label, int current, ValueChanged<int> onChanged, String name) => Semantics(
    label: name,
    value: label(current),
    child: SizedBox(
      width: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(2, 4), blurRadius: 8)],
            ),
            child: const SizedBox(height: 44, width: 76),
          ),
          ListWheelScrollView.useDelegate(
            controller: c,
            itemExtent: 44,
            perspective: 0.0001,
            diameterRatio: 100,
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
                      style: i == current ? Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1, letterSpacing: 0) : Ink3D.text(18, FontWeight.w500, const Color(0xFFB4B8C2), height: 1, letterSpacing: 0),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _periodChip(String t, bool on, ListingTone tone, VoidCallback tap) => Tap3D(
    onTap: tap,
    selected: on,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? null : const Color(0xFFEEF0F4),
        gradient: on ? tone.gradient : null,
        borderRadius: BorderRadius.circular(21),
        boxShadow: on ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.45), offset: const Offset(2, 5), blurRadius: 8)] : null,
      ),
      child: Text(t, textScaler: TextScaler.noScaling, style: Ink3D.text(15, FontWeight.w700, on ? Colors.white : Ink3D.grey)),
    ),
  );
}
