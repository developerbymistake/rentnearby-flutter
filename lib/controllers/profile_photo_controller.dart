import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show DioException, FormData;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide FormData;

import '../config/profile_photo_strings.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_toast.dart';
import '../utils/photo_upload/app_photo_pick.dart';
import '../utils/photo_upload/photo_pick_strings.dart';
import '../utils/photo_upload/profile_photo_pick.dart';
import 'auth_controller.dart';

typedef ProfilePhotoPicker = Future<File?> Function(BuildContext context);
typedef ProfilePhotoSender = Future<Map<String, dynamic>> Function(String path, void Function(int sent, int total) onProgress);
typedef OfflineCheck = Future<bool> Function();
typedef ProfilePhotoRemover = Future<Map<String, dynamic>> Function();

class ProfilePhotoController extends GetxController {
  ProfilePhotoController({ProfilePhotoPicker? pick, ProfilePhotoSender? send, OfflineCheck? offline, ProfilePhotoRemover? remove})
      : _pick = pick ?? ProfilePhotoPick.pick,
        _send = send ?? _put,
        _offline = offline ?? _connectivityOffline,
        _remove = remove ?? _delete;

  @visibleForTesting
  static ProfilePhotoController Function() create = ProfilePhotoController.new;

  // Session-scoped: a route-bound instance is closed when offAllNamed disposes its first route.
  static ProfilePhotoController ensure() => Get.isRegistered<ProfilePhotoController>()
      ? Get.find<ProfilePhotoController>()
      : Get.put(create(), permanent: true);

  static const String path = '/users/me/photo';

  final ProfilePhotoPicker _pick;
  final ProfilePhotoSender _send;
  final OfflineCheck _offline;
  final ProfilePhotoRemover _remove;

  final busy = false.obs;
  final failed = false.obs;
  final localPath = RxnString();
  final progress = 0.0.obs;

  bool _picking = false;
  int _seq = 0;
  String? _settled;

  // The last uploaded file: shown while the new url loads, deleted on the next success or on close.
  String? get placeholderPath => _settled;

  bool get active => _picking || busy.value;

  // False (and a toast) when offline.
  Future<bool> online() async {
    if (!await _offline()) return true;
    AppToast.warning(ProfilePhotoStrings.offline);
    return false;
  }

  Future<bool> choose(BuildContext context) async {
    if (active) return false;
    _picking = true;
    try {
      if (!await online()) return false;
      if (!context.mounted) return false;
      final file = await _pick(context);
      if (file == null || isClosed) return false;
      _dropTemp(localPath.value);
      localPath.value = file.path;
      failed.value = false;
      return true;
    } finally {
      _picking = false;
    }
  }

  Future<bool> upload() async {
    final file = localPath.value;
    if (file == null || busy.value || isClosed) return false;
    if (!File(file).existsSync()) {
      _forget(PhotoPickStrings.pickFailed);
      return false;
    }
    final auth = Get.find<AuthController>();
    final userId = auth.user.value?.id;
    final my = ++_seq;
    busy.value = true;
    failed.value = false;
    progress.value = 0;
    try {
      final res = await _send(file, (sent, total) {
        if (my == _seq && total > 0) progress.value = (sent / total).clamp(0.0, 1.0);
      });
      if (my != _seq || auth.user.value?.id != userId) return false;
      final data = res['data'];
      if (data is! Map<String, dynamic>) throw const FormatException('no user');
      final updated = UserModel.fromJson(data);
      final oldUrl = auth.user.value?.profilePhotoUrl;
      auth.applyUser(updated);
      if (oldUrl != null && oldUrl != updated.profilePhotoUrl) _evict(oldUrl);
      if (_settled != file) _dropTemp(_settled);
      _settled = file;
      localPath.value = null;
      progress.value = 1;
      return true;
    } catch (e) {
      if (my != _seq) return false;
      final refused = _refusal(e);
      if (refused != null) {
        _forget(refused);
      } else {
        failed.value = true;
      }
      return false;
    } finally {
      if (my == _seq) busy.value = false;
    }
  }

  Future<bool> retry() => upload();

  Future<bool> remove() async {
    if (active || isClosed) return false;
    if (!await online()) return false;
    final auth = Get.find<AuthController>();
    final userId = auth.user.value?.id;
    final my = ++_seq;
    busy.value = true;
    try {
      final res = await _remove();
      if (my != _seq || auth.user.value?.id != userId) return false;
      final data = res['data'];
      if (data is! Map<String, dynamic>) throw const FormatException('no user');
      final oldUrl = auth.user.value?.profilePhotoUrl;
      auth.applyUser(UserModel.fromJson(data));
      if (oldUrl != null) _evict(oldUrl);
      _dropTemp(localPath.value);
      _dropTemp(_settled);
      _settled = null;
      localPath.value = null;
      failed.value = false;
      AppToast.success(ProfilePhotoStrings.removed);
      return true;
    } catch (_) {
      if (my == _seq && !isClosed) AppToast.error(ProfilePhotoStrings.removeFailed);
      return false;
    } finally {
      if (my == _seq) busy.value = false;
    }
  }

  void discard() {
    if (active) return;
    _dropTemp(localPath.value);
    localPath.value = null;
    failed.value = false;
  }

  // The file cannot be sent again (gone or refused by the server): back to the picker.
  void _forget(String message) {
    _dropTemp(localPath.value);
    localPath.value = null;
    failed.value = false;
    AppToast.error(message);
  }

  static String? _refusal(Object e) {
    if (e is! DioException) return null;
    final status = e.response?.statusCode;
    if (status != 400 && status != 413 && status != 415) return null;
    final data = e.response?.data;
    final message = data is Map ? (data['error'] is Map ? data['error']['message'] : null) : null;
    if (message is String && message.isNotEmpty) return message;
    return status == 413 ? PhotoPickStrings.tooLarge : PhotoPickStrings.wrongType;
  }

  Future<void> change(BuildContext context) async {
    if (!await choose(context)) return;
    await _uploadWithToast();
  }

  Future<void> retryChange() async {
    if (active || localPath.value == null) return;
    if (!await online()) return;
    await _uploadWithToast();
  }

  Future<void> _uploadWithToast() async {
    final ok = await upload();
    if (isClosed) return;
    if (ok) {
      AppToast.success(ProfilePhotoStrings.updated);
    } else if (failed.value) {
      AppToast.error(ProfilePhotoStrings.updateFailed);
    }
  }

  @override
  void onClose() {
    _seq++;
    _dropTemp(localPath.value);
    _dropTemp(_settled);
    _settled = null;
    localPath.value = null;
    busy.value = false;
    failed.value = false;
    progress.value = 0;
    super.onClose();
  }

  static void _evict(String url) {
    try {
      CachedNetworkImage.evictFromCache(url).catchError((_) => false);
    } catch (_) {}
  }

  static void _dropTemp(String? path) {
    if (path == null) return;
    try {
      File(path).delete().catchError((_) => File(path));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _put(String file, void Function(int, int) onProgress) async {
    final form = FormData.fromMap({'photo': await AppPhotoPick.multipart(file)});
    return ApiService.putFormData(path, form, onSendProgress: onProgress);
  }

  static Future<Map<String, dynamic>> _delete() => ApiService.deleteJson(path);

  static Future<bool> _connectivityOffline() async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2), onTimeout: () => const [ConnectivityResult.wifi]);
      return results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
