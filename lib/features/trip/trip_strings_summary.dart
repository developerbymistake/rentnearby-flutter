class TripStringsSummary {
  static const String stillToDo = 'Still to do';
  static const String stillToDoSub = 'Tap one to finish it.';
  static const String allDone = 'All set';
  static const String allDoneSub = 'Everything you planned is arranged.';
  static const String statDays = 'Days';
  static const String statPlaces = 'Places';
  static const String statArranged = 'Arranged';
  static const String statTotal = 'Agreed total';
  static const String stayChip = 'Stay';
  static const String taxiChip = 'Taxi';
  static const String datesNotSet = 'Dates not set';
  static String arranged(int done, int total) => '$done of $total';
  static String stayState(String s) => 'Stay: $s';
  static String taxiState(String s) => 'Taxi: $s';
  static String travellers(int n) => n == 1 ? '1 traveller' : '$n travellers';
  static String percentLabel(int p) => '$p percent arranged';
  static String openStep(String title) => 'Open $title in the plan';
}
