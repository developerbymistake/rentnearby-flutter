import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../buddy/buddy_routes.dart';
import 'edit/edit_profile_screen.dart';
import 'people/add_buddies_screen.dart';
import 'people/people_screen.dart';
import 'profile/travel_levels_screen.dart';
import 'profile/traveller_profile_screen.dart';
import 'settings/settings_screen.dart';

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

final List<GetPage<dynamic>> socialPagesA = [
  _page(AppRoutes.settings, () => const SettingsScreen()),
  _page(AppRoutes.editProfile, () => const EditProfileScreen()),
  _page(AppRoutes.traveller, () => TravellerProfileScreen(userId: BuddyArgs.text(BuddyArgs.current, 'userId'))),
  _page(AppRoutes.people, () => PeopleScreen(tab: BuddyArgs.textOrNull(BuddyArgs.current, 'tab') ?? 'discover')),
  _page(AppRoutes.addBuddies, () => const AddBuddiesScreen()),
  _page(AppRoutes.travelLevels, () => const TravelLevelsScreen()),
];
