import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/study_guard.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stream_transform/stream_transform.dart';

mixin DebounceStreamMixin<T> {
  final Duration duration = const Duration(milliseconds: 200);
  StreamController<T>? ctr;
  StreamSubscription<T>? _sub;
  void onValueChanged(T value);

  void subInit() {
    _sub = (ctr = StreamController<T>()).stream
        .debounce(duration, trailing: true)
        .listen(onValueChanged);
  }

  void subDispose() {
    _sub?.cancel();
    ctr?.close();
    _sub = null;
    ctr = null;
  }
}

abstract class DebounceStreamState<T extends StatefulWidget, S> extends State<T>
    with DebounceStreamMixin<S> {
  @override
  void dispose() {
    subDispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    subInit();
  }
}

// 定制版：已移除 搜索联想词、大家都在搜/完整榜单/搜索发现。
// 保留搜索历史（记录全部关键词，长按单条删除），与上游一致。
class BaseSearchController extends GetxController {
  final historyList = List<String>.from(
    GStorage.historyWord.get('cacheList') ?? const <String>[],
  ).obs;

  final recordSearchHistory = Pref.recordSearchHistory.obs;
}

class SSearchController extends GetxController {
  SSearchController(this.tag);
  final String tag;

  final searchFocusNode = FocusNode();
  final controller = TextEditingController();
  final _baseCtr = Get.putOrFind(BaseSearchController.new);

  String? hintText;

  int initIndex = 0;

  // uid
  final RxBool showUidBtn = false.obs;

  // history
  RxBool get recordSearchHistory => _baseCtr.recordSearchHistory;
  RxList<String> get historyList => _baseCtr.historyList;

  /// 定制版：白名单搜索总开关（关闭时搜索不受限）
  bool get allowSearchEnabled => StudyGuard.allowSearchEnabled;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    hintText = params['hintText'];
    final text = params['text'];
    if (text != null) {
      controller.text = text;
    }
  }

  void validateUid() {
    showUidBtn.value = IdUtils.digitOnlyRegExp.hasMatch(controller.text);
  }

  void onChange(String value) => validateUid();

  void onClear() {
    if (controller.value.text != '') {
      controller.clear();
      searchFocusNode.requestFocus();
      showUidBtn.value = false;
    } else {
      Get.back();
    }
  }

  // 搜索
  Future<void> submit() async {
    if (controller.text.isEmpty) {
      if (hintText.isNullOrEmpty) return;
      controller.text = hintText!;
      validateUid();
    }

    final text = controller.text;

    // 定制版：白名单开关打开时，仅允许命中学习白名单的关键词。
    // 放在 scheme 解析之前，确保外链/BV号等非白名单内容也无法通过搜索框进入。
    if (allowSearchEnabled && !StudyGuard.allowSearch(text)) {
      SmartDialog.showToast(
        StudyGuard.whitelist.isEmpty
            ? '未配置学习白名单，请联系家长设置'
            : '仅允许搜索学习相关内容',
      );
      return;
    }

    if (await PiliScheme.routePushFromUrl(text, selfHandle: true)) {
      return;
    }

    if (recordSearchHistory.value) {
      final index = historyList.indexOf(text);
      if (index != 0) {
        if (index != -1) historyList.removeAt(index);
        historyList.insert(0, text);
        GStorage.historyWord.put('cacheList', historyList);
      }
    }

    searchFocusNode.unfocus();
    Get.toNamed(
      '/searchResult',
      parameters: {'tag': tag, 'keyword': text},
      arguments: {'initIndex': initIndex, 'fromSearch': true},
    )?.whenComplete(searchFocusNode.requestFocus);
  }

  void onClickKeyword(String keyword) {
    controller.text = keyword;
    validateUid();
    submit();
  }

  /// 长按单条历史 -> 删除该条
  void onLongSelect(String word) {
    historyList.remove(word);
    GStorage.historyWord.put('cacheList', historyList);
  }

  /// 清空全部历史
  void onClearHistory() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定清空搜索历史？'),
      onConfirm: () {
        historyList.clear();
        GStorage.historyWord.delete('cacheList');
      },
    );
  }

  @override
  void onClose() {
    searchFocusNode.dispose();
    controller.dispose();
    super.onClose();
  }
}
