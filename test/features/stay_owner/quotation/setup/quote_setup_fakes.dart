import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_api.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_asset_store.dart';
import 'package:bakhli/features/stay_owner/quotation/data/quote_models.dart';
import 'package:bakhli/features/stay_owner/quotation/pdf/quote_engine.dart';

Map<String, dynamic> hubJson({
  bool approved = true,
  bool profile = true,
  int? acceptedVersion = 1,
  int used = 1,
  int limit = 2,
  String resetsAt = '2026-11-30T18:30:00Z',
  bool bankStorage = true,
  bool hasLogo = false,
  int assetsVersion = 3,
  String? pendingName,
}) =>
    {
      'stay': {'name': 'The Banyan Retreat', 'approved': approved, 'pendingName': pendingName, 'lastNameResult': null, 'hasGstin': true},
      'preparedBy': 'Meena Bisht',
      'profile': profile
          ? {
              'slogan': 'Riverside stays',
              'address': 'Village Dhikuli\nRamnagar',
              'phone': '+91 98370 41122',
              'email': 'stay@banyan.in',
              'gstin': '05ABCDE1234F1Z6',
              'bank': {'has': true, 'bank': 'State Bank of India', 'branch': 'Ramnagar', 'accountLast4': '4521', 'ifsc': 'SBIN0001234', 'upiMasked': 'ba***@sbi'},
              'termsText': 'Check-in 12 pm',
              'cancellationText': '15 days: full refund',
              'hasLogo': hasLogo,
              'hasSignature': false,
              'assetsVersion': assetsVersion,
              'updatedAt': '2026-11-27T08:00:00Z',
            }
          : null,
      'defaults': {'address': 'Stay address', 'phone': '9837041122', 'upi': 'banyan@sbi'},
      'terms': {'currentVersion': 1, 'acceptedVersion': acceptedVersion, 'acceptedAt': acceptedVersion == null ? null : '2026-11-12T07:55:00Z'},
      'usage': {'used': used, 'limit': limit, 'resetsAt': resetsAt, 'canUpgrade': true},
      'next': {'quotation': 42, 'proforma': 7},
      'bankStorage': bankStorage,
      'bankUnreadable': false,
      'minTemplateVersion': 1,
      'previewWatermark': true,
      'maxFreePerWindow': 5,
    };

QuoteHub hubOf({bool approved = true, bool profile = true, int? acceptedVersion = 1, bool bankStorage = true, bool hasLogo = false}) =>
    QuoteHub.fromJson(hubJson(approved: approved, profile: profile, acceptedVersion: acceptedVersion, bankStorage: bankStorage, hasLogo: hasLogo));

const sampleBank = QuoteBank(holder: 'Meena Bisht', accountNo: '123456784521', ifsc: 'SBIN0001234', bank: 'State Bank of India', branch: 'Ramnagar', upi: 'banyan@sbi');

class FakeQuoteApi implements QuoteApi {
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];

  OwnerResult<QuoteHubResponse> hubResult = OwnerOk(QuoteHubResponse(notModified: false, etag: '"e1"', hub: hubOf()));
  OwnerResult<QuoteBank?> bankResult = const OwnerOk(sampleBank);
  OwnerResult<QuoteProfile>? profileResult;
  OwnerResult<int> imagePutResult = const OwnerOk(4);
  OwnerResult<int> imageDeleteResult = const OwnerOk(5);
  OwnerResult<Uint8List> imageResult = OwnerOk(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]));
  OwnerResult<QuoteTermsAccepted> termsResult = OwnerOk(QuoteTermsAccepted(acceptedVersion: 1, acceptedAt: DateTime.utc(2026, 11, 27, 9)));
  OwnerResult<String?> nameResult = const OwnerOk('The Banyan Riverside Retreat');
  String? lastEtag;

  @override
  Future<OwnerResult<QuoteHubResponse>> hub({String? etag}) async {
    calls.add('hub');
    lastEtag = etag;
    return hubResult;
  }

  @override
  Future<OwnerResult<QuoteBank?>> bank() async {
    calls.add('bank');
    return bankResult;
  }

  @override
  Future<OwnerResult<QuoteProfile>> saveProfile(QuoteProfileInput input) async {
    calls.add('saveProfile');
    bodies.add(input.toJson());
    return profileResult ?? OwnerOk(QuoteProfile.fromJson({...hubJson()['profile'] as Map<String, dynamic>, 'updatedAt': '2026-11-27T10:00:00Z'}));
  }

  @override
  Future<OwnerResult<int>> putImage(QuoteImageKind kind, String filePath, {void Function(int sent, int total)? onProgress}) async {
    calls.add('putImage:${kind.wire}');
    onProgress?.call(1, 1);
    return imagePutResult;
  }

  @override
  Future<OwnerResult<int>> deleteImage(QuoteImageKind kind) async {
    calls.add('deleteImage:${kind.wire}');
    return imageDeleteResult;
  }

  @override
  Future<OwnerResult<Uint8List>> image(QuoteImageKind kind) async {
    calls.add('image:${kind.wire}');
    return imageResult;
  }

  @override
  Future<OwnerResult<QuoteTermsAccepted>> acceptTerms({required int version, required String appVersion}) async {
    calls.add('acceptTerms:$version');
    return termsResult;
  }

  @override
  Future<OwnerResult<QuoteReserveResult>> reserve({required String documentId, required QuoteKind kind}) async {
    calls.add('reserve');
    throw UnimplementedError();
  }

  @override
  Future<OwnerResult<String?>> nameChange({required String name, String? note}) async {
    calls.add('nameChange');
    bodies.add({'name': name, 'note': note});
    return nameResult;
  }
}

class FakeEngine implements QuoteEngineApi {
  final calls = <String>[];
  final images = <String, Uint8List>{};
  String root = '/data/quote';
  bool writeFiles = false;

  @override
  Future<String> storageDir() async => root;

  @override
  Future<void> putImage({required String userId, required QuoteImageKind kind, required int version, required Uint8List bytes}) async {
    calls.add('putImage:$userId:${kind.wire}:$version');
    images['$userId/${QuoteStorageNames.imageFile(kind, version)}'] = bytes;
    if (writeFiles) {
      final f = File('$root/$userId/${QuoteStorageNames.imageFile(kind, version)}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
    }
  }

  @override
  Future<void> clearUser(String userId) async => calls.add('clearUser:$userId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemKeyValue implements QuoteKeyValue {
  final values = <String, String>{};
  final deleted = <String>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    deleted.add(key);
    values.remove(key);
  }
}

class MemBoxes implements QuoteBoxes {
  final boxes = <String, Map<String, Map<String, dynamic>>>{};
  final erased = <String>[];

  @override
  Future<Map<String, dynamic>?> readJson(String box, String key) async => boxes[box]?[key];

  @override
  Future<void> writeJson(String box, String key, Map<String, dynamic> value) async => (boxes[box] ??= {})[key] = value;

  @override
  Future<void> erase(String box) async {
    erased.add(box);
    boxes.remove(box);
  }
}
