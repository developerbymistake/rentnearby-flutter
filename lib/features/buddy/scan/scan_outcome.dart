sealed class ScanOutcome {
  const ScanOutcome();
}

final class ScanFound extends ScanOutcome {
  const ScanFound(this.username);

  final String username;

  @override
  bool operator ==(Object other) => other is ScanFound && other.username == username;

  @override
  int get hashCode => username.hashCode;
}

final class ScanTypeInstead extends ScanOutcome {
  const ScanTypeInstead();

  @override
  bool operator ==(Object other) => other is ScanTypeInstead;

  @override
  int get hashCode => (ScanTypeInstead).hashCode;
}
