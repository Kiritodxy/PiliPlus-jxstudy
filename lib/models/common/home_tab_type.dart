import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 定制版：首页 tab 枚举（裁剪版）
///
/// 上游此文件同时绑定 6 个页面（live/rcmd/hot/rank/pgc），
/// 而定制版已移除 live / rcmd / hot / rank / pgc 整套页面，
/// 因此这里只保留枚举与 label，去掉 ctr / page 两个依赖页面的 getter。
/// 目前仅 main/controller.dart 的 refreshRecommendations() 使用 HomeTabType.rcmd 判断。
enum HomeTabType implements EnumWithLabel {
  live('直播'),
  rcmd('推荐'),
  hot('热门'),
  rank('分区'),
  bangumi('番剧'),
  cinema('影视'),
  ;

  @override
  final String label;

  const HomeTabType(this.label);
}