import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../buddy/buddy_routes.dart';
import 'chat/dm_room_screen.dart';
import 'plus/seeker_plus_screen.dart';

GetPage<dynamic> _page(String name, GetPageBuilder page) =>
    GetPage(name: name, page: page, customTransition: TemplateTransition(), transitionDuration: templateTransitionDuration);

final List<GetPage<dynamic>> socialPagesC = [
  _page(AppRoutes.dmRoom, () {
    final a = BuddyArgs.current;
    return DmRoomScreen(
      roomId: BuddyArgs.textOrNull(a, 'roomId'),
      userId: BuddyArgs.textOrNull(a, 'userId'),
      name: BuddyArgs.textOrNull(a, 'name'),
      photoUrl: BuddyArgs.textOrNull(a, 'photoUrl'),
      tripId: BuddyArgs.textOrNull(a, 'tripId'),
    );
  }),
  _page(AppRoutes.seekerPlus, () => SeekerPlusScreen(from: BuddyArgs.textOrNull(BuddyArgs.current, 'from'))),
];
