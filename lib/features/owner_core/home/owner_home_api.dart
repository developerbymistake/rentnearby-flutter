import '../data/owner_api.dart';
import '../data/owner_result.dart';
import 'owner_home_models.dart';

class OwnerHomeApi {
  const OwnerHomeApi();

  static const String path = '/owner/home';

  Future<OwnerResult<OwnerHomeDto>> load() => OwnerApi.get(path, OwnerHomeDto.fromJson);
}
