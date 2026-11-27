import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/buddy/buddies/data/buddies_api.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:get/get.dart';

String seedFor(String base, int index) {
  var seed = base;
  var n = 0;
  while (BuddyLook.avatarIndex(seed) != index) {
    seed = '$base-${n++}';
  }
  return seed;
}

final rahulId = seedFor('rahul', 0);
final vikasId = seedFor('vikas', 1);
final nehaId = seedFor('neha', 2);
final priyaId = seedFor('priya', 3);
final amanId = seedFor('aman', 4);
final vikramId = seedFor('vikram', 5);
final karanId = seedFor('karan', 1);

BuddyPerson person(String id, String name, String username) => BuddyPerson(userId: id, name: name, username: username, initial: name[0]);

BuddyPerson get aman => person(amanId, 'Aman', 'Bakhli#61408275');
BuddyPerson get neha => person(nehaId, 'Neha', 'Bakhli#73019462');
BuddyPerson get vikram => person(vikramId, 'Vikram', 'Bakhli#29583047');
BuddyPerson get karan => person(karanId, 'Karan', 'Bakhli#35196843');
BuddyPerson get vikas => person(vikasId, 'Vikas', 'Bakhli#83720518');
BuddyPerson get rahul => person(rahulId, 'Rahul', 'Bakhli#48291736');
BuddyPerson get priya => person(priyaId, 'Priya', 'Bakhli#50267139');

BuddyItem item(BuddyPerson p, {bool isNew = false}) =>
    BuddyItem(userId: p.userId, name: p.name, username: p.username, initial: p.initial, isNew: isNew);

BuddyRefused<T> refused<T>(int status, [String? type, int? retryAfter]) => BuddyRefused<T>(type: type, statusCode: status, retryAfterSeconds: retryAfter);

const reasons = [
  ReportReason(id: 'r1', name: 'Spam'),
  ReportReason(id: 'r2', name: 'Harassment'),
  ReportReason(id: 'r3', name: 'Fake account'),
  ReportReason(id: 'r4', name: 'Other'),
];

class FakeBuddiesApi extends BuddiesApi {
  FakeBuddiesApi();

  final calls = <String>[];
  final sources = <String>[];
  ReportInput? lastAlsoReport;
  String? lastContext;
  bool? lastAlsoBlock;

  BuddyResult<FindResult> findResult = const BuddyOk(FindResult(found: false));
  BuddyResult<BuddyList> buddiesResult = const BuddyOk(BuddyList(items: [], count: 0));
  BuddyResult<void> removeResult = const BuddyOk(null);
  BuddyResult<BuddySummary> summaryResult = const BuddyOk(BuddySummary());
  BuddyResult<void> blockResult = const BuddyOk(null);
  BuddyResult<void> unblockResult = const BuddyOk(null);
  BuddyResult<BlockedList> blocksResult = const BuddyOk(BlockedList(items: [], count: 0));
  BuddyResult<void> reportResult = const BuddyOk(null);
  BuddyResult<List<ReportReason>> reasonsResult = const BuddyOk(reasons);
  BuddyResult<BlockContext> blockContextResult = const BuddyOk(BlockContext(tripsInCommon: []));

  @override
  Future<BuddyResult<FindResult>> find(String query, {required String source}) async {
    calls.add('find:$query');
    sources.add(source);
    return findResult;
  }

  @override
  Future<BuddyResult<BuddyList>> buddies({String? cursor, int limit = 50, String? forTripId}) async {
    calls.add('buddies:${cursor ?? ''}');
    return buddiesResult;
  }

  @override
  Future<BuddyResult<void>> remove(String userId) async {
    calls.add('remove:$userId');
    return removeResult;
  }

  @override
  Future<BuddyResult<BuddySummary>> summary() async => summaryResult;

  @override
  Future<BuddyResult<void>> block(String userId, {ReportInput? alsoReport, String? context}) async {
    calls.add('block:$userId');
    lastAlsoReport = alsoReport;
    lastContext = context;
    return blockResult;
  }

  @override
  Future<BuddyResult<void>> unblock(String userId) async {
    calls.add('unblock:$userId');
    return unblockResult;
  }

  @override
  Future<BuddyResult<BlockedList>> blocks({String? cursor}) async => blocksResult;

  @override
  Future<BuddyResult<void>> report(String userId, {required String reasonId, String? note, required bool alsoBlock, required String context}) async {
    calls.add('report:$userId:$reasonId');
    lastAlsoBlock = alsoBlock;
    lastContext = context;
    return reportResult;
  }

  @override
  Future<BuddyResult<List<ReportReason>>> reportReasons() async => reasonsResult;

  @override
  Future<BuddyResult<BlockContext>> blockContext(String userId) async => blockContextResult;
}

class FakeTabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void putMe({String username = 'Bakhli#48291736'}) {
  Get.put<TabConfigController>(FakeTabs());
  final a = Get.put<AuthController>(FakeAuth());
  a.profileName.value = 'Rahul';
  a.user.value = UserModel(id: rahulId, phoneNumber: '9876543210', isPhoneVerified: true, name: 'Rahul', username: username, createdAt: DateTime(2026), roleConfirmed: true);
}
