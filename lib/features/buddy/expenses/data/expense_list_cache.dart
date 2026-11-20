import 'package:get_storage/get_storage.dart';

import '../../shared/buddy_json.dart';
import '../models/expense_models.dart';

abstract class ExpenseCacheStore {
  Object? read(String key);
  void write(String key, Object value);
}

class _BoxStore implements ExpenseCacheStore {
  GetStorage get _box => GetStorage();

  @override
  Object? read(String key) => _box.read<Object?>(key);

  @override
  void write(String key, Object value) => _box.write(key, value);
}

class MemoryExpenseCacheStore implements ExpenseCacheStore {
  final Map<String, Object> data = {};

  @override
  Object? read(String key) => data[key];

  @override
  void write(String key, Object value) => data[key] = value;
}

abstract final class ExpenseListCache {
  static const String prefix = 'trip_expenses_cache:';
  static ExpenseCacheStore store = _BoxStore();

  static String key(String tripId) => '$prefix$tripId';

  static void save(ExpenseList list) {
    try {
      store.write(key(list.tripId), list.toJson());
    } catch (_) {}
  }

  static ExpenseList? read(String tripId) {
    try {
      final raw = BuddyJson.mapOrNull(store.read(key(tripId)));
      return raw == null ? null : ExpenseList.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static void debugReset() => store = _BoxStore();
}
