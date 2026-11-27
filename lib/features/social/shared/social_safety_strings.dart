abstract final class SocialSafetyStrings {
  static String title(String firstName) {
    final n = firstName.trim();
    return n.isEmpty ? 'Chat safely' : 'Chat safely with $n';
  }

  static const String groupTitle = 'Chat safely with your trip group';
  static const String intro = 'Please follow these guidelines in every chat.';
  static const String understood = 'I understand';
  static const String close = 'Close';
  static const String tipsRow = 'Safety guidelines';
  static const String footer = 'You can report a chat from the menu (⋮).';

  static const String moneyTitle = 'No requests for money';
  static const String moneyLine = 'Do not send or ask for money, deposits or booking fees in chat. Share costs in person.';
  static const String detailsTitle = 'Protect your private details';
  static const String detailsLine = 'Never share passport, bank, address or OTP details. Phone numbers, emails and links are hidden in chat.';
  static const String kindTitle = 'Respectful language only';
  static const String kindLine = 'Abusive, offensive, sexual or threatening messages are not allowed. Reported accounts are reviewed and may be suspended.';
  static const String meetTitle = 'Meet safely';
  static const String meetLine = 'Meet in a public place during the day and share your plan with a friend or family member.';
  static const String disappearTitle = 'Messages expire in 24 hours';
  static const String disappearLine = 'Chats are temporary and are deleted automatically.';
}
