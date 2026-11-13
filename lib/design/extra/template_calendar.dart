import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';
import '../tokens/listing_palette.dart';
import '../tokens/type_tokens.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'pill_buttons_3d.dart';
import 'state_card.dart';

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String kitDayLabel(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} ${_monthsShort[d.month - 1]}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _same(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

class TemplateCalendarPopup extends StatefulWidget {
  const TemplateCalendarPopup({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.minimumDate,
    this.maximumDate,
    this.singleDate = false,
    this.tone = KitTone.brand,
    this.fromLabel = 'From',
    this.toLabel = 'To',
    this.applyLabel = 'Apply',
    this.barrierDismissible = true,
    this.onApply,
    this.art,
  });

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final bool singleDate;
  final KitTone tone;
  final String fromLabel;
  final String toLabel;
  final String applyLabel;
  final bool barrierDismissible;
  final void Function(DateTime start, DateTime end)? onApply;
  final String? art;

  static Future<DateTime?> pickDate(
    BuildContext context, {
    DateTime? initial,
    DateTime? first,
    DateTime? last,
    String label = 'Date',
    KitTone tone = KitTone.brand,
    bool useRootNavigator = true,
    String? art,
  }) {
    DateTime? result;
    return showDialog<DateTime>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: DesignColors.scrim,
      builder: (ctx) => TemplateCalendarPopup(
        singleDate: true,
        initialStartDate: initial,
        minimumDate: first,
        maximumDate: last,
        fromLabel: label,
        tone: tone,
        art: art,
        onApply: (s, _) => result = s,
      ),
    ).then((_) => result);
  }

  static Future<DateTimeRange?> pickRange(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? first,
    DateTime? last,
    KitTone tone = KitTone.brand,
    bool useRootNavigator = true,
  }) {
    DateTimeRange? result;
    return showDialog<DateTimeRange>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: DesignColors.scrim,
      builder: (ctx) => TemplateCalendarPopup(
        initialStartDate: initialStart,
        initialEndDate: initialEnd,
        minimumDate: first,
        maximumDate: last,
        tone: tone,
        onApply: (s, e) => result = DateTimeRange(start: s, end: e),
      ),
    ).then((_) => result);
  }

  @override
  State<TemplateCalendarPopup> createState() => _TemplateCalendarPopupState();
}

