import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';

// 定制版：已移除 电竞直播(searchEsports) 与 番剧/影视(searchMedia) 推荐板块
class SearchAllController extends SearchVideoController with SearchVideoMixin {
  SearchAllController({
    required super.keyword,
    required super.searchType,
    required super.tag,
  });

  List<SearchUser>? searchUser;
  List<SearchActivity>? searchActivity;

  @override
  bool customHandleResponse(bool isRefresh, Success<SearchVideoData> response) {
    final res = response.response;
    if (isRefresh) {
      searchType_ = .video;
      searchUser = res.searchUser;
      searchActivity = res.searchActivity;
    }
    return super.customHandleResponse(isRefresh, response);
  }

  @override
  late var searchType_ = searchType;

  void _computeActualSearchType() {
    if (order.isNotEmpty ||
        videoDurationType != .all ||
        videoZoneType != .all ||
        pubBegin != null ||
        pubEnd != null) {
      searchType_ = .video;
      return;
    }
    searchType_ = .all;
  }

  @override
  Future<void> onRefresh() {
    _computeActualSearchType();
    searchUser = null;
    searchActivity = null;
    return super.onRefresh();
  }
}
