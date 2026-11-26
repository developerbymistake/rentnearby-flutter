import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/c/chat/open_room_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(OpenRoomTracker.clear);

  test('a push for the open room is suppressed', () {
    OpenRoomTracker.open('r1');
    expect(OpenRoomTracker.isOpen(AppRoutes.dmRoom, {'roomId': 'r1'}), isTrue);
  });

  test('a push for another room, another route or no open room is shown', () {
    expect(OpenRoomTracker.isOpen(AppRoutes.dmRoom, {'roomId': 'r1'}), isFalse);
    OpenRoomTracker.open('r1');
    expect(OpenRoomTracker.isOpen(AppRoutes.dmRoom, {'roomId': 'r2'}), isFalse);
    expect(OpenRoomTracker.isOpen(AppRoutes.notifications, {'roomId': 'r1'}), isFalse);
    expect(OpenRoomTracker.isOpen(AppRoutes.dmRoom, null), isFalse);
  });

  test('closing clears only the same room', () {
    OpenRoomTracker.open('r1');
    OpenRoomTracker.close('r2');
    expect(OpenRoomTracker.current, 'r1');
    OpenRoomTracker.close('r1');
    expect(OpenRoomTracker.current, isNull);
  });

  test('closing the top room gives the room below back', () {
    OpenRoomTracker.open('a');
    OpenRoomTracker.open('b');
    expect(OpenRoomTracker.current, 'b');
    OpenRoomTracker.close('b');
    expect(OpenRoomTracker.current, 'a');
    expect(OpenRoomTracker.isOpen(AppRoutes.dmRoom, {'roomId': 'a'}), isTrue);
  });
}
