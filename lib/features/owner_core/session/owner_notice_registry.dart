import '../../buddy/notices/models/notice_models.dart';
import '../../buddy/notices/notice_copy.dart';

typedef OwnerNoticeCopy = NoticeView? Function(Notice notice);

abstract final class OwnerNoticeRegistry {
  static final Map<String, OwnerNoticeCopy> _byKind = {};

  static void register(String kind, OwnerNoticeCopy copy) => _byKind[kind] = copy;

  static void reset() => _byKind.clear();

  static bool knows(String kind) => _byKind.containsKey(kind);

  static NoticeView? of(Notice notice) {
    final copy = _byKind[notice.kind];
    if (copy == null) return null;
    try {
      return copy(notice);
    } catch (_) {
      return null;
    }
  }

  static NoticeView? viewOf(Notice notice) => NoticeCopy.of(notice) ?? of(notice);
}
