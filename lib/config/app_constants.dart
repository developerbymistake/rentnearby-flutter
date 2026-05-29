class AppConstants {
  static const String serverUrl = 'https://developerbymistake.tech';
  static const String baseUrl = '$serverUrl/api/v1';
  static const String nominatimUrl = 'https://nominatim.developerbymistake.tech';
  // static const String baseUrl = 'http://192.168.1.33:5000/api/v1'; // Local dev
  // static const String baseUrl = 'http://10.0.2.2:5000/api/v1'; // Android emulator

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String googleWebClientId =
      '577015347089-k0pslitl2gko23qr92bdu3e6as9gidth.apps.googleusercontent.com';

  static const double defaultRadius = 5.0; // km
  static const int maxPhotos = 5;

  // Map defaults
  static const double fallbackLat = 30.0668; // Uttarakhand centre
  static const double fallbackLng = 79.0193;
  static const double clusterRadius = 500.0;
  static const int maxMapMarkers = 50;
  static const List<double> radiusOptions = [1.0, 4.0, 8.0];
}
