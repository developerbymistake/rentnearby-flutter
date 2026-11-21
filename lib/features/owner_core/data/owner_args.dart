import 'package:get/get.dart';

abstract final class OwnerArgs {
  static Map<String, dynamic> get current => of(Get.arguments);

  static Map<String, dynamic> of(Object? a) {
    if (a is! Map) return const {};
    return {for (final e in a.entries) if (e.key is String) e.key as String: e.value};
  }

  static String? text(Map<String, dynamic> a, String key) {
    final v = a[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  static int? number(Map<String, dynamic> a, String key) {
    final v = a[key];
    return v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
  }

  static bool flag(Map<String, dynamic> a, String key) => a[key] == true || a[key] == 'true';
}
