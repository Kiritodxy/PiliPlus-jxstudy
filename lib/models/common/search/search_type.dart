// ignore_for_file: constant_identifier_names
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';

enum SearchType implements EnumWithLabel {
  all('综合', api: Api.searchAll),
  // 视频：video
  video('视频'),
  // 定制版：已移除 番剧(media_bangumi)、影视(media_ft)、直播间(live_room) 搜索
  // 用户：bili_user
  bili_user('用户'),
  // 专栏：article
  article('专栏'),
  ;

  // 相簿：photo
  // photo

  @override
  final String label;
  final String api;
  const SearchType(this.label, {this.api = Api.searchByType});
}
