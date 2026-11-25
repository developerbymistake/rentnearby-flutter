import '../../../utils/photo_upload/photo_pick_strings.dart';

abstract final class StaySetupStrings {
  static const hubTitle = 'Set up your stay';
  static const saved = 'Saved';
  static String notApproved(String? reason) => reason == null ? 'Not approved' : 'Not approved: $reason';
  static const changePhoto = 'Change';
  static const changePhotoTitle = 'Change Photo';
  static const wrongRole = 'Wrong role? Change it';
  static const menuLabel = 'Menu';

  static const roomsTitle = 'Rooms';
  static const roomsSubtitle = 'Step 2 of 4';
  static const addRoomType = 'Add room type';
  static String duplicateRoom(String name) => 'You already have a $name room. Pick another type.';

  static const photosTitle = 'Stay Photos';
  static String photoMeter(int used, int limit) => '$used of $limit';
  static const cover = 'Cover';
  static const addPhoto = 'Add photo';
  static const photoTooLarge = PhotoPickStrings.tooLarge;
  static const photoWrongType = PhotoPickStrings.wrongType;
  static const photoUploadFailed = 'Upload failed. Try again.';
  static const photoPickFailed = PhotoPickStrings.pickFailed;
  static const keepOnePhoto = 'Keep at least one photo.';

  static const noConnection = 'No connection. Please try again.';
  static const notOpenTitle = 'Not open here yet';
  static const notOpenBody = 'We are not taking new stays in this area yet. We will tell you when it opens.';
  static const outsideDistrictBody = 'Pin your stay inside the selected district.';

  static String notOpenBodyFor(String? errorType, String? serverMessage) {
    if (errorType != 'StayOutsideDistrict') return notOpenBody;
    final m = serverMessage?.trim() ?? '';
    return m.isEmpty ? outsideDistrictBody : m;
  }
  static const ok = 'OK';

  static const dashboardOpens = 'Dashboard opens after submit';
  static const submit = 'Submit';
  static const submittedToast = 'Submitted for review';
}
