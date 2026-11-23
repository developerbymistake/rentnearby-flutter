abstract final class PhotoPickStrings {
  static const sheetTitle = 'Add Photo';
  static const sheetSubtitle = 'Camera or Gallery';
  static const cameraTitle = 'Take Photo';
  static const cameraSubtitle = 'Use camera to capture now';
  static const galleryTitle = 'Choose from Gallery';
  static const gallerySubtitle = 'Pick existing photos';
  static String permissionTitle(String type) => '$type Permission Required';
  static String permissionBody(String type) => 'Please enable $type access in your device Settings to add photos.';
  static const permissionCancel = 'Cancel';
  static const permissionOpenSettings = 'Open Settings';
  static const camera = 'Camera';
  static const pickFailed = 'Could not open your photos. Try again.';
  static const tooLarge = 'Photo is too large. Use one under 10 MB.';
  static const wrongType = 'Use a JPG, PNG or WebP photo.';
}
