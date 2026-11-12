import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/template_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';

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

  static Future<DateTime?> pickDate(
    BuildContext context, {
    DateTime? initial,
    DateTime? first,
    DateTime? last,
    String label = 'Date',
    KitTone tone = KitTone.brand,
    bool useRootNavigator = true,
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
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(fade),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _headerCell(widget.fromLabel, _start),
                          ),
                          if (!widget.singleDate) ...[
                            Container(
                              height: 74,
                              width: 1,
                              color: DesignColors.divider,
                            ),
                            Expanded(child: _headerCell(widget.toLabel, _end)),
                          ],
                        ],
                      ),
                      const Divider(height: 1),
                      _CalendarGrid(
                        start: _start,
                        end: _end,
                        min: widget.minimumDate == null
                            ? null
                            : _day(widget.minimumDate!),
                        max: widget.maximumDate == null
                            ? null
                            : _day(widget.maximumDate!),
                        single: widget.singleDate,
                        tone: widget.tone,
                        onChange: (s, e) => setState(() {
                          _start = s;
                          _end = e;
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: PrimaryButton(
                          label: widget.applyLabel,
                          tone: widget.tone,
                          onPressed: _ready ? _apply : null,
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

  Widget _headerCell(String label, DateTime? d) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        label,
        style: TypeTokens.style(
          16,
          FontWeight.w400,
          color: DesignColors.tint(DesignColors.textGrey, Alpha.high),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        d == null ? '--/--' : kitDayLabel(d),
        style: TypeTokens.style(
          16,
          FontWeight.w700,
          color: DesignColors.textStrong,
        ),
      ),
    ],
  );
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
  final KitTone tone;
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
                color: on ? accent : DesignColors.tint(accent, Alpha.faint),
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
    final accent = widget.tone.accentDark;
    final today = _day(DateTime.now());
    final big = MediaQuery.sizeOf(context).width > 360;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              _navButton(
                Icons.keyboard_arrow_left,
                _canGoPrev(),
                () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
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
                          child: Text(
                            _pickStage == 2
                                ? '${_pickYear ?? _month.year}'
                                : '${_months[_month.month - 1]}, ${_month.year}',
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(
                              20,
                              FontWeight.w500,
                              color: DesignColors.textStrong,
                            ),
                          ),
                        ),
                        Icon(
                          _pickStage == 0
                              ? Icons.arrow_drop_down
                              : Icons.arrow_drop_up,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _navButton(
                Icons.keyboard_arrow_right,
                _canGoNext(),
                () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
        ),
        if (_pickStage != 0)
          _jumpGrid(accent)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                for (final d in _days)
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TypeTokens.style(
                          14,
                          FontWeight.w500,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                for (var r = 0; r < 6; r++)
                  Row(
                    children: [
                      for (var k = 0; k < 7; k++)
                        Expanded(
                          child: _cell(cells[r * 7 + k], accent, today, big),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _navButton(IconData icon, bool enabled, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.all(3),
    child: SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            border: Border.all(color: DesignColors.divider),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              onTap: enabled ? onTap : null,
              child: Icon(
                icon,
                color: enabled
                    ? DesignColors.textGrey
                    : DesignColors.textDisabled,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _cell(DateTime d, Color accent, DateTime today, bool big) {
    final inMonth = d.month == _month.month;
    final edge = inMonth && _isEdge(d);
    final range =
        inMonth &&
        (edge || _inRange(d)) &&
        !widget.single &&
        widget.start != null &&
        widget.end != null;
    final isStart = _same(widget.start, d) || d.weekday == 1;
    final isEnd = _same(widget.end, d) || d.weekday == 7;
    final allowed = inMonth && _allowed(d);
    final textColor = edge
        ? DesignColors.onPrimary
        : !inMonth
        ? DesignColors.tint(DesignColors.textGrey, Alpha.soft)
        : allowed
        ? DesignColors.textStrong
        : DesignColors.textDisabled;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isStart ? 4 : 0, 5, isEnd ? 4 : 0, 5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: range
                    ? DesignColors.tint(accent, Alpha.soft)
                    : Colors.transparent,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(isStart ? 24 : 0),
                  right: Radius.circular(isEnd ? 24 : 0),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(32)),
              onTap: allowed ? () => _tap(d) : null,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: edge ? accent : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(32)),
                    border: Border.all(
                      color: edge ? TemplateTokens.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: edge
                        ? [
                            ShadowTokens.tint(
                              DesignColors.textGrey,
                              const ShadowSpec(0.6, Offset.zero, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${d.day}',
                      style: TypeTokens.style(
                        big ? 18 : 16,
                        edge ? FontWeight.w700 : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_same(today, d) && inMonth)
            Positioned(
              bottom: 9,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 6,
                  width: 6,
                  decoration: BoxDecoration(
                    color: edge || range ? DesignColors.onPrimary : accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
