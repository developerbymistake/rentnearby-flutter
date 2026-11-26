import '../../../../services/api_service.dart';
import '../../../buddy/shared/buddy_api_base.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../social_models.dart';

class SocialMeApi {
  const SocialMeApi();

  Future<BuddyResult<SocialMe>> me() =>
      BuddyApiBase.run(() async => SocialMe.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/social/me')))));

  Future<BuddyResult<MyProfile>> completeOnboarding(Map<String, dynamic> body) =>
      BuddyApiBase.run(() async => MyProfile.fromJson(BuddyApiBase.dataOf(await ApiService.put('/social/me/onboarding', body))));

  Future<BuddyResult<MyProfile>> updateProfile(Map<String, dynamic> body) =>
      BuddyApiBase.run(() async => MyProfile.fromJson(BuddyApiBase.dataOf(await ApiService.put('/social/me/profile', body))));

  Future<BuddyResult<MyProfile>> updatePrivacy(Map<String, dynamic> body) =>
      BuddyApiBase.run(() async => MyProfile.fromJson(BuddyApiBase.dataOf(await ApiService.put('/social/me/privacy', body))));

  Future<BuddyResult<TravellerProfile>> traveller(String userId) => BuddyApiBase.run(() async =>
      TravellerProfile.fromJson(BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/social/travellers/$userId')))));
}
