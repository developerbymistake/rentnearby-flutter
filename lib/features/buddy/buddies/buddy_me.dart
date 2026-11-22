import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../buddy_strings.dart';

class BuddyMe {
  const BuddyMe({required this.userId, required this.name, this.username, this.photoUrl});

  final String userId;
  final String name;
  final String? username;
  final String? photoUrl;

  String get initial => BuddyStrings.initialOf(name);

  static BuddyMe read() {
    if (!Get.isRegistered<AuthController>()) return const BuddyMe(userId: '', name: '');
    final a = Get.find<AuthController>();
    final u = a.user.value;
    final name = a.profileName.value.isNotEmpty ? a.profileName.value : (u?.name ?? '');
    return BuddyMe(userId: u?.id ?? '', name: name, username: u?.username, photoUrl: u?.profilePhotoUrl);
  }
}
