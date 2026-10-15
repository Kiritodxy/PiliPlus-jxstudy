import 'dart:io' show Directory, File, Platform;

import 'package:PiliPlus/utils/mirror_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 定制版：应用内下载更新包并直接唤起系统安装器（替代原先跳浏览器下载）。
///
/// - 下载前先由 [MirrorPicker] 运行「抓清单 → 探活 → 实测速度 → 择优」，
///   用实测最快的镜像下载；失败自动顺延到下一个候选，最后用 GitHub 原链兜底。
/// - 下载到应用私有外部目录 `Android/data/<applicationId>/files/updates/`：
///   免存储权限，且与 AndroidManifest 里 FileProvider 的 `updates/` 路径一一对应。
/// - 下载完成后通过 MethodChannel `com.custom.piliplus/update` 调用原生安装
///   （Android 7.0+ 必须用 content:// URI，见 AndroidHelper.installApk）。
abstract final class InAppUpdate {
  static const _channel = MethodChannel('com.custom.piliplus/update');

  /// 已下载完成、等待安装的文件路径（用于「未授权未知来源」授权后重试安装）
  static String? _pendingApk;

  /// [targetUrl] 为 GitHub 原始下载地址；内部自动套加速镜像。
  static Future<void> downloadAndInstall({
    required String targetUrl,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) return;
    SmartDialog.dismiss();
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        SmartDialog.showToast('无法获取下载目录，已取消');
        return;
      }
      final dir = Directory(path.join(extDir.path, 'updates'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final filePath = path.join(dir.path, fileName);
      final file = File(filePath);

      final progress = ValueNotifier<double>(-1); // 负值表示总大小未知
      final status = ValueNotifier<String>('正在筛选下载线路…');
      final cancelToken = CancelToken();
      SmartDialog.show(
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (context) => AlertDialog(
          title: const Text('正在下载更新'),
          content: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, text, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value < 0 ? null : value,
                  ),
                ),
                const SizedBox(height: 12),
                Text(text),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorScheme.of(context).outline,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelToken.cancel();
                SmartDialog.dismiss();
              },
              child: const Text('取消'),
            ),
          ],
        ),
      );

      // 1) 测速择优：拿到按速度降序的候选镜像
      final picked = await MirrorPicker.candidates(targetUrl);
      if (cancelToken.isCancelled) return;
      // 2) 候选镜像 + GitHub 原链兜底
      final urls = [
        for (final node in picked) MirrorPicker.link(node, targetUrl),
        targetUrl,
      ];

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      Object? lastError;
      var ok = false;
      for (var i = 0; i < urls.length; i++) {
        if (cancelToken.isCancelled) return;
        try {
          // 每个地址都从头下载（部分镜像不支持 Range，续传反而会拿到损坏文件）
          if (file.existsSync()) file.deleteSync();
          progress.value = -1;
          status.value = i == urls.length - 1
              ? '正在从 GitHub 下载…'
              : '正在下载（线路 ${i + 1}/${urls.length}）…';
          await dio.download(
            urls[i],
            filePath,
            cancelToken: cancelToken,
            onReceiveProgress: (count, total) {
              final double v = total > 0 ? count / total : -1.0;
              progress.value = v;
              if (v >= 0) {
                status.value =
                    '正在下载 ${(v * 100).toStringAsFixed(1)}%'
                    '${i == urls.length - 1 ? '（GitHub 原链）' : ''}';
              }
            },
          );
          // 镜像异常时可能返回 HTML 错误页，只有真正拿到 zip(APK) 才算成功
          if (!_looksLikeApk(file)) {
            lastError = '返回内容不是 APK（可能镜像异常）';
            continue;
          }
          ok = true;
          break;
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) return;
          lastError = e;
        }
      }

      SmartDialog.dismiss();
      // 注：不 dispose 这几个 ValueNotifier —— 弹窗退场动画期间仍可能重建，提前销毁会抛异常

      if (!ok) {
        SmartDialog.showToast('下载失败：${lastError ?? '无可用下载地址'}');
        return;
      }
      if (file.existsSync() && file.lengthSync() > 0) {
        await installDownloaded(filePath);
      } else {
        SmartDialog.showToast('下载失败：文件为空');
      }
    } catch (e) {
      SmartDialog.dismiss();
      if (e is! DioException || !CancelToken.isCancel(e)) {
        SmartDialog.showToast('下载失败：$e');
      }
    }
  }

  /// 校验下载结果确实是 APK：zip 魔数 `PK\x03\x04`。
  /// 部分加速镜像失败时会返回 HTML 错误页且仍是 200，若不校验会把错误页当安装包。
  static bool _looksLikeApk(File file) {
    try {
      if (!file.existsSync() || file.lengthSync() < 4) return false;
      final raf = file.openSync();
      try {
        final head = raf.readSync(4);
        return head.length == 4 &&
            head[0] == 0x50 &&
            head[1] == 0x4B &&
            head[2] == 0x03 &&
            head[3] == 0x04;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// 唤起系统安装器；若「安装未知应用」未授权，先跳到系统授权页，授权后引导再次点击安装。
  static Future<void> installDownloaded(String filePath) async {
    if (!Platform.isAndroid) return;
    _pendingApk = filePath;
    final String? res;
    try {
      res = await _channel.invokeMethod<String>('installApk', {
        'path': filePath,
      });
    } catch (e) {
      SmartDialog.showToast('唤起安装器失败：$e');
      return;
    }
    if (res == null) return; // 已成功唤起安装器
    if (res == 'need install permission') {
      SmartDialog.show(
        builder: (context) => AlertDialog(
          title: const Text('需要安装权限'),
          content: const Text(
            '已为你打开「安装未知应用」设置页，请允许本应用安装应用后返回，点击下方按钮继续安装。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                SmartDialog.dismiss();
                final pending = _pendingApk;
                if (pending != null) installDownloaded(pending);
              },
              child: const Text('我已授权，继续安装'),
            ),
          ],
        ),
      );
    } else {
      SmartDialog.showToast('安装失败：$res');
    }
  }
}