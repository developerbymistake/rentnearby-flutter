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
    final oldItems = <InboxItem>[
      for (final r in oldRows)
        if (!(noticesHasMore && oldestNotice != null && r.createdAt.isBefore(oldestNotice))) OldRowItem(r),
    ];
    final noticeItems = <InboxItem>[
      for (final n in notices)
        if (!(oldHasMore && oldestOld != null && noticeTime(n).isBefore(oldestOld))) NoticeItem(n),
    ];
    final merged = <InboxItem>[];
    var a = 0;
    var b = 0;
    while (a < oldItems.length && b < noticeItems.length) {
      merged.add(oldItems[a].time.isBefore(noticeItems[b].time) ? noticeItems[b++] : oldItems[a++]);
    }
    while (a < oldItems.length) {
      merged.add(oldItems[a++]);
    }
    while (b < noticeItems.length) {
      merged.add(noticeItems[b++]);
    }
    return merged;
  }
}
