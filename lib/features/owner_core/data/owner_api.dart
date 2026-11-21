import '../../../services/api_service.dart';
import '../../buddy/shared/buddy_api_base.dart';
import '../json/owner_json.dart';
import 'owner_result.dart';

abstract class OwnerTransport {
  const OwnerTransport();
  Future<Map<String, dynamic>> get(String path, Map<String, dynamic>? params);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body);
  Future<Map<String, dynamic>> delete(String path, Map<String, dynamic>? params);
}

class ApiServiceTransport extends OwnerTransport {
  const ApiServiceTransport();
  @override
  Future<Map<String, dynamic>> get(String path, Map<String, dynamic>? params) => ApiService.get(path, params: params);
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) => ApiService.post(path, body);
  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) => ApiService.put(path, body);
  @override
  Future<Map<String, dynamic>> delete(String path, Map<String, dynamic>? params) => ApiService.deleteJson(path, params: params);
}

abstract final class OwnerApi {
  static OwnerTransport transport = const ApiServiceTransport();

  static void debugReset() => transport = const ApiServiceTransport();

  static Future<OwnerResult<T>> run<T>(Future<T> Function() call) => BuddyApiBase.run(call);

  static Future<T> read<T>(Future<T> Function() call) => BuddyApiBase.read(call);

  static Map<String, dynamic> dataOf(Map<String, dynamic> res) => OwnerJson.map(res['data']);

  static Map<String, dynamic> query(Map<String, Object?> params) => BuddyApiBase.query(params);

  static Future<OwnerResult<T>> get<T>(String path, T Function(Map<String, dynamic> data) parse, {Map<String, Object?> params = const {}}) =>
      run(() => read(() async => parse(dataOf(await transport.get(path, params.isEmpty ? null : query(params))))));

  static Future<OwnerResult<T>> post<T>(String path, Map<String, dynamic> body, T Function(Map<String, dynamic> data) parse) =>
      run(() async => parse(dataOf(await transport.post(path, body))));

  static Future<OwnerResult<T>> put<T>(String path, Map<String, dynamic> body, T Function(Map<String, dynamic> data) parse) =>
      run(() async => parse(dataOf(await transport.put(path, body))));

  static Future<OwnerResult<void>> delete(String path, {Map<String, Object?> params = const {}}) => run(() async {
        await transport.delete(path, params.isEmpty ? null : query(params));
      });
}
