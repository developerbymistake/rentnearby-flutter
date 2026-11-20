import 'package:flutter/widgets.dart' show StringCharacters;

class BuddyStrings {
  static const String usernameLabel = 'Username';
  static const String usernameHelper = 'Made by the app. It cannot be changed.';
  static const String usernameLoading = 'Getting your username';
  static const String myUsername = 'My username';
  static const String sectionBuddies = 'BUDDIES';
  static const String copyUsername = 'Copy username';
  static const String showQr = 'Show my QR';
  static const String copied = 'Username copied';
  static const String qrTitle = 'My QR';
  static const String qrSubtitle = 'Show it to a friend. They scan it in Find a buddy.';
  static const String qrLabel = 'QR code of your username';
  static const String close = 'Close';

  static String initialOf(String name) {
    final n = name.trim();
    return n.isEmpty ? '' : n.characters.first.toUpperCase();
  }
}
