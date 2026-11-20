import 'dart:convert';

import 'package:get_storage/get_storage.dart';

import 'expense_op.dart';

abstract class QueueBox {
  Future<void> init();
  Object? read(String key);
  Future<void> write(String key, Object value);
  Future<void> remove(String key);
  Iterable<String> get keys;
}

class GetStorageQueueBox implements QueueBox {
  static const String name = 'buddy_expense_queue_v1';
  Future<bool>? _init;

  GetStorage get _box => GetStorage(name);

  @override
  Future<void> init() => _init ??= GetStorage.init(name);

  @override
  Object? read(String key) => _box.read<Object?>(key);

  @override
  Future<void> write(String key, Object value) => _box.write(key, value);

  @override
  Future<void> remove(String key) => _box.remove(key);

  @override
  Iterable<String> get keys => _box.getKeys<Iterable<dynamic>>().whereType<String>();
}

class MemoryQueueBox implements QueueBox {
  final Map<String, Object> data = {};

  @override
  Future<void> init() async {}

  @override
  Object? read(String key) => data[key];

  @override
  Future<void> write(String key, Object value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  Iterable<String> get keys => data.keys.toList();
}

class ExpenseQueueStore {
  ExpenseQueueStore({QueueBox? box, DateTime Function()? now}) : box = box ?? GetStorageQueueBox(), _now = now ?? DateTime.now;

  static const Duration keepOthers = Duration(days: 30);

  final QueueBox box;
  final DateTime Function() _now;
  Future<void> _chain = Future.value();

  static String queueKey(String userId) => 'q:$userId';
  static String lostKey(String userId) => 'lost:$userId';
  static String seenKey(String userId) => 'seen:$userId';

  Future<void> init() => box.init();

  Future<T> _run<T>(Future<T> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  List<ExpenseOp> load(String userId) {
    final raw = box.read(queueKey(userId));
    try {
      final list = raw is String ? jsonDecode(raw) : raw;
      if (list is! List) return [];
      return [for (final e in list) if (e is Map) ExpenseOp.fromJson(Map<String, dynamic>.from(e))];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String userId, List<ExpenseOp> ops) => _run(() async {
        if (ops.isEmpty) {
          await box.remove(queueKey(userId));
        } else {
          await box.write(queueKey(userId), jsonEncode([for (final o in ops) o.toJson()]));
        }
        await box.write(seenKey(userId), _now().toUtc().toIso8601String());
      });

  int lost(String userId) {
    final v = box.read(lostKey(userId));
    return v is int ? v : (v is num ? v.toInt() : 0);
  }

  Future<void> addLost(String userId, int n) => _run(() async {
        if (n > 0) await box.write(lostKey(userId), lost(userId) + n);
      });

  Future<void> clearLost(String userId) => _run(() => box.remove(lostKey(userId)));

  Future<void> clear(String userId) => _run(() async {
        await box.remove(queueKey(userId));
        await box.remove(lostKey(userId));
        await box.remove(seenKey(userId));
      });

  Future<void> touchAndPrune(String userId) => _run(() async {
        final now = _now().toUtc();
        await box.write(seenKey(userId), now.toIso8601String());
        for (final key in box.keys.where((k) => k.startsWith('seen:')).toList()) {
          final other = key.substring(5);
          if (other == userId) continue;
          final seen = DateTime.tryParse('${box.read(key)}');
          if (seen != null && now.difference(seen) < keepOthers) continue;
          await box.remove(queueKey(other));
          await box.remove(lostKey(other));
          await box.remove(key);
        }
      });
}
