import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

class UserRepository {
  UserModel? _profileCache;
  DateTime? _profileCacheTime;
  static const _ttl = Duration(seconds: 60);

  bool _isValid() => isCacheValid(_profileCacheTime, _ttl);

  Future<UserModel?> getProfile() async {
    if (_profileCache != null && _isValid()) return _profileCache;
    try {
      final res = await ApiService.get('/users/profile');
      _profileCache = UserModel.fromJson(res['data']);
      _profileCacheTime = DateTime.now();
      return _profileCache;
    } catch (_) {
      return null;
    }
  }

  void invalidate() {
    _profileCache = null;
    _profileCacheTime = null;
  }
}
