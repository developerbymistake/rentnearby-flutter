import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../services/api_service.dart';
import '../../../../utils/photo_upload/app_photo_pick.dart';
import '../../../owner_core/data/owner_api.dart';
import '../../../owner_core/data/owner_result.dart';
import '../../../owner_core/json/owner_json.dart';
import 'quote_models.dart';

// Every call of /api/v1/stays/me/quotation (BUILD_PLAN 4.1). No guest field is ever sent.
class QuoteApi {
  const QuoteApi();

  static const base = '/stays/me/quotation';

  Future<OwnerResult<QuoteHubResponse>> hub({String? etag}) => OwnerApi.run(() async {
        final res = await OwnerApi.read(() => ApiService.getRaw(base, headers: etag == null ? null : {'If-None-Match': etag}));
        final tag = res.headers.value('etag') ?? etag;
        if (res.statusCode == 304) return QuoteHubResponse(notModified: true, etag: tag);
        return QuoteHubResponse(notModified: false, etag: tag, hub: QuoteHub.fromJson(OwnerApi.dataOf(OwnerJson.map(res.data))));
      });

  Future<OwnerResult<QuoteBank?>> bank() => OwnerApi.run(() async {
        final res = await OwnerApi.read(() => ApiService.get('$base/profile/bank'));
        final data = OwnerJson.mapOrNull(res['data']);
        return data == null ? null : QuoteBank.fromJson(data);
      });

  Future<OwnerResult<QuoteProfile>> saveProfile(QuoteProfileInput input) =>
      OwnerApi.put('$base/profile', input.toJson(), QuoteProfile.fromJson);

  Future<OwnerResult<int>> putImage(QuoteImageKind kind, String filePath, {void Function(int sent, int total)? onProgress}) =>
      OwnerApi.run(() async {
        final form = FormData.fromMap({'photo': await AppPhotoPick.multipart(filePath)});
        final res = await ApiService.putFormData('$base/${kind.wire}', form, onSendProgress: onProgress);
        return OwnerJson.integer(OwnerApi.dataOf(res)['assetsVersion']);
      });

  Future<OwnerResult<int>> deleteImage(QuoteImageKind kind) => OwnerApi.run(() async {
        final res = await OwnerApi.transport.delete('$base/${kind.wire}', null);
        return OwnerJson.integer(OwnerApi.dataOf(res)['assetsVersion']);
      });

  // The server-stripped JPEG of the caller's own image; 404 = none saved.
  Future<OwnerResult<Uint8List>> image(QuoteImageKind kind) => OwnerApi.run(() async {
        final res = await OwnerApi.read(() => ApiService.getRaw('$base/image/${kind.wire}', responseType: ResponseType.bytes));
        final data = res.data;
        if (data is Uint8List) return data;
        if (data is List<int>) return Uint8List.fromList(data);
        throw StateError('no image bytes');
      });

  Future<OwnerResult<QuoteTermsAccepted>> acceptTerms({required int version, required String appVersion}) =>
      OwnerApi.post('$base/terms/accept', {'version': version, 'appVersion': appVersion}, QuoteTermsAccepted.fromJson);

  Future<OwnerResult<QuoteReserveResult>> reserve({required String documentId, required QuoteKind kind}) =>
      OwnerApi.post('$base/reserve', {'documentId': documentId, 'kind': kind.wire}, QuoteReserveResult.fromJson);

  Future<OwnerResult<String?>> nameChange({required String name, String? note}) => OwnerApi.post(
        '$base/name-change',
        {'name': name, 'note': (note ?? '').isEmpty ? null : note},
        (d) => OwnerJson.strOrNull(d['pendingName']),
      );
}
