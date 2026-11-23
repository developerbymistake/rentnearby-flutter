class IntroSlideCopy {
  const IntroSlideCopy({required this.eyebrow, required this.headline, required this.sub});

  final String eyebrow, headline, sub;

  String get spoken => '$eyebrow. $headline $sub';
}

class IntroStrings {
  IntroStrings._();

  static const String tagline = "Let's Plan Your Perfect Trip.";
  static const String skip = 'Skip', next = 'Next', getStarted = 'Start planning';

  static const List<IntroSlideCopy> slides = [
    IntroSlideCopy(
      eyebrow: 'EXPLORE AND PLAN',
      headline: 'Dream it. Plan it together.',
      sub: 'Explore places, save your wishlist and shape every day with your buddies.',
    ),
    IntroSlideCopy(
      eyebrow: 'BOOK YOUR RIDE',
      headline: 'Your ride is on its way.',
      sub: 'Request a taxi in a few taps and relax. It arrives right where you wait.',
    ),
    IntroSlideCopy(
      eyebrow: 'THE JOURNEY BEGINS',
      headline: 'Every mile, in plan.',
      sub: 'Your route, stops and timings stay with you, day by day.',
    ),
    IntroSlideCopy(
      eyebrow: 'ADVENTURE',
      headline: 'Find your kind of adventure.',
      sub: 'Treks, viewpoints and thrills, picked for your trip.',
    ),
    IntroSlideCopy(
      eyebrow: 'MEMORIES AND STAY',
      headline: 'Make memories. Rest easy.',
      sub: 'Stop for the perfect photo, then settle into a stay you love.',
    ),
    IntroSlideCopy(
      eyebrow: 'BAKHLI',
      headline: tagline,
      sub: 'Great stays, comfortable rides, one effortless plan.',
    ),
  ];
}
