import 'package:dio/dio.dart';

import 'dio_error_mapper.dart';

class AccountDeleteBlock {
  const AccountDeleteBlock({
    required this.code,
    required this.message,
    this.action,
    this.targetId,
    this.side = 'Self',
    this.reasonKey,
    this.route,
    this.args = const {},
    this.title,
  });

  final String code;
  final String message;
  final String? action;
  final String? targetId;
  final String side;
  final String? reasonKey;
  final String? route;
  final Map<String, dynamic> args;
  final String? title;

  int get count {
    final c = args['count'];
    return c is num ? c.toInt() : 1;
  }

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  static AccountDeleteBlock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = _text(raw['code']);
    final message = _text(raw['message']);
    if (code == null && message == null) return null;
    final args = raw['args'];
    return AccountDeleteBlock(
      code: code ?? '',
      message: message ?? '',
      action: _text(raw['action']),
      targetId: _text(raw['targetId']),
      side: _text(raw['side']) ?? 'Self',
      reasonKey: _text(raw['reasonKey']),
      route: _text(raw['route']),
      args: args is Map ? {for (final e in args.entries) if (e.key is String) e.key as String: e.value} : const {},
      title: _text(raw['title']),
    );
  }
}

class AccountDeleteMessage {
  const AccountDeleteMessage._();

  static const errorType = 'AccountHasActiveItems';

  static const _byCode = <String, String>{
    'ActiveTaxiBooking': 'You have an active taxi booking. You can delete your account after it ends.',
    'ActiveStayBooking': 'You have an active stay booking. You can delete your account after it ends.',
    'SelectedTaxiOffer': 'A traveller has chosen you. Confirm or decline the trip first.',
    'OpenTaxiRequest': 'You have an open taxi request. Cancel it first.',
    'OpenStayEnquiry': 'You have an open stay enquiry. Close it first.',
    'LiveListing': 'Take your listing offline first.',
  };

  static const fallback = 'You cannot delete your account right now. Finish your active items first.';

  /// One block per server reason, in server order; null when [e] is not a 409 AccountHasActiveItems.
  static List<AccountDeleteBlock>? blocks(dynamic e) {
    if (e is! DioException || e.response?.statusCode != 409) return null;
    if (DioErrorMapper.errorType(e) != errorType) return null;
    final data = e.response?.data;
    final inner = data is Map ? data['data'] : null;
    final reasons = inner is Map ? inner['reasons'] : null;
    final out = <AccountDeleteBlock>[];
    if (reasons is List) {
      for (final r in reasons) {
        final b = AccountDeleteBlock.fromJson(r);
        if (b != null) out.add(b);
      }
    }
    if (out.isEmpty) {
      final msg = data is Map && data['error'] is Map ? (data['error'] as Map)['message'] : null;
      out.add(AccountDeleteBlock(code: '', message: msg is String && msg.trim().isNotEmpty ? msg : fallback));
    }
    return out;
  }

  static String lineOf(AccountDeleteBlock b) => _byCode[b.code] ?? (b.message.isNotEmpty ? b.message : fallback);

  /// Null when [e] is not a 409 AccountHasActiveItems.
  static String? from(dynamic e) => lines(e)?.join('\n');

  /// One message per blocking reason; null when [e] is not a 409 AccountHasActiveItems.
  static List<String>? lines(dynamic e) {
    if (e is! DioException || e.response?.statusCode != 409) return null;
    if (DioErrorMapper.errorType(e) != errorType) return null;
    final data = e.response?.data;
    final out = <String>[];
    final reasons = data is Map ? (data['data'] is Map ? (data['data'] as Map)['reasons'] : null) : null;
    if (reasons is List) {
      for (final r in reasons) {
        if (r is! Map) continue;
        final code = r['code'];
        final server = r['message'];
        final line = _byCode[code] ?? (server is String && server.trim().isNotEmpty ? server : null);
        if (line != null && !out.contains(line)) out.add(line);
      }
    }
    if (out.isEmpty) {
      final msg = data is Map && data['error'] is Map ? (data['error'] as Map)['message'] : null;
      return [msg is String && msg.trim().isNotEmpty ? msg : fallback];
    }
    return out;
  }
}
