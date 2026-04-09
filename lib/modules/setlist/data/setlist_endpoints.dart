class SetlistEndpoints {
  static const String base = '/api/v1/setlists';
  static const String create = '$base/create';

  static String byId(String setlistId) => '$base/$setlistId';
  static String addSet(String setlistId) => '$base/$setlistId/sets';
  static String addItem(String setId) => '$base/sets/$setId/items';

  // Backend endpoint name is currently `/pdf-html`.
  static String pdfExport(String setlistId) => '$base/$setlistId/pdf-html';
}
