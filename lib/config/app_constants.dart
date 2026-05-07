class AppConstants {
  // Physical Android device — uses PC's local IP (must be on same WiFi)
  static const String baseUrl = 'http://192.168.1.33:5000/api/v1';
  // static const String baseUrl = 'http://10.0.2.2:5000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:5000/api/v1'; // iOS simulator

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static const double defaultRadius = 5.0; // km
  static const int maxPhotos = 5;
}
