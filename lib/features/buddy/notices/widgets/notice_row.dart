import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_notifications.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../models/notice_models.dart';
import '../notice_copy.dart';

class NoticeRow extends StatelessWidget {
  const NoticeRow({super.key, required this.notice, required this.onTap, this.now});

  final Notice notice;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final view = NoticeCopy.of(notice);
    if (view == null) return const SizedBox.shrink();
    final (time, unit) = BuddyFormat.agoParts(notice.updatedAt ?? notice.createdAt, now: now);
    return NoticeCard(view: view, time: time, unit: unit, isRead: notice.isRead, onTap: onTap);
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.view, required this.time, required this.unit, required this.isRead, this.onTap});

  final NoticeView view;
  final String time;
  final String unit;
  final bool isRead;
  final VoidCallback? onTap;

  static ListingTone toneOf(NoticeTone t) => switch (t) {
        NoticeTone.teal => BuddyLook.teal,
        NoticeTone.indigo => BuddyLook.indigo,
        NoticeTone.rose => BuddyLook.rose,
      };

  @override
  Widget build(BuildContext context) => NotificationCard3D(
        tone: toneOf(view.tone),
        art: view.art,
        title: view.title,
        body: view.body,
        time: time,
        unit: unit,
        tag: view.tag,
        isNew: !isRead,
        read: isRead,
        opens: true,
        onTap: onTap,
      );
}
