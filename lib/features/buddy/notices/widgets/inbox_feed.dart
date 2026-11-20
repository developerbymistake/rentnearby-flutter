import '../../../../models/notification_model.dart';
import '../models/notice_models.dart';

sealed class InboxItem {
  const InboxItem();
  DateTime get time;
  String get key;
}

final class OldRowItem extends InboxItem {
  const OldRowItem(this.row);
  final NotificationModel row;

  @override
  DateTime get time => row.createdAt;

  @override
  String get key => 'o:${row.id}';
}

final class NoticeItem extends InboxItem {
  const NoticeItem(this.notice);
  final Notice notice;

  @override
  DateTime get time => InboxFeed.noticeTime(notice);

  @override
  String get key => 'n:${notice.id}';
}

abstract final class InboxFeed {
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime noticeTime(Notice n) => n.updatedAt ?? n.createdAt ?? _epoch;

  static List<InboxItem> merge(List<NotificationModel> oldRows, List<Notice> notices, {bool oldHasMore = false, bool noticesHasMore = false}) {
    DateTime? oldestOld;
    for (final r in oldRows) {
      if (oldestOld == null || r.createdAt.isBefore(oldestOld)) oldestOld = r.createdAt;
    }
    DateTime? oldestNotice;
    for (final n in notices) {
      final t = noticeTime(n);
      if (oldestNotice == null || t.isBefore(oldestNotice)) oldestNotice = t;
    }
    final items = <InboxItem>[
      for (final r in oldRows)
        if (!(noticesHasMore && oldestNotice != null && r.createdAt.isBefore(oldestNotice))) OldRowItem(r),
      for (final n in notices)
        if (!(oldHasMore && oldestOld != null && noticeTime(n).isBefore(oldestOld))) NoticeItem(n),
    ];
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final c = b.$2.time.compareTo(a.$2.time);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}
