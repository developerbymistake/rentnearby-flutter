import 'package:get/get.dart';

import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../data/notices_api.dart';
import '../models/notice_models.dart';

class NoticesController extends GetxController {
  NoticesController({this.api = const NoticesApi()});

  static NoticesController? get maybe => Get.isRegistered<NoticesController>() ? Get.find<NoticesController>() : null;

  final NoticesApi api;
  final notices = <Notice>[].obs;
  final unread = 0.obs;
  final nextCursor = RxnString();
  Worker? _live;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(BuddyLive.notices, (_) => refreshFirstPage());
  }

  Future<void> refreshFirstPage() async {
    final r = await api.list();
    if (r is BuddyOk<NoticePage>) {
      notices.assignAll(r.value.items.where((n) => n.isKnown));
      nextCursor.value = r.value.nextCursor;
      unread.value = r.value.unread;
    }
  }

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }
}
