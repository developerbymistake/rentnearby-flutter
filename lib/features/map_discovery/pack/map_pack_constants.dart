class MapPackConstants {
  static const String box = 'map_pack';
  static const int isolateFromChars = 4096;
  static const int maxBodyChars = 2000000;
  static const int maxRows = 20000;
  static const Duration retryAfter = Duration(seconds: 60);
  static const int fallbackRefs = 4;
  static const int unrankedBase = 1000000;

  static const String colId = 'id';
  static const String colLat = 'lat';
  static const String colLon = 'lon';
  static const String colCat = 'cat';
  static const String colRank = 'rank';
  static const String colName = 'name';
  static const String colCityKey = 'cityKey';
  static const String colThumb = 'thumb';
  static const String colNPhotos = 'nPhotos';
  static const String colVm = 'vm';
  static const List<String> requiredColumns = [colId, colLat, colLon, colName];
}
