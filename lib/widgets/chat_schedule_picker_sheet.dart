import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../utils/app_toast.dart';

class ChatSchedulePickerSheet extends StatefulWidget {
  final String title;
  final ListingTone? tone;
  const ChatSchedulePickerSheet({super.key, this.title = 'When would you like to visit?', this.tone});

  static Future<List<DateTime>?> show(BuildContext context, {String? title, ListingTone? tone}) {
    return Sheet3D.show<List<DateTime>>(
      context,
      builder: (_) => ChatSchedulePickerSheet(title: title ?? 'When would you like to visit?', tone: tone),
    );
  }

  @override
  State<ChatSchedulePickerSheet> createState() => _ChatSchedulePickerSheetState();
}

class _ChatSchedulePickerSheetState extends State<ChatSchedulePickerSheet> {
  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _slots = [
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
  ];

  late final List<DateTime> _dates = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  int _selectedDateIndex = 0;
  final Set<TimeOfDay> _selectedSlots = {};

  bool _isPast(DateTime date, TimeOfDay slot) {
    final dt = DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
    return dt.isBefore(DateTime.now());
  }

  void _onSend(DateTime selectedDate) {
    final times = _selectedSlots
        .where((slot) => !_isPast(selectedDate, slot))
        .map((slot) => DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot.hour, slot.minute))
        .toList()
      ..sort();

    if (times.isEmpty) {
      AppToast.error('Those times have passed — please pick a new time');
      setState(() {});
      return;
    }

    Navigator.pop(context, times);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dates[_selectedDateIndex];
    final tone = widget.tone ?? ListingTone.forest;
    return Sheet3D(
      tone: tone,
      art: ListingArt.calendar,
      title: widget.title,
      fitTitle: true,
      footer: GradientPillButton(
        tone: tone,
        label: _selectedSlots.length > 1 ? 'Send these times \u2192' : 'Send this time \u2192',
        fontSize: 17,
        onTap: _selectedSlots.isEmpty ? null : () => _onSend(selectedDate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                for (var i = 0; i < _dates.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: ChatDayPill3D(
                      tone: tone,
                      top: i == 0 ? 'Today' : _dayLabels[_dates[i].weekday % 7],
                      day: '${_dates[i].day}',
                      selected: i == _selectedDateIndex,
                      onTap: () => setState(() {
                        _selectedDateIndex = i;
                        _selectedSlots.clear();
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 10),
            child: Text('Tap one or more times to offer a choice', style: Ink3D.text(12, FontWeight.w400, Ink3D.grey)),
          ),
          for (var r = 0; r < _slots.length; r += 3) ...[
            if (r > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var c = r; c < r + 3 && c < _slots.length; c++) ...[
                  if (c > r) const SizedBox(width: 10),
                  Expanded(child: _slot(selectedDate, _slots[c])),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _slot(DateTime selectedDate, TimeOfDay slot) {
    final sel = _selectedSlots.contains(slot);
    return ChatSlotPill3D(
      tone: widget.tone ?? ListingTone.forest,
      label: slot.format(context),
      selected: sel,
      off: _isPast(selectedDate, slot),
      onTap: () => setState(() => sel ? _selectedSlots.remove(slot) : _selectedSlots.add(slot)),
    );
  }
}
