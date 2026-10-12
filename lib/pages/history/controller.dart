import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/tab.dart';
import 'package:PiliPlus/pages/common/multi_select/multi_select_controller.dart';
import 'package:PiliPlus/pages/history/base_controller.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class HistoryController
    extends MultiSelectController<HistoryData, HistoryItemModel>
    with GetSingleTickerProviderStateMixin {
  HistoryController(this.type);

  late final baseCtr = Get.put(HistoryBaseController());

  Account get account => baseCtr.account;

  final String? type;
  TabController? tabController;
  late RxList<HistoryTab> tabs = <HistoryTab>[].obs;

  int? max;
  int? viewAt;

  @override
  RxInt get rxCount => baseCtr.checkedCount;

  @override
  RxBool get enableMultiSelect => baseCtr.enableMultiSelect;

  @override
  void onInit() {
    super.onInit();
    historyStatus();
    queryData();
  }

  @override
  Future<void> onRefresh() {
    max = null;
    viewAt = null;
    return super.onRefresh();
  }

  @override
  List<HistoryItemModel>? getDataList(HistoryData response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<HistoryData> response) {
    final data = response.response;
    final last = data.list?.lastOrNull;
    if (last == null) {
      isEnd = true;
      max = viewAt = null;
    } else {
      isEnd = false;
      max = last.history.oid;
      viewAt = last.viewAt;
    }

    if (isRefresh && type == null) {
      final tab = data.tab;
      if (tabs.isEmpty && tab != null && tab.isNotEmpty) {
        // 定制版：过滤掉「直播」等非视频类观看记录标签页
        final filtered = tab.where((e) {
          final t = e.type ?? '';
          final n = e.name ?? '';
          return t != 'live' &&
              t != 'article' &&
              !n.contains('直播') &&
              !n.contains('专栏');
        }).toList();
        if (filtered.isNotEmpty) {
          tabs.value = filtered;
          tabController = TabController(length: filtered.length + 1, vsync: this);
        }
      }
    }

    return false;
  }

  // 观看历史暂停状态
  Future<void> historyStatus() async {
    final res = await UserHttp.historyStatus(account: account);
    if (res case Success(:final response)) {
      baseCtr.pauseStatus.value = response;
      GStorage.localCache.put(LocalCacheKey.historyPause, response);
    } else {
      res.toast();
    }
  }


  // 定制版：观看记录不可删除
  @override
  void onRemove() {
    SmartDialog.showToast('观看记录不可删除');
  }

  @override
  Future<LoadingState<HistoryData>> customGetData() => UserHttp.historyList(
    type: type ?? 'all',
    max: max,
    viewAt: viewAt,
    account: account,
  );

  @override
  void onClose() {
    tabController?.dispose();
    super.onClose();
  }

  @override
  Future<void> onReload() {
    scrollController.jumpToTop();
    return super.onReload();
  }
}
