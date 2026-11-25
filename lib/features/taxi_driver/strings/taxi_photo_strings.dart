import '../../../utils/photo_upload/photo_pick_strings.dart';

abstract final class TaxiPhotoStrings {
  static const plateTitle = 'Number plate photo';
  static const plateHint = 'Verification, only we see it';
  static const displayTitle = 'Taxi photo';
  static const displayHint = 'Travellers see this';
  static const plateBand = 'Plate';
  static const verifiedBand = 'Verified';
  static const taxiBand = 'Taxi';
  static const add = 'Add';
  static const change = 'Change';
  static const plateLockedNote = 'Verified. This photo cannot be changed.';
  static const plateNumberLockedNote = 'Verified. The plate number cannot be changed.';
  static const plateReviewNote = 'Changing the plate number sends your taxi back to review.';
  static const plateLockedToast = 'Your number plate photo is verified and cannot be changed.';
  static const displayNote = 'You can change this photo any time. No review needed.';
  static const uploadingPhoto = 'Uploading photo';
  static const uploadFailedTitle = 'Upload Failed';
  static const plateUploadFailedBody = 'The plate photo could not be uploaded. Retry?';
  static const displayUploadFailedBody = 'The taxi photo could not be uploaded. Retry?';
  static const skip = 'Skip';
  static const retry = 'Retry';
  static const displayUpdated = 'Taxi photo updated';
  static const photoTooLarge = PhotoPickStrings.tooLarge;
  static const photoWrongType = PhotoPickStrings.wrongType;
  static const photoPickFailed = PhotoPickStrings.pickFailed;
  static const photoCardTitle = 'Taxi photo and plate proof';
  static const manage = 'Manage';
  static const plateProof = 'Plate proof';
  static const private = 'Private';
  static const couldNotUpload = 'Could not upload photo.';
  static const deleteBody = 'Your taxi, routes and photos will be deleted.';
}
