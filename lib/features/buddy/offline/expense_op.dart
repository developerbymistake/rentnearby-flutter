import '../expenses/models/expense_models.dart';
import '../shared/buddy_json.dart';

enum OpKind { create, edit, delete }

enum OpState { waiting, notSaved }

enum OpAction { refresh, edit, remove }

class ExpenseOp {
  const ExpenseOp({
    required this.opId,
    required this.kind,
    required this.tripId,
    required this.expenseId,
    required this.baseVersion,
    this.body,
    this.paymentsAcknowledged = false,
    required this.shown,
    this.state = OpState.waiting,
    this.failType,
    this.failMessage,
    this.failAction,
    this.attempts = 0,
    required this.createdAt,
  });

  final String opId;
  final OpKind kind;
  final String tripId;
  final String expenseId;
  final int baseVersion;
  final ExpenseWriteRequest? body;
  final bool paymentsAcknowledged;
  final ExpenseItem shown;
  final OpState state;
  final String? failType;
  final String? failMessage;
  final OpAction? failAction;
  final int attempts;
  final DateTime createdAt;

  bool get waiting => state == OpState.waiting;
  bool get notSaved => state == OpState.notSaved;

  List<String> get peopleIds {
    final b = body;
    if (b == null) return [shown.paidByUserId];
    return [b.paidByUserId, ...b.sharers, for (final s in b.shares) s.userId];
  }

  ExpenseOp copyWith({OpState? state, String? failType, String? failMessage, OpAction? failAction, int? attempts}) => ExpenseOp(
        opId: opId,
        kind: kind,
        tripId: tripId,
        expenseId: expenseId,
        baseVersion: baseVersion,
        body: body,
        paymentsAcknowledged: paymentsAcknowledged,
        shown: shown,
        state: state ?? this.state,
        failType: failType ?? this.failType,
        failMessage: failMessage ?? this.failMessage,
        failAction: failAction ?? this.failAction,
        attempts: attempts ?? this.attempts,
        createdAt: createdAt,
      );

  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  factory ExpenseOp.fromJson(Map<String, dynamic> j) {
    final body = BuddyJson.mapOrNull(j['body']);
    final action = j['failAction'];
    return ExpenseOp(
      opId: BuddyJson.str(j['opId']),
      kind: _enum(OpKind.values, j['kind'], OpKind.create),
      tripId: BuddyJson.str(j['tripId']),
      expenseId: BuddyJson.str(j['expenseId']),
      baseVersion: BuddyJson.integer(j['baseVersion']),
      body: body == null ? null : ExpenseWriteRequest.fromJson(body),
      paymentsAcknowledged: BuddyJson.boolean(j['paymentsAcknowledged']),
      shown: ExpenseItem.fromJson(BuddyJson.map(j['shown'])),
      state: _enum(OpState.values, j['state'], OpState.waiting),
      failType: BuddyJson.strOrNull(j['failType']),
      failMessage: BuddyJson.strOrNull(j['failMessage']),
      failAction: action == null ? null : _enum(OpAction.values, action, OpAction.remove),
      attempts: BuddyJson.integer(j['attempts']),
      createdAt: BuddyJson.time(j['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'kind': kind.name,
        'tripId': tripId,
        'expenseId': expenseId,
        'baseVersion': baseVersion,
        'body': body?.toJson(),
        'paymentsAcknowledged': paymentsAcknowledged,
        'shown': shown.toJson(),
        'state': state.name,
        'failType': failType,
        'failMessage': failMessage,
        'failAction': failAction?.name,
        'attempts': attempts,
        'createdAt': BuddyJson.timeText(createdAt),
      };
}
