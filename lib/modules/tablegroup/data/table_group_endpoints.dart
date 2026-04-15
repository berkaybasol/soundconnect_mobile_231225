class TableGroupEndpoints {
  static const String base = '/api/v1/table-groups';
  static const String active = '$base/active';

  static String detail(String tableGroupId) => '$base/$tableGroupId';
  static String join(String tableGroupId) => '$base/$tableGroupId/join';
  static String create() => base;
}
