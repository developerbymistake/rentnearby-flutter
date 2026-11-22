abstract final class StaySetupStrings {
  static const hubTitle = 'Set up your stay';
  static const hubEyebrow = 'Your stay';
  static const hubFinish = 'Finish 4 steps to open your dashboard';
  static const hubFixItems = 'Fix the items below, then resubmit';
  static String profilePercent(int p) => 'Profile $p% complete';
  static const start = 'Start ›';
  static const continueLabel = 'Continue ›';
  static const resubmit = 'Resubmit';

  static const step1 = 'Basic details';
  static const step1Sub = 'Details, registration, location, photos';
  static const step2 = 'Rooms';
  static const step2Sub = 'Add your rooms';
  static const step2Continue = 'Continue: add your rooms';
  static const step3 = 'Rules';
  static const step3Sub = 'Check-in, house rules, cancellation';
  static const step4 = 'Final submit';
  static const step4Sub = 'Review and submit';
  static const saved = 'Saved';
  static String fixThis(bool photos, bool registration) {
    final parts = [if (photos) 'photos', if (registration) 'registration'];
    return parts.isEmpty ? 'Fix this' : 'Fix this: ${parts.join(' and ')}';
  }

  static String submittedOn(String date) => 'Submitted on $date';
  static String notApproved(String? reason) => reason == null ? 'Not approved' : 'Not approved: $reason';
  static const registrationNeeded = 'Registration details needed';
  static const add = 'Add';
  static const changePhoto = 'Change';
  static const changePhotoTitle = 'Change Photo';
  static const wrongRole = 'Wrong role? Change it';
  static const menuChangeRole = 'Change role';
  static const menuLogOut = 'Log out';
  static const menuLabel = 'Menu';
  static const stayUnderReview = 'Your stay is under review.';

  static const roomsTitle = 'Rooms';
  static const roomsSubtitle = 'Step 2 of 4';
  static const addRoomType = 'Add room type';
  static String duplicateRoom(String name) => 'You already have a $name room. Pick another type.';

  static const photosTitle = 'Stay Photos';
  static String photoMeter(int used, int limit) => '$used of $limit';
  static const cover = 'Cover';
  static const addPhoto = 'Add photo';
  static const photoTooLarge = 'Photo is too large. Use one under 10 MB.';
  static const photoWrongType = 'Use a JPG, PNG or WebP photo.';
  static const photoUploadFailed = 'Upload failed. Try again.';
  static const photoPickFailed = 'Could not open your photos. Try again.';
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

  static const submitTitle = 'Final Submit';
  static const submitStep = 'Step 4 of 4';
  static const checkYourStay = 'Check your stay';
  static const almostDone = 'Almost done!';
  static const dashboardOpens = 'Dashboard opens after submit';
  static const submit = 'Submit';
  static const submittedToast = 'Submitted for review';
  static String basicSummary(String name, String type, int photos) => '$name · $type · ${photos == 1 ? '1 photo' : '$photos photos'}';

  static String time12(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${m == '00' ? '$h12' : '$h12:$m'} ${h < 12 ? 'am' : 'pm'}';
  }

  static String cancellationLine(String? policy) => switch (policy) {
        'Flexible' => 'Free cancellation 3 days before',
        final p? => '$p cancellation',
        null => '',
      };

  static String roomsSummary(List<(String, String)> rooms) => rooms.map((r) => '${r.$1} ${r.$2}').join(' · ');
  static String rulesSummary(String inTime, String outTime, String? policy) {
    final base = 'Check-in ${time12(inTime)} · Check-out ${time12(outTime)}';
    final c = cancellationLine(policy);
    return c.isEmpty ? base : '$base · $c';
  }
}
