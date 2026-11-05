class TripStringsMcdK1 {
  static const String baseStay = 'base stay';

  static String nightsRange(int first, int last) => 'Nights $first–$last';

  static String baseStayLine(String name, String checkOut) => [
        if (name.isNotEmpty) name,
        baseStay,
        if (checkOut.isNotEmpty) 'out $checkOut',
      ].join(' · ');
}
