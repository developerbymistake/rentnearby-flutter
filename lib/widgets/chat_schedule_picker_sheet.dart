import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import '../utils/app_toast.dart';

class ChatSchedulePickerSheet extends StatefulWidget {
  final String title;
  const ChatSchedulePickerSheet({super.key, this.title = 'When would you like to visit?'});

  static Future<List<DateTime>?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    return ChatSheetFrame(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: TemplateStagger(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatSheetFrame.grabber(),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: Text(widget.title, style: FitnessAppTheme.title),
              ),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  itemCount: _dates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _dates[i];
                    final sel = i == _selectedDateIndex;
                    return ChatReveal(
                      index: i,
                      count: _dates.length,
                      horizontal: true,
                      offset: 100,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedDateIndex = i;
                          _selectedSlots.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 50,
                          decoration: BoxDecoration(
                            color: sel ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.spacer, width: 1.5),
                            boxShadow: sel ? ShadowTokens.elev3 : PickKit.greyShadow(),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(i == 0 ? 'Today' : _dayLabels[d.weekday % 7],
                                style: TripKit.text(11, color: sel ? FitnessAppTheme.white : FitnessAppTheme.nearlyDarkBlue)),
                            const SizedBox(height: 2),
                            Text('${d.day}',
                                style: TripKit.text(16, weight: FontWeight.w700, color: sel ? FitnessAppTheme.white : FitnessAppTheme.darkerText)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text('Tap one or more times to offer a choice',
                    style: FitnessAppTheme.caption.copyWith(fontSize: 12, color: FitnessAppTheme.lightText)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _slots.map((slot) {
                    final disabled = _isPast(selectedDate, slot);
                    final sel = _selectedSlots.contains(slot);
                    return IgnorePointer(
                      ignoring: disabled,
                      child: Opacity(
                        opacity: disabled ? Alpha.v40 : Alpha.full,
                        child: PickChip(
                          label: slot.format(context),
                          selected: sel,
                          activeColor: FitnessAppTheme.nearlyDarkBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          onTap: () => setState(() => sel ? _selectedSlots.remove(slot) : _selectedSlots.add(slot)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              PickButton(
                label: _selectedSlots.length > 1 ? 'Send these times →' : 'Send this time →',
                onPressed: _selectedSlots.isEmpty ? null : () => _onSend(selectedDate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
