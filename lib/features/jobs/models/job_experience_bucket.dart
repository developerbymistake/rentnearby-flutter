class JobExperienceBucket {
  final String label;
  final int min;
  final int? max;

  const JobExperienceBucket(this.label, this.min, this.max);

  static const all = [
    JobExperienceBucket('Fresher', 0, 0),
    JobExperienceBucket('1-2 yrs', 1, 2),
    JobExperienceBucket('3-5 yrs', 3, 5),
    JobExperienceBucket('6+ yrs', 6, 20),
  ];
}
