import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../data/follow_api.dart';
import '../social_error_types.dart';
import '../social_live.dart';
import '../social_strings.dart';
import 'follow_limit_sheet.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.userId,
    required this.iFollow,
    required this.followRequested,
    required this.followsMe,
    this.onChanged,
    this.onSettled,
    this.compact = false,
    this.light = false,
    this.api = const FollowApi(),
  });

  final String userId;
  final bool iFollow;
  final bool followRequested;
  final bool followsMe;
  final void Function(bool iFollow, bool requested)? onChanged;

  /// Called once with the server's final state after an accepted follow or unfollow.
  final void Function(bool iFollow, bool requested)? onSettled;
  final bool compact;
  final bool light;
  final FollowApi api;

  static String labelOf({required bool iFollow, required bool requested, required bool followsMe}) {
    if (requested) return SocialStrings.requested;
    if (iFollow) return SocialStrings.following;
    return followsMe ? SocialStrings.followBack : SocialStrings.follow;
  }

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _iFollow = widget.iFollow;
  late bool _requested = widget.followRequested;
  bool _busy = false;

  @override
  void didUpdateWidget(FollowButton old) {
    super.didUpdateWidget(old);
    if (!_busy && (old.iFollow != widget.iFollow || old.followRequested != widget.followRequested || old.userId != widget.userId)) {
      _iFollow = widget.iFollow;
      _requested = widget.followRequested;
    }
  }

  void _set(bool iFollow, bool requested) {
    SocialLive.followChange.trigger((widget.userId, iFollow, requested));
    widget.onChanged?.call(iFollow, requested);
    if (!mounted) return;
    setState(() {
      _iFollow = iFollow;
      _requested = requested;
    });
  }

  void _settled(bool iFollow, bool requested) {
    if (mounted) widget.onSettled?.call(iFollow, requested);
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    final wasFollow = _iFollow;
    final wasRequested = _requested;
    try {
      if (wasFollow || wasRequested) {
        _set(false, false);
        final r = await widget.api.unfollow(widget.userId);
        if (!r.isOk) {
          _set(wasFollow, wasRequested);
          _fail(r);
        } else {
          SocialLive.followers.value++;
          _settled(false, false);
        }
      } else {
        _set(true, false);
        final r = await widget.api.follow(widget.userId);
        if (r case BuddyOk<String>(:final value)) {
          final requested = value == FollowApi.stateRequested;
          _set(!requested, requested);
          SocialLive.followers.value++;
          _settled(!requested, requested);
        } else {
          _set(wasFollow, wasRequested);
          _fail(r);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        _busy = false;
      }
    }
  }

  static bool _isTryLater(BuddyResult<dynamic> r) =>
      r is BuddyRefused && (r.rateLimited || r.type == SocialErrorTypes.tryLater || r.type == SocialErrorTypes.tooManyRequests);

  void _fail(BuddyResult<dynamic> r) {
    if (!mounted) return;
    if (_isTryLater(r)) {
      FollowLimitSheet.show(context);
      return;
    }
    final text = switch (r) {
      BuddyOffline() => SocialStrings.offline,
      BuddyRefused(:final message) => message ?? SocialStrings.failed,
      _ => SocialStrings.failed,
    };
    BuddySnack.show(context, text, danger: true);
  }

  @override
  Widget build(BuildContext context) {
    final label = FollowButton.labelOf(iFollow: _iFollow, requested: _requested, followsMe: widget.followsMe);
    final height = widget.compact ? 36.0 : 50.0;
    final font = widget.compact ? 13.0 : 15.0;
    final Widget pill;
    if (_iFollow || _requested) {
      pill = WhitePillButton(tone: BuddyLook.indigo, label: label, onTap: _tap, neutral: true, height: height, fontSize: font, expand: !widget.compact);
    } else if (widget.light) {
      pill = WhitePillButton(tone: BuddyLook.indigo, label: label, onTap: _tap, height: height, fontSize: font, expand: !widget.compact);
    } else {
      pill = GradientPillButton(tone: BuddyLook.teal, label: label, onTap: _tap, height: height, fontSize: font, expand: !widget.compact);
    }
    // Busy keeps the live look; IgnorePointer only blocks a second tap.
    return IgnorePointer(ignoring: _busy, child: pill);
  }
}
