import '../../shared/social_models.dart';

// Spec 22: every trip is visible to everyone; the server flags notOpen when my gender may not request it (Women only = women, Men only = men).
abstract final class JoinGenderRule {
  static bool blocks(PublicTrip t) => !t.isMine && !t.sample && t.joinGender != 'A' && t.notOpen;
}
