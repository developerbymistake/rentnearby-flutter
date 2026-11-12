class GuideArgs {
  const GuideArgs(this.stepKey, {this.max = 3});

  static const String argKey = 'guide';

  final String stepKey;
  final int max;

  static GuideArgs? from(Object? args) {
    if (args is! Map) return null;
    final g = args[argKey];
    return g is GuideArgs ? g : null;
  }

  Map<String, dynamic> toArgs() => {argKey: this};

  bool get isStay => stepKey.startsWith('stay:');

  bool get isLocalTaxi => stepKey == 'taxi';

  bool get isWays => !isStay && !isLocalTaxi;

  String get kind => isStay ? 'Stay' : (isLocalTaxi ? 'Taxi' : 'Car');
}