class _TemplateCalendarPopupState extends State<TemplateCalendarPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  DateTime? _start;
  DateTime? _end;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStartDate == null
        ? null
        : _day(widget.initialStartDate!);
    _end = widget.singleDate
        ? _start
        : (widget.initialEndDate == null ? null : _day(widget.initialEndDate!));
  }

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

  bool get _ready => _start != null && _end != null;

  void _apply() {
    if (!_ready) return;
    widget.onApply?.call(_start!, _end!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn);
    final tone = listingToneOf(widget.tone);
    final single = widget.singleDate;
    String d(DateTime? v) => v == null ? '--/--' : kitDayLabel(v);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(fade),
        child: Dialog3D(
          tone: tone,
          art: widget.art ?? ListingArt.calendar,
          label: single ? widget.fromLabel : '${widget.fromLabel} - ${widget.toLabel}',
          title: single ? d(_start) : '${d(_start)} - ${d(_end)}',
          content: _CalendarGrid(
            start: _start,
            end: _end,
            min: widget.minimumDate == null ? null : _day(widget.minimumDate!),
            max: widget.maximumDate == null ? null : _day(widget.maximumDate!),
            single: single,
            tone: tone,
            onChange: (s, e) => setState(() {
              _start = s;
              _end = e;
            }),
          ),
          primaryLabel: widget.applyLabel,
          primaryEnabled: _ready,
          onPrimary: _ready ? _apply : null,
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatefulWidget {
  const _CalendarGrid({
    required this.start,
    required this.end,
    required this.min,
    required this.max,
    required this.single,
    required this.tone,
    required this.onChange,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime? min;
  final DateTime? max;
  final bool single;
  final ListingTone tone;
  final void Function(DateTime? start, DateTime? end) onChange;

  @override
  State<_CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<_CalendarGrid> {
  late DateTime _month = _initialMonth();

  DateTime _initialMonth() {
    var d = widget.start ?? widget.min ?? DateTime.now();
    if (widget.start == null && widget.max != null && d.isAfter(widget.max!)) d = widget.max!;
    return DateTime(d.year, d.month);
  }

  int _pickStage = 0;
  int? _pickYear;

  int get _firstYear => widget.min?.year ?? DateTime.now().year - 100;
  int get _lastYear => widget.max?.year ?? DateTime.now().year + 10;

  bool _monthAllowed(int y, int m) =>
      (widget.min == null ||
          !DateTime(
            y,
            m + 1,
          ).isBefore(DateTime(widget.min!.year, widget.min!.month))) &&
      (widget.max == null ||
          !DateTime(
            y,
            m,
          ).isAfter(DateTime(widget.max!.year, widget.max!.month)));

  Widget _jumpGrid(Color accent) {
    final years = _pickStage == 1;
    final items = years
        ? [for (var y = _lastYear; y >= _firstYear; y--) y]
        : [for (var m = 0; m < 12; m++) m];
    return SizedBox(
      height: 300,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 52,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final v = items[i];
          final on = years
              ? v == _month.year
              : (_pickYear == _month.year && v == _month.month - 1);
          final ok = years || _monthAllowed(_pickYear ?? _month.year, v);
          return GestureDetector(
            onTap: !ok
                ? null
                : () => setState(() {
                    if (years) {
                      _pickYear = v;
                      _pickStage = 2;
                    } else {
                      _month = DateTime(_pickYear ?? _month.year, v + 1);
                      _pickStage = 0;
                    }
                  }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? accent : widget.tone.tint,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Text(
                years ? '$v' : _monthsShort[v],
                style: TypeTokens.style(
                  16,
                  on ? FontWeight.w700 : FontWeight.w500,
                  color: !ok
                      ? DesignColors.textDisabled
                      : on
                      ? DesignColors.onPrimary
                      : DesignColors.textStrong,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<DateTime> _cells() {
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday - 1;
    final startDay = first.subtract(Duration(days: lead));
    return [
      for (var i = 0; i < 42; i++)
        DateTime(startDay.year, startDay.month, startDay.day + i),
    ];
  }

  bool _allowed(DateTime d) =>
      (widget.min == null || !d.isBefore(widget.min!)) &&
      (widget.max == null || !d.isAfter(widget.max!));

  bool _canGoPrev() =>
      widget.min == null ||
      DateTime(
        _month.year,
        _month.month,
      ).isAfter(DateTime(widget.min!.year, widget.min!.month));

  bool _canGoNext() =>
      widget.max == null ||
      DateTime(
        _month.year,
        _month.month,
      ).isBefore(DateTime(widget.max!.year, widget.max!.month));

  void _tap(DateTime d) {
    if (!_allowed(d) || d.month != _month.month) return;
    if (widget.single) {
      widget.onChange(d, d);
      return;
    }
    final s = widget.start;
    final e = widget.end;
    if (s == null || e != null) {
      widget.onChange(d, null);
    } else if (_same(s, d)) {
      widget.onChange(null, null);
    } else if (d.isBefore(s)) {
      widget.onChange(d, null);
    } else {
      widget.onChange(s, d);
    }
  }

  bool _isEdge(DateTime d) => _same(widget.start, d) || _same(widget.end, d);

  bool _inRange(DateTime d) =>
      widget.start != null &&
      widget.end != null &&
      d.isAfter(widget.start!) &&
      d.isBefore(widget.end!);

  @override
  Widget build(BuildContext context) {
    final cells = _cells();
    final tone = widget.tone;
    final accent = tone.g2;
    final today = _day(DateTime.now());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _navButton(Icons.chevron_left_rounded, 'Previous month', _canGoPrev(), () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _pickYear = null;
                  _pickStage = _pickStage == 0 ? 1 : 0;
                }),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _pickStage == 2 ? '${_pickYear ?? _month.year}' : '${_months[_month.month - 1]}, ${_month.year}',
                            maxLines: 1,
                            softWrap: false,
                            style: Ink3D.text(16, FontWeight.w700, Ink3D.title),
                          ),
                        ),
                      ),
                      Icon(_pickStage == 0 ? Icons.arrow_drop_down : Icons.arrow_drop_up, color: accent),
                    ],
                  ),
                ),
              ),
            ),
            _navButton(Icons.chevron_right_rounded, 'Next month', _canGoNext(), () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
          ],
        ),
        if (_pickStage != 0)
          _jumpGrid(accent)
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Row(
              children: [
                for (final d in _days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(d, maxLines: 1, softWrap: false, textScaler: TextScaler.noScaling, style: Ink3D.text(12, FontWeight.w700, Ink3D.hint, letterSpacing: 0)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < 6; r++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  for (var k = 0; k < 7; k++) Expanded(child: _cell(cells[r * 7 + k], today)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _navButton(IconData icon, String tip, bool enabled, VoidCallback onTap) => Tooltip(
    message: tip,
    child: Tap3D(
      onTap: enabled ? onTap : null,
      label: tip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: enabled ? const [BoxShadow(color: Color(0x669E9E9E), offset: Offset(2, 4), blurRadius: 8)] : null,
              border: enabled ? null : Border.all(color: Ink3D.line),
            ),
            child: Icon(icon, size: 22, color: enabled ? widget.tone.text : const Color(0xFFC6C9D1)),
          ),
        ),
      ),
    ),
  );

  Widget _cell(DateTime d, DateTime today) {
    final tone = widget.tone;
    final inMonth = d.month == _month.month;
    if (!inMonth) return const SizedBox(height: 38);
    final edge = _isEdge(d);
    final range = (edge || _inRange(d)) && !widget.single && widget.start != null && widget.end != null;
    final isStart = _same(widget.start, d) || d.weekday == 1;
    final isEnd = _same(widget.end, d) || d.weekday == 7;
    final allowed = _allowed(d);
    final isToday = _same(today, d);
    final textColor = edge
        ? Colors.white
        : !allowed
        ? const Color(0xFFC6C9D1)
        : isToday
        ? tone.text
        : Ink3D.body;
    return Semantics(
      button: allowed,
      selected: edge,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: allowed ? () => _tap(d) : null,
        child: SizedBox(
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (range)
                Positioned.fill(
                  top: 3,
                  bottom: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tone.tint,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(isStart ? 19 : 0), right: Radius.circular(isEnd ? 19 : 0)),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: edge ? tone.gradient : null,
                  border: isToday && !edge ? Border.all(color: tone.g1, width: 2) : null,
                  boxShadow: edge ? [BoxShadow(color: tone.shadow.withValues(alpha: 0.5), offset: const Offset(2, 5), blurRadius: 8)] : null,
                ),
                child: Text(
                  '${d.day}',
                  textScaler: TextScaler.noScaling,
                  style: Ink3D.text(14, edge || isToday ? FontWeight.w700 : FontWeight.w500, textColor, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
