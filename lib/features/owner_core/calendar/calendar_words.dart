abstract class CalendarWords {
  const CalendarWords();

  String get title;
  String get addEntry;
  String get legendBlocked => '';
  String get legendSpecial => '';
  String get legendFestival => '';
  String get tapHint;
  String get emptyDay;
  String get monthLockLine;
  String meterLabel(String key);
  String hiddenLine(int count);
  String get loadError;
}
