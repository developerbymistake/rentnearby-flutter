import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../utils/app_toast.dart';

/// The date/time picker behind "Schedule a visit" — used identically whether
/// the renter is proposing first or the owner is countering with a different
/// time (same widget, same mechanism, per the design).
class ChatSchedulePickerSheet extends StatefulWidget {
  final String title;
  const ChatSchedulePickerSheet({super.key, this.title = 'When would you like to visit?'});

  static Future<List<DateTime>?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ChatSchedulePickerSheet(title: title ?? 'When would you like to visit?'),
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
  // Multiple slots can be offered at once within the same date, so the other
  // party has a choice rather than one rigid time.
  final Set<TimeOfDay> _selectedSlots = {};

  bool _isPast(DateTime date, TimeOfDay slot) {
    final dt = DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
    return dt.isBefore(DateTime.now());
  }

  // Re-checks "already past" right at submit time rather than trusting the disabled-chip state
  // computed at build time — the sheet can sit open long enough for a slot that was valid when
  // tapped to genuinely become past by the time Send is pressed. Also sorts chronologically:
  // _selectedSlots is a Set, so without this, slots render in tap order (e.g. 5 PM, then 11 AM,
  // then 2 PM) instead of a sensible time-of-day order.
  void _onSend(DateTime selectedDate) {
    final times = _selectedSlots
        .where((slot) => !_isPast(selectedDate, slot))
        .map((slot) => DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot.hour, slot.minute))
        .toList()
      ..sort();

    if (times.isEmpty) {
      AppToast.error('Those times have passed — please pick a new time');
      setState(() {}); // refreshes the chips so the now-past slot shows disabled
      return;
    }

    Navigator.pop(context, times);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dates[_selectedDateIndex];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(widget.title,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 14),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _dates[i];
                final sel = i == _selectedDateIndex;
                return GestureDetector(
                  // Selected slots are specific to one date — switching date
                  // clears them rather than silently reinterpreting the same
                  // times against a different day.
                  onTap: () => setState(() {
                    _selectedDateIndex = i;
                    _selectedSlots.clear();
                  }),
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(i == 0 ? 'Today' : _dayLabels[d.weekday % 7],
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: sel ? Colors.white70 : AppColors.textLight)),
                      const SizedBox(height: 2),
                      Text('${d.day}',
                          style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textDark)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Tap one or more times to offer a choice',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _slots.map((slot) {
            final disabled = _isPast(selectedDate, slot);
            final sel = _selectedSlots.contains(slot);
            return GestureDetector(
              onTap: disabled
                  ? null
                  : () => setState(() => sel ? _selectedSlots.remove(slot) : _selectedSlots.add(slot)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Opacity(
                  opacity: disabled ? 0.4 : 1,
                  child: Text(slot.format(context),
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textDark)),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSlots.isEmpty ? null : () => _onSend(selectedDate),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                _selectedSlots.length > 1 ? 'Send these times →' : 'Send this time →',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
