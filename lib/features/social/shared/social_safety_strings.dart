abstract final class SocialSafetyStrings {
  static String title(String firstName) {
    final n = firstName.trim();
    return n.isEmpty ? 'Keep it safe' : 'Keep it safe with $n';
  }

  static const String groupTitle = 'Keep your trip chat safe';
  static const String intro = 'Every buddy agrees to these.';
  static const String understood = 'Understood';
  static const String close = 'Close';
  static const String tipsRow = 'Safety tips';
  static const String footer = 'Report a chat from the menu (⋮).';

  static const String moneyTitle = 'Never send or ask for money';
  static const String moneyLine = 'No transfers, deposits or booking fees in chat. Split costs in person.';
  static const String detailsTitle = 'Keep private details private';
  static const String detailsLine = 'Passport, bank, home address, OTPs: never in chat. Phone numbers, emails and links are hidden here.';
  static const String kindTitle = 'Be kind, no exceptions';
  static const String kindLine = 'No harassment, hate, threats or sexual content. Reports can lead to a ban.';
  static const String meetTitle = 'Meet in public, tell someone';
  static const String meetLine = 'First meetups in daylight, public places. Share your plan with a friend.';
  static const String disappearTitle = 'Messages disappear after 24 hours';
  static const String disappearLine = 'Chats are short-lived. Report anything off from the menu.';
}
