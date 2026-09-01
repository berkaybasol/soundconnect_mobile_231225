import '../../../../core/policy/stage_mode.dart';

class TableGroupListArgs {
  final StageMode bottomBarStageMode;

  const TableGroupListArgs({this.bottomBarStageMode = StageMode.backstage});
}

class TableGroupCreateResult {
  final String cityId;

  const TableGroupCreateResult({required this.cityId});
}
