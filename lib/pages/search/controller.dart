import 'dart:async';

import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
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

// 定制版：已移除 搜索联想词、搜索历史、大家都在搜/完整榜单/搜索发现。
// 无任何本地缓存，避免输入即推词，也避免留下浏览痕迹。
class BaseSearchController extends GetxController {}

class SSearchController extends GetxController {
  SSearchController(this.tag);
  final String tag;

  final searchFocusNode = FocusNode();
  final controller = TextEditingController();

  String? hintText;

  int initIndex = 0;

  // uid
  final RxBool showUidBtn = false.obs;

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

    // 定制版：仅允许命中学习白名单的关键词。
    // 放在 scheme 解析之前，确保外链/BV号等非白名单内容也无法通过搜索框进入。
    if (!StudyGuard.allowSearch(text)) {
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

  @override
  void onClose() {
    searchFocusNode.dispose();
    controller.dispose();
    super.onClose();
  }
}
