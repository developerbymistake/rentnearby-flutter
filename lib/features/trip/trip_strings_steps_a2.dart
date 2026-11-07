class TripStringsStepsA2 {
  static const String changeCar = 'change car';
  static String carDriver(int n) => 'Car $n';
  static const String driverFallback = 'Driver';
  static const String call = 'Call';
  static const String whatsApp = 'WhatsApp';
  static String vehicleLine(String? from, String? to, String? vehicle) => [
        if ((from ?? '').isNotEmpty && (to ?? '').isNotEmpty) '$from → $to',
        if (vehicle != null && vehicle.isNotEmpty) vehicle,
      ].join(' · ');
  static String driverPaused(String driver, String? backup) =>
      backup == null || backup.isEmpty ? '$driver paused his taxi.' : '$driver paused his taxi. Backup: $backup';

}
